# Hindsight MCP Server

A custom Model Context Protocol (MCP) server for [Hindsight](https://github.com/vectorize-io/hindsight) that provides automated memory retention and recall capabilities for Claude Code.

## Features

- **7 MCP Tools** for comprehensive memory management:
  - `retain` - Store information with automatic entity extraction
  - `recall` - Multi-strategy memory search (semantic + keyword + graph + temporal)
  - `reflect` - Generate insights by synthesizing stored memories
  - `list_banks` - View all available memory banks
  - `create_bank` - Create isolated memory namespaces
  - `get_statistics` - View memory bank analytics
  - `health_check` - Monitor server connectivity

- **Automatic Memory Retention** - Capture key activities from Claude Code
- **Entity Tracking** - Automatically extract and link entities (people, places, tools, projects)
- **Temporal Queries** - Search memories by time range
- **Multi-Bank Support** - Isolate memories by project or context
- **Type Safety** - Full TypeScript implementation with Zod validation

## Quick Start

### 1. Installation

```bash
cd ~/hindsight-mcp-server
npm install
```

### 2. Configuration

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env`:

```env
HINDSIGHT_URL=http://34.174.13.163:8888
HINDSIGHT_BANK_ID=claude-code
```

### 3. Build

```bash
npm run build
```

### 4. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "hindsight": {
      "command": "node",
      "args": [
        "/c/Users/achau/hindsight-mcp-server/dist/index.js"
      ]
    }
  }
}
```

### 5. Restart Claude Code

The MCP server will now be available with the `hindsight` tools.

## Usage Examples

### Store a Memory

```
Use the retain tool to remember: "I learned that AWS SSO requires both sso-session config and profile config in ~/.aws/config for proper authentication flow"
```

Claude Code will call:
```typescript
retain({
  content: "AWS SSO requires both sso-session config and profile config in ~/.aws/config for proper authentication flow",
  context: "learning",
  tags: ["aws", "authentication"]
})
```

### Search Memories

```
Use recall to search: "What did I learn about AWS authentication?"
```

Claude Code will call:
```typescript
recall({
  query: "What did I learn about AWS authentication?",
  max_tokens: 4096,
  budget: "MID"
})
```

### Generate Insights

```
Use reflect to analyze: "What patterns emerge from my debugging sessions this week?"
```

Claude Code will call:
```typescript
reflect({
  query: "What patterns emerge from my debugging sessions this week?",
  budget: "mid"
})
```

### View Statistics

```
Use get_statistics to see memory bank stats
```

Claude Code will call:
```typescript
get_statistics({ bank_id: "claude-code" })
```

## Tool Reference

### retain

Store information in Hindsight with automatic entity extraction and relationship creation.

**Parameters:**
- `content` (required): The information to remember
- `context` (optional): Category (e.g., "learning", "decision", "debugging")
- `timestamp` (optional): ISO 8601 timestamp
- `bank_id` (optional): Target memory bank
- `tags` (optional): Array of tags for filtering

**Example:**
```typescript
retain({
  content: "User prefers async/await over Promise chains",
  context: "coding_preference",
  tags: ["javascript", "async"]
})
```

### recall

Search memories using multi-strategy retrieval (semantic, keyword, graph, temporal).

**Parameters:**
- `query` (required): Natural language search query
- `max_tokens` (optional): Maximum response size (default: 4096)
- `bank_id` (optional): Target memory bank
- `types` (optional): Filter by ["world", "experience", "mental_model"]
- `budget` (optional): "LOW" | "MID" | "HIGH" (default: "MID")
- `query_timestamp` (optional): Search relative to this time
- `tags` (optional): Filter by tags

**Example:**
```typescript
recall({
  query: "What debugging techniques worked for the database issue?",
  types: ["experience"],
  budget: "HIGH",
  tags: ["debugging", "database"]
})
```

### reflect

Generate insights by combining memories with reasoning.

**Parameters:**
- `query` (required): Question or topic for reflection
- `context` (optional): Additional context
- `budget` (optional): "low" | "mid" | "high" (default: "mid")
- `bank_id` (optional): Target memory bank
- `max_tokens` (optional): Maximum response length (default: 2048)
- `tags` (optional): Filter memories before reflecting

**Example:**
```typescript
reflect({
  query: "What have I learned about effective code review?",
  budget: "high"
})
```

### list_banks

List all available memory banks with their configurations.

**Parameters:** None

**Returns:** Array of banks with bank_id, name, mission, disposition

### create_bank

Create a new memory bank or retrieve existing one.

**Parameters:**
- `bank_id` (required): Unique identifier
- `name` (optional): Display name
- `mission` (optional): Purpose description
- `disposition` (optional): Personality traits (skepticism, literalism, empathy: 1-5)

**Example:**
```typescript
create_bank({
  bank_id: "smart-test-generator",
  name: "Smart Test Generator Project",
  mission: "Track decisions and learnings for the test generator project",
  disposition: {
    skepticism: 4,
    literalism: 3,
    empathy: 2
  }
})
```

### get_statistics

Get analytics for a memory bank.

**Parameters:**
- `bank_id` (optional): Target bank (default: configured bank)

**Returns:** Total memories, memory types, links, entities, last update time

### health_check

Check if Hindsight server is accessible and database is connected.

**Parameters:** None

**Returns:** Server status, database status, URL, default bank

## Advanced Configuration

### Multiple Memory Banks

Create separate banks for different projects:

```json
{
  "mcpServers": {
    "hindsight-personal": {
      "command": "node",
      "args": ["/c/Users/achau/hindsight-mcp-server/dist/index.js"],
      "env": {
        "HINDSIGHT_BANK_ID": "personal"
      }
    },
    "hindsight-work": {
      "command": "node",
      "args": ["/c/Users/achau/hindsight-mcp-server/dist/index.js"],
      "env": {
        "HINDSIGHT_BANK_ID": "work-projects"
      }
    }
  }
}
```

### Custom Hindsight Server

Point to a different Hindsight instance:

```json
{
  "mcpServers": {
    "hindsight": {
      "command": "node",
      "args": ["/c/Users/achau/hindsight-mcp-server/dist/index.js"],
      "env": {
        "HINDSIGHT_URL": "http://your-server.com:8888",
        "HINDSIGHT_BANK_ID": "custom-bank"
      }
    }
  }
}
```

### Authentication

If your Hindsight server requires authentication:

```env
HINDSIGHT_API_KEY=your-secret-api-key
```

## Development

### Run in Development Mode

```bash
npm run dev
```

This uses `tsx` to watch for changes and reload automatically.

### Build for Production

```bash
npm run build
```

### Test MCP Inspector

```bash
npm run inspector
```

Opens the MCP Inspector UI for testing tools interactively.

### Project Structure

```
hindsight-mcp-server/
├── src/
│   ├── index.ts              # Main MCP server
│   ├── hindsight-client.ts   # HTTP API wrapper
│   └── types.ts              # TypeScript type definitions
├── dist/                     # Compiled JavaScript (generated)
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

## Troubleshooting

### "Could not connect to Hindsight server"

Check that:
1. Hindsight server is running: `curl http://34.174.13.163:8888/health`
2. URL in `.env` is correct
3. No firewall blocking port 8888

### "Invalid arguments" Error

Check that you're passing required parameters:
- `retain` requires `content`
- `recall` requires `query`
- `reflect` requires `query`
- `create_bank` requires `bank_id`

### Tools Not Appearing in Claude Code

1. Verify `settings.json` syntax is valid JSON
2. Restart Claude Code completely
3. Check logs: Claude Code → Settings → View Logs
4. Run `node dist/index.js` manually to see startup errors

### Server Crashes

Check stderr output:
```bash
node dist/index.js 2> error.log
```

Common issues:
- Missing `node_modules` - run `npm install`
- TypeScript not compiled - run `npm run build`
- Invalid `.env` values - check `.env.example`

## Performance Tips

### Budget Levels

- `"LOW"` / `"low"` - Fast, basic results (~100ms)
- `"MID"` / `"mid"` - Balanced, good quality (~500ms)
- `"HIGH"` / `"high"` - Comprehensive, best results (~2s)

### Token Limits

- `max_tokens` for `recall`: 4096 (default) - 8192 (high detail)
- `max_tokens` for `reflect`: 2048 (default) - 4096 (comprehensive)

### Memory Types

Filter by type for faster searches:
- `["world"]` - Facts only
- `["experience"]` - Interactions only
- `["mental_model"]` - Derived observations only

## Integration with Claude Code

### Automatic Capture (Future Feature)

The server can be extended with hooks to automatically capture:
- File edits (Write, Edit tools)
- Command executions (Bash tool)
- Git commits
- Error occurrences
- Debugging sessions

This requires custom hooks in Claude Code settings.

### Manual Retention Best Practices

1. **Capture Decisions**: Use `retain` after making important decisions
2. **Log Learnings**: Store "aha moments" and troubleshooting insights
3. **Tag Strategically**: Use consistent tags like "bug-fix", "feature", "learning"
4. **Add Context**: Always include `context` parameter for better categorization
5. **Regular Reflection**: Use `reflect` weekly to synthesize patterns

## API Documentation

Full Hindsight API docs: https://github.com/vectorize-io/hindsight

Key endpoints used:
- `POST /v1/default/banks/{bank_id}/memories/retain`
- `POST /v1/default/banks/{bank_id}/memories/recall`
- `POST /v1/default/banks/{bank_id}/reflect`
- `GET /v1/default/banks`
- `GET /health`

## License

MIT

## Support

For issues with:
- **This MCP server**: Open issue on your repo
- **Hindsight core**: https://github.com/vectorize-io/hindsight/issues
- **MCP protocol**: https://github.com/anthropics/mcp/issues
- **Claude Code**: https://github.com/anthropics/claude-code/issues

## Changelog

### v1.0.0 (2026-01-25)

- Initial release
- 7 MCP tools: retain, recall, reflect, list_banks, create_bank, get_statistics, health_check
- Full TypeScript implementation
- Zod validation for all inputs
- Comprehensive error handling
- Health check on startup
- Support for multiple memory banks
- Tag-based filtering
- Temporal queries
- Budget control for retrieval/reflection
