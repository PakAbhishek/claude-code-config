# Hindsight MCP Server Setup Guide

## ✅ Installation Complete!

Your custom Hindsight MCP server has been successfully installed and tested.

## 🎯 Next Steps: Configure Claude Code

### 1. Open Claude Code Settings

Navigate to your Claude Code settings file:
```
~/.claude/settings.json
```

### 2. Add the MCP Server Configuration

Add this to your `mcpServers` section:

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

**Full example settings.json:**
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

### 3. Restart Claude Code

Completely restart Claude Code for the changes to take effect.

### 4. Verify Installation

In Claude Code, ask:
```
What tools are available?
```

You should see 7 Hindsight tools:
- ✅ retain
- ✅ recall
- ✅ reflect
- ✅ list_banks
- ✅ create_bank
- ✅ get_statistics
- ✅ health_check

## 🚀 Quick Start Examples

### Store Your First Memory

```
Use the retain tool to remember: "I successfully set up the custom Hindsight MCP server on January 25, 2026. It provides 7 tools for memory management."
```

### Search Your Memories

```
Use recall to find: "What did I do with Hindsight?"
```

### Get Insights

```
Use reflect to analyze: "What have I accomplished with Claude Code this month?"
```

### Check Server Status

```
Use health_check to verify the Hindsight server is connected
```

## 📊 Available Tools

### 1. **retain** - Store Memories
Store any information you want to remember later. Automatically extracts entities and creates relationships.

**Example Usage:**
```
Use retain to remember: "AWS SSO authentication requires both sso-session config and profile config"
```

**Parameters:**
- `content` (required): What to remember
- `context` (optional): Category like "learning", "decision", "debugging"
- `tags` (optional): Tags for filtering
- `timestamp` (optional): When this happened

### 2. **recall** - Search Memories
Search your stored memories using semantic search, keywords, entity relationships, and time ranges.

**Example Usage:**
```
Use recall to find: "What did I learn about AWS authentication?"
```

**Parameters:**
- `query` (required): Natural language search
- `max_tokens` (optional): Result size (default: 4096)
- `budget` (optional): "LOW" (fast), "MID" (balanced), "HIGH" (comprehensive)
- `types` (optional): Filter by "world", "experience", "mental_model"
- `tags` (optional): Filter by tags

### 3. **reflect** - Generate Insights
Synthesize multiple memories to answer complex questions or identify patterns.

**Example Usage:**
```
Use reflect to analyze: "What patterns emerge from my coding sessions?"
```

**Parameters:**
- `query` (required): Question or topic
- `context` (optional): Additional context
- `budget` (optional): "low", "mid", "high"
- `max_tokens` (optional): Response length

### 4. **list_banks** - View Memory Banks
See all available memory banks and their configurations.

**Example Usage:**
```
Use list_banks to see all memory banks
```

### 5. **create_bank** - Create Memory Bank
Create a new isolated memory bank for a specific project or context.

**Example Usage:**
```
Use create_bank to create a bank called "smart-test-generator" with mission "Track project decisions and learnings"
```

**Parameters:**
- `bank_id` (required): Unique identifier
- `name` (optional): Display name
- `mission` (optional): Purpose description
- `disposition` (optional): Personality traits (1-5 scale)

### 6. **get_statistics** - View Stats
Get analytics about your memory bank: total memories, types, entities, links.

**Example Usage:**
```
Use get_statistics to see memory bank stats
```

### 7. **health_check** - Check Connection
Verify the MCP server is connected to Hindsight.

**Example Usage:**
```
Use health_check to verify Hindsight is connected
```

## 🎨 Best Practices

### 1. Capture Decisions
Whenever you make an important decision, store it:
```
Use retain to remember: "Decided to use TypeScript for the MCP server because it provides better type safety and IDE support"
```

### 2. Log Learnings
Store insights and "aha moments":
```
Use retain to remember: "Learned that the MCP protocol uses stdio transport for communication between Claude Code and the server"
```

