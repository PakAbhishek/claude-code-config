#!/usr/bin/env node
/**
 * Hindsight Automatic Capture Hook for Claude Code
 * Smart cloud-aware version with async operations
 *
 * Features:
 * - Fire-and-forget async storage (non-blocking)
 * - Retry queue for failed requests
 * - Adaptive timeouts based on endpoint
 * - FILTERED CAPTURE: Skips low-value tools to reduce noise
 *
 * Updated: 2026-01-12 - Added filtering to improve memory quality
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

// Tools to SKIP (low-value, high-noise)
// These are captured in full transcript at session end anyway
const SKIP_TOOLS = new Set([
  'Read',           // File reads - ephemeral, high volume
  'Glob',           // File searches - ephemeral
  'Grep',           // Content searches - ephemeral
  'TaskOutput',     // Task status checks - ephemeral
  'NotebookEdit',   // Notebook edits captured in transcript
]);

// Tools to ALWAYS capture (high-value)
const IMPORTANT_TOOLS = new Set([
  'Bash',           // Commands and results
  'Edit',           // Code changes
  'Write',          // File creation
  'Task',           // Agent launches
  'TodoWrite',      // Task tracking
  'WebFetch',       // Web research
  'AskUserQuestion', // User interactions
]);

// Configuration - CLOUD ENDPOINT
const HINDSIGHT_HOST = 'hindsight-achau.southcentralus.azurecontainer.io';
const HINDSIGHT_PORT = 8888;
const BANK_ID = 'claude-code';

// Smart timeouts (cloud needs more time)
const HEALTH_TIMEOUT = 5000;      // Health check: 5s
const STORE_TIMEOUT = 120000;     // Store: 2 min (OpenAI processing)
const MAX_RETRIES = 2;

// Retry queue file (persist failed requests)
const RETRY_QUEUE_PATH = path.join(process.env.HOME || process.env.USERPROFILE, '.claude', 'hooks', 'hindsight', '.retry_queue.json');
const SYNC_TRACKER_PATH = path.join(process.env.HOME || process.env.USERPROFILE, '.claude', 'hooks', 'hindsight', '.synced_transcripts');

// Standard hook response - ALWAYS return quickly
const HOOK_RESPONSE = JSON.stringify({ continue: true, suppressOutput: true });

// Load retry queue
function loadRetryQueue() {
  try {
    if (fs.existsSync(RETRY_QUEUE_PATH)) {
      return JSON.parse(fs.readFileSync(RETRY_QUEUE_PATH, 'utf8'));
    }
  } catch {}
  return [];
}

// Save retry queue
function saveRetryQueue(queue) {
  try {
    fs.writeFileSync(RETRY_QUEUE_PATH, JSON.stringify(queue.slice(-50))); // Keep last 50
  } catch {}
}

// Fire-and-forget store - returns immediately, processes in background
function storeMemoryAsync(content, retryCount = 0) {
  const data = JSON.stringify({
    items: [{ content: content }]
  });

  const options = {
    hostname: HINDSIGHT_HOST,
    port: HINDSIGHT_PORT,
    path: `/v1/default/banks/${BANK_ID}/memories`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data)
    },
    timeout: STORE_TIMEOUT
  };

  const req = http.request(options, (res) => {
    // Success - do nothing, memory stored
    res.resume(); // Drain response
  });

  req.on('error', () => {
    // Failed - add to retry queue if not max retries
    if (retryCount < MAX_RETRIES) {
      const queue = loadRetryQueue();
      queue.push({ content, retryCount: retryCount + 1, timestamp: Date.now() });
      saveRetryQueue(queue);
    }
  });

  req.on('timeout', () => {
    req.destroy();
    // Timeout - add to retry queue
    if (retryCount < MAX_RETRIES) {
      const queue = loadRetryQueue();
      queue.push({ content, retryCount: retryCount + 1, timestamp: Date.now() });
      saveRetryQueue(queue);
    }
  });

  req.write(data);
  req.end();
}

// Process retry queue in background (non-blocking)
function processRetryQueue() {
  const queue = loadRetryQueue();
  if (queue.length === 0) return;

  // Process one item at a time to avoid overwhelming
  const item = queue.shift();
  saveRetryQueue(queue);

  if (item && Date.now() - item.timestamp < 3600000) { // Less than 1 hour old
    storeMemoryAsync(item.content, item.retryCount);
  }
}

// Format tool use for memory
function formatToolUse(toolName, toolInput, toolResponse) {
  let content = `[Tool Use: ${toolName}]\n`;

  if (toolInput) {
    if (typeof toolInput === 'string') {
      try { toolInput = JSON.parse(toolInput); } catch {}
    }
    if (toolInput.command) content += `Command: ${toolInput.command}\n`;
    if (toolInput.file_path) content += `File: ${toolInput.file_path}\n`;
    if (toolInput.pattern) content += `Pattern: ${toolInput.pattern}\n`;
    if (toolInput.query) content += `Query: ${toolInput.query}\n`;
    if (toolInput.content) content += `Content: ${toolInput.content.substring(0, 500)}...\n`;
    if (toolInput.prompt) content += `Prompt: ${toolInput.prompt}\n`;
  }

  if (toolResponse) {
    const respStr = typeof toolResponse === 'string' ? toolResponse : JSON.stringify(toolResponse);
    content += `Result: ${respStr.substring(0, 1000)}${respStr.length > 1000 ? '...' : ''}\n`;
  }

  return content;
}

// Check if transcript was already synced
function wasTranscriptSynced(transcriptPath) {
  try {
    if (fs.existsSync(SYNC_TRACKER_PATH)) {
      const synced = fs.readFileSync(SYNC_TRACKER_PATH, 'utf8').split('\n');
      return synced.includes(transcriptPath);
    }
  } catch {}
  return false;
}

// Mark transcript as synced
function markTranscriptSynced(transcriptPath) {
  try {
    fs.appendFileSync(SYNC_TRACKER_PATH, transcriptPath + '\n');
  } catch {}
}

// Sync full transcript (for session end)
function syncFullTranscript(transcriptPath, sessionId) {
  try {
    if (!transcriptPath || !fs.existsSync(transcriptPath)) return;
    if (wasTranscriptSynced(transcriptPath)) return;

    const content = fs.readFileSync(transcriptPath, 'utf8');
    const lines = content.trim().split('\n');

    let formattedConversation = `[Full Session Transcript]\n`;
    formattedConversation += `Session: ${sessionId}\n`;
    formattedConversation += `Transcript: ${transcriptPath}\n`;
    formattedConversation += `Total turns: ${lines.length}\n`;
    formattedConversation += `---\n\n`;

    let turnCount = 0;
    for (const line of lines) {
      try {
        const entry = JSON.parse(line);
        turnCount++;
        if (entry.type === 'user') {
          formattedConversation += `[USER ${turnCount}]: `;
          if (entry.message?.content) {
            if (typeof entry.message.content === 'string') {
              formattedConversation += entry.message.content;
            } else if (Array.isArray(entry.message.content)) {
              for (const block of entry.message.content) {
                if (block.type === 'text') formattedConversation += block.text;
              }
            }
          }
          formattedConversation += '\n\n';
        } else if (entry.type === 'assistant') {
          formattedConversation += `[CLAUDE ${turnCount}]: `;
          if (entry.message?.content) {
            if (typeof entry.message.content === 'string') {
              formattedConversation += entry.message.content;
            } else if (Array.isArray(entry.message.content)) {
              for (const block of entry.message.content) {
                if (block.type === 'text') formattedConversation += block.text;
                else if (block.type === 'tool_use') formattedConversation += `\n[Used tool: ${block.name}]`;
              }
            }
          }
          formattedConversation += '\n\n';
        }
      } catch {}
    }

    // Truncate if too long
    const MAX_LENGTH = 100000;
    if (formattedConversation.length > MAX_LENGTH) {
      formattedConversation = formattedConversation.substring(0, MAX_LENGTH) + '\n[truncated]\n';
    }

    markTranscriptSynced(transcriptPath);
    storeMemoryAsync(formattedConversation);
  } catch {}
}

// Main hook handler - MUST return quickly
async function main() {
  // Output success response IMMEDIATELY - don't block Claude Code
  console.log(HOOK_RESPONSE);

  // Process retry queue in background
  setImmediate(processRetryQueue);

  let stdinData = '';

  // Read stdin with short timeout
  await new Promise((resolve) => {
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', chunk => stdinData += chunk);
    process.stdin.on('end', resolve);
    setTimeout(resolve, 500); // Short timeout for stdin
  });

  try {
    let hookData = {};
    if (stdinData.trim()) {
      try {
        hookData = JSON.parse(stdinData);
      } catch {
        hookData = { raw: stdinData };
      }
    }

    const timestamp = new Date().toISOString();
    let memoryContent = '';

    // Handle different hook types
    if (hookData.tool_name) {
      // PostToolUse - FILTER low-value tools
      const toolName = hookData.tool_name;

      // Skip low-value tools (they're in transcript anyway)
      if (SKIP_TOOLS.has(toolName)) {
        // Don't store, exit early
        setTimeout(() => process.exit(0), 50);
        return;
      }

      // For tools not in IMPORTANT_TOOLS, only capture if they have interesting output
      if (!IMPORTANT_TOOLS.has(toolName)) {
        const response = hookData.tool_response || '';
        const respStr = typeof response === 'string' ? response : JSON.stringify(response);
        // Skip if response is very short (likely just status)
        if (respStr.length < 100) {
          setTimeout(() => process.exit(0), 50);
          return;
        }
      }

      memoryContent = formatToolUse(hookData.tool_name, hookData.tool_input, hookData.tool_response);
      memoryContent += `Session: ${hookData.session_id || 'unknown'}\n`;
      memoryContent += `Timestamp: ${timestamp}\n`;
    } else if (hookData.user_message || hookData.prompt) {
      // UserPromptSubmit
      const message = hookData.user_message || hookData.prompt || hookData.content;
      memoryContent = `[User Message]\nMessage: ${message}\nSession: ${hookData.session_id || 'unknown'}\nTimestamp: ${timestamp}\n`;
    } else if (hookData.session_id && !hookData.tool_name) {
      // Session end - sync transcript
      memoryContent = `[Session Event]\nSession: ${hookData.session_id}\nTimestamp: ${timestamp}\n`;
      if (hookData.transcript_path) {
        setImmediate(() => syncFullTranscript(hookData.transcript_path, hookData.session_id));
      }
    } else if (hookData.raw) {
      memoryContent = `[Activity]\n${hookData.raw}\nTimestamp: ${timestamp}\n`;
    }

    // Fire-and-forget store (non-blocking)
    if (memoryContent && memoryContent.length > 50) {
      setImmediate(() => storeMemoryAsync(memoryContent));
    }

  } catch {}

  // Exit after short delay to allow async operations to start
  setTimeout(() => process.exit(0), 100);
}

main();
