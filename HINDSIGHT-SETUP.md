# Hindsight Integration for Claude Code

Automated memory retention and recall system for Claude Code using [Hindsight](https://github.com/vectorize-io/hindsight).

## Overview

This integration provides:
- **Automated Memory Capture**: Smart hook that auto-saves important activities
- **Manual Memory Tools**: 7 MCP tools for explicit memory management
- **Importance Scoring**: Filters noise, keeps valuable information (0-100 scale)
- **Tag System**: Organize memories with auto-expiry (7d, 30d, permanent)
- **Deduplication**: Prevents redundant command storage

## Architecture

### 1. MCP Server (Manual Tools)
**Location**: `settings.json` → `mcpServers.hindsight`

```json
{
  "hindsight": {
    "transport": "sse",
    "url": "http://34.174.13.163:8888/mcp/claude-code/"
  }
}
```

**Available Tools**:
- `retain` - Store memories manually
- `recall` - Search stored memories
- `reflect` - Generate insights from memories
- `list_banks` - View all memory banks
- `create_bank` - Create isolated memory namespaces
- `get_statistics` - View memory bank analytics
- `health_check` - Check server connectivity

### 2. Auto-Capture Hook (Automated)
**Location**: `~/.claude/hooks/hindsight/capture.js`
**Trigger**: PostToolUse (all tools via matcher `.*`)
**Configuration**: `settings.json` → `hooks.PostToolUse`

```json
{
  "matcher": ".*",
  "hooks": [
    {
      "type": "command",
      "command": "node \"C:\\Users\\achau\\.claude\\hooks/hindsight/capture.js\"",
      "timeout": 5
    }
  ]
}
```

## How Auto-Capture Works

### Importance Scoring (0-100)

| Activity | Base Score | Modifiers |
|----------|------------|-----------|
| `git commit` | 90 | +15 if errors |
| `git push` | 85 | +15 if errors |
| File edit (.ts/.js/.py) | 65 | +10 if Write (new file) |
| package.json edit | 80 | Critical files get boost |
| Command execution | 50 | -30 if ls/pwd/cd |
| Task completion | 60 | +10 if subtasks |
| Error messages | +15 | Applied to base score |

**Thresholds**:
- Score < 20: **Skipped** (too noisy)
- Score 20-49: **Async retention** (fire-and-forget)
- Score 50-69: **Standard retention** (medium priority)
- Score 70+: **High priority** with permanent tag

### Tag System

**Auto-Generated Tags**:
- `auto-captured` - All auto-captured memories
- `tool:bash`, `tool:edit`, etc. - Tool name
- `priority:high/medium/low` - Based on importance score
- `git`, `npm`, `debug` - Content-specific tags

**Expiry Tags** (Automatic Cleanup):
- `expires:7d` - Low importance (score < 50)
- `expires:30d` - Medium importance (score 50-69)
- `permanent` - High importance (score 70+)

### Filtering Rules

**Skipped Tools** (Too Noisy):
- `Read`, `Glob`, `Grep` - File exploration
- `TaskOutput`, `TaskList`, `TaskGet` - Task metadata

**Deduplication**:
- Bash commands: 5-minute window
- Identical content within window = skipped

## Setup Instructions

### Prerequisites
- Node.js installed
- Hindsight server running at `http://34.174.13.163:8888`
- Claude Code with hooks enabled

### Installation

1. **Auto-Sync Setup** (if using one-click installer)
   ```bash
   # Already configured - hooks and settings sync via OneDrive
   ```

2. **Manual Setup**
   ```bash
   # Copy hooks
   cp -r "OneDrive/Claude Backup/claude-config/hooks/hindsight" ~/.claude/hooks/

   # Update settings.json
   # Add PostToolUse hook and mcpServers.hindsight (see Architecture above)
   ```

3. **Verify Installation**
   ```bash
   # Restart Claude Code
   # In a new session, check for Hindsight tools:
   claude mcp list
   # Should show: hindsight (retain, recall, reflect, list_banks, create_bank, get_statistics, health_check)
   ```

### Testing

**Test Auto-Capture**:
```bash
# Create a test commit
git add -A
git commit -m "Test Hindsight auto-capture"

# Should auto-capture with:
# - Score: 90
# - Tags: auto-captured, tool:bash, priority:high, git, permanent
```

**Test Manual Tools**:
```
Use recall to search: "What did I just commit?"
# Should return the auto-captured commit memory
```

## Usage Examples

### Manual Memory Management

**Store a Decision**:
```
Use retain to remember: "Decided to use TypeScript for the MCP server because it provides better type safety and IDE support. This decision was made after evaluating JavaScript alternatives."

Tags: ["typescript", "architecture", "decision"]
Context: "project-decision"
```

**Search Memories**:
```
Use recall to search: "What TypeScript decisions did I make?"

Budget: "HIGH" (comprehensive search)
Tags: ["typescript", "decision"]
```

**Generate Insights**:
```
Use reflect to analyze: "What patterns emerge from my TypeScript architecture decisions?"

Budget: "high"
Context: "Looking for consistency in design choices"
```

**Check Statistics**:
```
Use get_statistics to see memory bank analytics
```

### Automatic Capture Examples

These are captured automatically with appropriate scoring:

| User Action | Auto-Captured | Score | Tags | Expiry |
|-------------|---------------|-------|------|--------|
| `git commit -m "Add feature"` | ✅ Yes | 90 | auto-captured, tool:bash, priority:high, git | permanent |
| `npm install package` | ✅ Yes | 60 | auto-captured, tool:bash, priority:medium, npm | expires:30d |
| Edit `src/index.ts` | ✅ Yes | 65 | auto-captured, tool:edit, priority:medium | expires:30d |
| Write `package.json` | ✅ Yes | 90 | auto-captured, tool:write, priority:high | permanent |
| `ls -la` | ❌ No | 20 | (skipped - too low) | N/A |
| Read file | ❌ No | N/A | (filtered out) | N/A |

## Advanced Configuration

### Custom Memory Banks

Create project-specific memory banks:

```
Use create_bank with:
- bank_id: "smart-test-generator"
- name: "Smart Test Generator Project"
- mission: "Track decisions, learnings, and debugging insights for the test generator"
- disposition: { skepticism: 4, literalism: 3, empathy: 2 }
```

Then configure the hook to use different banks:
```javascript
// In capture.js
const BANK_ID = process.env.HINDSIGHT_BANK_ID || 'claude-code';
```

### Adjusting Importance Thresholds

Edit `~/.claude/hooks/hindsight/capture.js`:

```javascript
// Current thresholds
const MIN_IMPORTANCE_SCORE = 20;    // Skip below this
const ASYNC_THRESHOLD = 50;         // Async below this
const PERMANENT_THRESHOLD = 70;     // Permanent above this

// Adjust based on your needs:
// - More noise? Increase MIN_IMPORTANCE_SCORE to 30
// - Less permanent memories? Increase PERMANENT_THRESHOLD to 80
// - Capture more synchronously? Lower ASYNC_THRESHOLD to 40
```

### Adding Custom Scoring Rules

```javascript
// In calculateImportance() function
if (toolName === 'YourCustomTool') {
  if (someCondition) score = 85;
  else score = 40;
}
```

## Alternative: Custom stdio MCP Server

**Location**: `hindsight-mcp-server/`

If the SSE endpoint doesn't work, use the custom TypeScript MCP server:

```json
{
  "mcpServers": {
    "hindsight": {
      "command": "node",
      "args": [
        "C:\\Users\\achau\\OneDrive\\Claude Backup\\claude-config\\hindsight-mcp-server\\dist\\index.js"
      ]
    }
  }
}
```

**Setup**:
```bash
cd "OneDrive/Claude Backup/claude-config/hindsight-mcp-server"
npm install
npm run build
```

See `hindsight-mcp-server/README.md` for details.

## Troubleshooting

### Auto-Capture Not Working

1. **Check hook is enabled**:
   ```bash
   cat ~/.claude/settings.json | grep hindsight/capture
   ```

2. **Test hook manually**:
   ```bash
   node ~/.claude/hooks/hindsight/capture.js
   # Should print: "Hindsight capture hook (no data - testing)"
   ```

3. **Check Hindsight server**:
   ```bash
   curl http://34.174.13.163:8888/health
   # Should return: {"status":"healthy","database":"connected"}
   ```

4. **View hook errors**:
   ```bash
   # Claude Code logs will show hook failures
   # Check: Settings → View Logs
   ```

### MCP Tools Not Available

1. **Verify settings.json**:
   ```bash
   cat ~/.claude/settings.json | grep -A5 mcpServers
   ```

2. **Test SSE endpoint**:
   ```bash
   curl http://34.174.13.163:8888/mcp/claude-code/
   # Should return MCP handshake response
   ```

3. **Try custom stdio server** (see Alternative above)

### Too Much Noise in Memories

**Increase minimum score**:
```javascript
// In capture.js
const MIN_IMPORTANCE_SCORE = 30;  // Was 20
```

**Add more skip rules**:
```javascript
const SKIP_TOOLS = new Set([
  'Read', 'Glob', 'Grep', 'TaskOutput', 'TaskList', 'TaskGet',
  'YourNoisyTool'  // Add here
]);
```

### Memory Bloat

**Check statistics**:
```
Use get_statistics to see memory counts
```

**Query by expiry tag**:
```
Use recall with tags: ["expires:7d"]
# Shows what will be auto-deleted
```

**Manually clean up**:
```bash
# Hindsight automatically deletes expired memories
# Check server logs for cleanup activity
```

## Best Practices

### 1. Let Auto-Capture Handle Routine Activities
- Git commits (auto-captured at score 90)
- File edits (auto-captured at score 65+)
- Command executions (auto-captured at score 50+)

### 2. Use Manual Retain for Context
- Project decisions
- "Aha moments" during debugging
- User preferences and requirements
- Architecture explanations

### 3. Use Tags Consistently
```
retain with tags: ["bug-fix", "performance", "database"]
```

### 4. Regular Reflection
```
Weekly: "Use reflect to summarize: What progress did I make this week?"
Monthly: "Use reflect to analyze: What patterns emerge from my coding sessions?"
```

### 5. Project-Specific Banks
- Create separate banks for major projects
- Isolates memories by context
- Prevents cross-project confusion

## Performance

### Auto-Capture Overhead
- **Async retention** (score < 50): ~50ms (non-blocking)
- **Sync retention** (score 50+): ~200ms (blocks hook)
- **Hook timeout**: 5 seconds (configured in settings.json)

### Memory Bank Stats (Current)
```
Total Memories: 7,273
Links: 738,808
Entities: 8,066
Average retrieval time: ~500ms (MID budget)
```

## Security Notes

- Hindsight server at `34.174.13.163:8888` is on GCP
- No authentication required (internal network)
- All memories stored in PostgreSQL database
- No data leaves your infrastructure

## Documentation Links

- **Hindsight Server Research**: `~/hindsight-server-research.md`
- **Custom MCP Server README**: `hindsight-mcp-server/README.md`
- **Setup Guide**: `hindsight-mcp-server/SETUP-GUIDE.md`
- **Hindsight GitHub**: https://github.com/vectorize-io/hindsight
- **MCP Protocol**: https://github.com/anthropics/mcp

## Changelog

### v1.0.0 (2026-01-25)
- Initial Hindsight integration
- Auto-capture hook with importance scoring
- SSE MCP server configuration
- Custom stdio MCP server (alternative)
- Tag system with auto-expiry
- Deduplication for bash commands
- 7 MCP tools: retain, recall, reflect, list_banks, create_bank, get_statistics, health_check
- Comprehensive filtering to reduce noise
- Portable setup for all personal Claude installs

---

**Support**: For issues, see TROUBLESHOOTING.md or open an issue at https://github.com/PakAbhishek/claude-code-config