### 3. Tag Consistently
Use tags to organize memories:
```
Use retain with tags ["typescript", "mcp", "development"] to remember: "Successfully implemented MCP tools using the @modelcontextprotocol/sdk package"
```

### 4. Regular Reflection
Weekly or after major milestones:
```
Use reflect to analyze: "What did I learn this week about building MCP servers?"
```

### 5. Project-Specific Banks
Create separate banks for different projects:
```
Use create_bank to create "project-alpha" with mission "Track architecture decisions and technical debt"
```

## 🔧 Troubleshooting

### Tools Not Showing Up

1. **Check settings.json syntax:**
   - Must be valid JSON
   - Path must use forward slashes or escaped backslashes
   - No trailing commas

2. **Verify file path:**
   ```bash
   ls -la /c/Users/achau/hindsight-mcp-server/dist/index.js
   ```

3. **Check Claude Code logs:**
   - Settings → View Logs
   - Look for MCP server errors

4. **Test server manually:**
   ```bash
   cd ~/hindsight-mcp-server
   node dist/index.js
   ```
   Should print startup messages without errors.

### "Could not connect to Hindsight"

1. **Verify Hindsight is running:**
   ```bash
   curl http://34.174.13.163:8888/health
   ```
   Should return: `{"status":"healthy","database":"connected"}`

2. **Check .env file:**
   ```bash
   cat ~/hindsight-mcp-server/.env
   ```
   Verify `HINDSIGHT_URL=http://34.174.13.163:8888`

3. **Test connection manually:**
   ```bash
   curl http://34.174.13.163:8888/v1/default/banks/claude-code/stats
   ```

### Server Crashes

1. **Check for build errors:**
   ```bash
   cd ~/hindsight-mcp-server
   npm run build
   ```

2. **View error logs:**
   ```bash
   node dist/index.js 2> error.log
   cat error.log
   ```

3. **Reinstall dependencies:**
   ```bash
   cd ~/hindsight-mcp-server
   rm -rf node_modules package-lock.json
   npm install
   npm run build
   ```

## 🔄 Updating the Server

### Rebuild After Code Changes

```bash
cd ~/hindsight-mcp-server
npm run build
# Restart Claude Code
```

### Update Dependencies

```bash
cd ~/hindsight-mcp-server
npm update
npm run build
```

## 📚 Documentation

- **MCP Server README**: `~/hindsight-mcp-server/README.md`
- **Hindsight Research**: `~/hindsight-server-research.md`
- **Hindsight GitHub**: https://github.com/vectorize-io/hindsight
- **MCP Protocol**: https://github.com/anthropics/mcp

## 🎉 Success Indicators

You'll know everything is working when:

1. ✅ Claude Code shows Hindsight tools in the tools list
2. ✅ `health_check` returns "Status: healthy"
3. ✅ `retain` successfully stores memories
4. ✅ `recall` finds your stored memories
5. ✅ `get_statistics` shows increasing memory counts

## 💡 Power User Tips

### Automatic Context Capture

Create a habit of storing context at session start:
```
Use retain to remember: "Starting new session on [date]. Working on [project]. Goals: [list goals]"
```

### Weekly Summaries

Every Friday:
```
Use reflect to summarize: "What progress did I make this week? What challenges did I overcome?"
```

### Project Retrospectives

After completing a project:
```
Use reflect to analyze: "What went well? What could be improved? What did I learn?"
```

### Knowledge Base Building

Tag related memories:
```
Use retain with tags ["aws", "authentication", "troubleshooting"] to remember: "[detailed solution]"
```

Then later:
```
Use recall with tags ["troubleshooting"] to find all troubleshooting notes
```

---

## 🎊 You're All Set!

Your custom Hindsight MCP server is ready to use. Start capturing your knowledge and let Hindsight help you remember, search, and reflect on your work!

**Next:** Try the Quick Start Examples above to test all the tools.
