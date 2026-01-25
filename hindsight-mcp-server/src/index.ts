#!/usr/bin/env node

/**
 * Hindsight MCP Server
 * A Model Context Protocol server for Hindsight memory management
 * Provides automated memory retention for Claude Code activities
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool
} from '@modelcontextprotocol/sdk/types.js';
import { HindsightClient } from './hindsight-client.js';
import * as dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Configuration
const HINDSIGHT_URL = process.env.HINDSIGHT_URL || 'http://34.174.13.163:8888';
const HINDSIGHT_BANK_ID = process.env.HINDSIGHT_BANK_ID || 'claude-code';
const HINDSIGHT_API_KEY = process.env.HINDSIGHT_API_KEY;

// Initialize Hindsight client
const hindsight = new HindsightClient({
  baseUrl: HINDSIGHT_URL,
  defaultBankId: HINDSIGHT_BANK_ID,
  apiKey: HINDSIGHT_API_KEY,
  timeout: 60000  // 60 second timeout
});

// MCP Server
const server = new Server(
  {
    name: 'hindsight-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Define MCP Tools
const TOOLS: Tool[] = [
  {
    name: 'retain',
    description: 'Store information in Hindsight memory bank. Use this to save important facts, learnings, decisions, or context for future recall. Automatically extracts entities and creates relationships.',
    inputSchema: {
      type: 'object',
      properties: {
        content: {
          type: 'string',
          description: 'The information to remember. Can be facts, observations, decisions, or learnings.',
        },
        context: {
          type: 'string',
          description: 'Optional context category (e.g., "project", "debugging", "decision", "learning"). Defaults to "general".',
        },
        timestamp: {
          type: 'string',
          description: 'Optional ISO 8601 timestamp. Defaults to current time.',
        },
        bank_id: {
          type: 'string',
          description: `Optional memory bank ID. Defaults to "${HINDSIGHT_BANK_ID}".`,
        },
        tags: {
          type: 'array',
          items: { type: 'string' },
          description: 'Optional tags for filtering memories later.',
        },
      },
      required: ['content'],
    },
  },
  {
    name: 'recall',
    description: 'Search Hindsight memory bank using multi-strategy retrieval (semantic, keyword, graph, temporal). Returns relevant memories matching the query.',
    inputSchema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Natural language search query (e.g., "What did I learn about AWS yesterday?")',
        },
        max_tokens: {
          type: 'number',
          description: 'Maximum response size in tokens. Default: 4096',
        },
        bank_id: {
          type: 'string',
          description: `Optional memory bank ID. Defaults to "${HINDSIGHT_BANK_ID}".`,
        },
        types: {
          type: 'array',
          items: {
            type: 'string',
            enum: ['world', 'experience', 'mental_model'],
          },
          description: 'Filter by memory types: "world" (facts), "experience" (interactions), "mental_model" (derived observations).',
        },
        budget: {
          type: 'string',
          enum: ['LOW', 'MID', 'HIGH'],
          description: 'Computation budget for retrieval. LOW=fast, HIGH=comprehensive. Default: MID',
        },
        query_timestamp: {
          type: 'string',
          description: 'Optional ISO 8601 timestamp to search memories relative to this time.',
        },
        tags: {
          type: 'array',
          items: { type: 'string' },
          description: 'Filter memories by tags.',
        },
      },
      required: ['query'],
    },
  },
  {
    name: 'reflect',
    description: 'Generate insights by combining stored memories with reasoning. Synthesizes knowledge to answer complex questions or provide analysis.',
    inputSchema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Question or topic for reflection (e.g., "What patterns emerge from my debugging sessions?")',
        },
        context: {
          type: 'string',
          description: 'Optional additional context to guide the reflection.',
        },
        budget: {
          type: 'string',
          enum: ['low', 'mid', 'high'],
          description: 'Computation budget: low=quick, high=comprehensive. Default: mid',
        },
        bank_id: {
          type: 'string',
          description: `Optional memory bank ID. Defaults to "${HINDSIGHT_BANK_ID}".`,
        },
        max_tokens: {
          type: 'number',
          description: 'Maximum response length in tokens. Default: 2048',
        },
        tags: {
          type: 'array',
          items: { type: 'string' },
          description: 'Filter memories by tags before reflecting.',
        },
      },
      required: ['query'],
    },
  },
  {
    name: 'list_banks',
    description: 'List all available Hindsight memory banks with their profiles and configurations.',
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
  {
    name: 'create_bank',
    description: 'Create a new Hindsight memory bank or retrieve existing one. Each bank is an isolated namespace with its own memories and personality.',
    inputSchema: {
      type: 'object',
      properties: {
        bank_id: {
          type: 'string',
          description: 'Unique identifier for the memory bank (e.g., "project-alpha", "personal").',
        },
        name: {
          type: 'string',
          description: 'Display name for the bank. Defaults to bank_id.',
        },
        mission: {
          type: 'string',
          description: 'Mission statement describing the purpose of this memory bank.',
        },
        disposition: {
          type: 'object',
          properties: {
            skepticism: {
              type: 'number',
              minimum: 1,
              maximum: 5,
              description: 'Skepticism level (1=trusting, 5=skeptical). Default: 3',
            },
            literalism: {
              type: 'number',
              minimum: 1,
              maximum: 5,
              description: 'Literalism level (1=flexible, 5=literal). Default: 3',
            },
            empathy: {
              type: 'number',
              minimum: 1,
              maximum: 5,
              description: 'Empathy level (1=detached, 5=empathetic). Default: 3',
            },
          },
          description: 'Personality traits that influence memory interpretation.',
        },
      },
      required: ['bank_id'],
    },
  },
  {
    name: 'get_statistics',
    description: 'Get statistics about a memory bank: total memories, memory types, links, entities, and last update time.',
    inputSchema: {
      type: 'object',
      properties: {
        bank_id: {
          type: 'string',
          description: `Optional memory bank ID. Defaults to "${HINDSIGHT_BANK_ID}".`,
        },
      },
    },
  },
  {
    name: 'health_check',
    description: 'Check if Hindsight server is healthy and database is connected.',
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
];

// Register tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'retain': {
        const schema = z.object({
          content: z.string(),
          context: z.string().optional(),
          timestamp: z.string().optional(),
          bank_id: z.string().optional(),
          tags: z.array(z.string()).optional(),
        });
        const input = schema.parse(args);

        const result = await hindsight.retain(input);

        return {
          content: [
            {
              type: 'text',
              text: result.status === 'success'
                ? `✓ Memory stored successfully.\nMemory ID: ${result.memory_id || 'N/A'}\n\nContent: ${input.content.substring(0, 200)}${input.content.length > 200 ? '...' : ''}`
                : `✗ Failed to store memory: ${result.detail || result.error}`,
            },
          ],
        };
      }

      case 'recall': {
        const schema = z.object({
          query: z.string(),
          max_tokens: z.number().optional(),
          bank_id: z.string().optional(),
          types: z.array(z.enum(['world', 'experience', 'mental_model'])).optional(),
          budget: z.enum(['LOW', 'MID', 'HIGH']).optional(),
          query_timestamp: z.string().optional(),
          tags: z.array(z.string()).optional(),
        });
        const input = schema.parse(args);

        const result = await hindsight.recall(input);

        // Format results
        let text = `Found ${result.results.length} memories for query: "${input.query}"\n\n`;

        if (result.results.length === 0) {
          text += 'No memories found matching this query.';
        } else {
          result.results.forEach((memory, idx) => {
            text += `--- Memory ${idx + 1} ---\n`;
            text += `Type: ${memory.type}\n`;
            text += `Text: ${memory.text}\n`;
            if (memory.entities.length > 0) {
              text += `Entities: ${memory.entities.join(', ')}\n`;
            }
            if (memory.mentioned_at) {
              text += `Mentioned: ${memory.mentioned_at}\n`;
            }
            if (memory.relevance_score) {
              text += `Relevance: ${(memory.relevance_score * 100).toFixed(1)}%\n`;
            }
            text += '\n';
          });
        }

        if (result.trace) {
          text += `\n--- Retrieval Info ---\n`;
          text += `Strategy: ${result.trace.retrieval_strategy || 'N/A'}\n`;
          text += `Processing Time: ${result.trace.processing_time_ms || 'N/A'}ms\n`;
        }

        return {
          content: [
            {
              type: 'text',
              text,
            },
          ],
        };
      }

      case 'reflect': {
        const schema = z.object({
          query: z.string(),
          context: z.string().optional(),
          budget: z.enum(['low', 'mid', 'high']).optional(),
          bank_id: z.string().optional(),
          max_tokens: z.number().optional(),
          tags: z.array(z.string()).optional(),
        });
        const input = schema.parse(args);

        const result = await hindsight.reflect(input);

        let text = `Reflection on: "${input.query}"\n\n`;
        text += result.text;

        if (result.based_on?.facts && result.based_on.facts.length > 0) {
          text += `\n\n--- Based On ${result.based_on.facts.length} Memories ---\n`;
          result.based_on.facts.slice(0, 3).forEach((fact, idx) => {
            text += `${idx + 1}. ${fact.text.substring(0, 100)}...\n`;
          });
        }

        if (result.usage) {
          text += `\n--- Usage ---\n`;
          text += `Input Tokens: ${result.usage.input_tokens}\n`;
          text += `Output Tokens: ${result.usage.output_tokens}\n`;
        }

        return {
          content: [
            {
              type: 'text',
              text,
            },
          ],
        };
      }

      case 'list_banks': {
        const result = await hindsight.listBanks();

        let text = `Available Memory Banks: ${result.banks.length}\n\n`;

        result.banks.forEach((bank, idx) => {
          text += `${idx + 1}. ${bank.name} (${bank.bank_id})\n`;
          if (bank.mission) {
            text += `   Mission: ${bank.mission}\n`;
          }
          text += `   Disposition: Skepticism=${bank.disposition.skepticism}, Literalism=${bank.disposition.literalism}, Empathy=${bank.disposition.empathy}\n`;
          text += '\n';
        });

        return {
          content: [
            {
              type: 'text',
              text,
            },
          ],
        };
      }

      case 'create_bank': {
        const schema = z.object({
          bank_id: z.string(),
          name: z.string().optional(),
          mission: z.string().optional(),
          disposition: z
            .object({
              skepticism: z.number().min(1).max(5).optional(),
              literalism: z.number().min(1).max(5).optional(),
              empathy: z.number().min(1).max(5).optional(),
            })
            .optional(),
        });
        const input = schema.parse(args);

        const result = await hindsight.createBank(input);

        const text =
          `✓ Memory bank created/retrieved: ${result.name}\n\n` +
          `Bank ID: ${result.bank_id}\n` +
          `Mission: ${result.mission || 'Not set'}\n` +
          `Disposition:\n` +
          `  - Skepticism: ${result.disposition.skepticism}/5\n` +
          `  - Literalism: ${result.disposition.literalism}/5\n` +
          `  - Empathy: ${result.disposition.empathy}/5\n`;

        return {
          content: [
            {
              type: 'text',
              text,
            },
          ],
        };
      }

      case 'get_statistics': {
        const schema = z.object({
          bank_id: z.string().optional(),
        });
        const input = schema.parse(args);

        const result = await hindsight.getStatistics(input.bank_id);

        const text =
          `Memory Bank Statistics\n\n` +
          `Total Memories: ${result.total_memories}\n` +
          `  - World Facts: ${result.world_facts}\n` +
          `  - Experiences: ${result.experiences}\n` +
          `  - Opinions: ${result.opinions}\n` +
          `Total Links: ${result.total_links.toLocaleString()}\n` +
          `Total Entities: ${result.total_entities.toLocaleString()}\n` +
          `Last Updated: ${result.last_updated}\n`;

        return {
          content: [
            {
              type: 'text',
              text,
            },
          ],
        };
      }

      case 'health_check': {
        const result = await hindsight.healthCheck();

        const text =
          `Hindsight Server Health\n\n` +
          `Status: ${result.status}\n` +
          `Database: ${result.database}\n` +
          `URL: ${HINDSIGHT_URL}\n` +
          `Default Bank: ${HINDSIGHT_BANK_ID}\n`;

        return {
          content: [
            {
              type: 'text',
              text,
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new Error(`Invalid arguments: ${error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join(', ')}`);
    }
    throw error;
  }
});

// Start server
async function main() {
  console.error('🚀 Starting Hindsight MCP Server...');
  console.error(`   URL: ${HINDSIGHT_URL}`);
  console.error(`   Default Bank: ${HINDSIGHT_BANK_ID}`);

  // Test connection
  try {
    const health = await hindsight.healthCheck();
    console.error(`✓ Connected to Hindsight (Status: ${health.status})`);
  } catch (error) {
    console.error(`✗ Warning: Could not connect to Hindsight server`);
    console.error(`  Error: ${error instanceof Error ? error.message : String(error)}`);
    console.error(`  Server will start but tools may fail until connection is restored.`);
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error('✓ MCP Server ready and listening on stdio');
  console.error(`   Available tools: ${TOOLS.map((t) => t.name).join(', ')}`);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
