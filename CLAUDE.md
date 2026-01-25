# Claude Code Agent Configuration

# 🚨🔴 STOP! READ THIS BEFORE ANY FILE OPERATION 🔴🚨

## ⛔ MANDATORY PRE-WRITE SECURITY CHECK ⛔

**BEFORE using Write, Edit, NotebookEdit, OR Bash (for file creation) on ANY file, I MUST:**

```
reflect("SOC 2 security scan for content I'm about to write")
```

### 🎯 APPLIES TO ALL FILE TYPES:
- Code: `.py`, `.js`, `.ts`, `.java`, `.go`, `.rs`, `.cs`, `.rb`, `.php`, `.sh`, `.ps1`, `.bat`
- Config: `.json`, `.yaml`, `.yml`, `.toml`, `.ini`, `.xml`, `.env*`, `.config`
- Notebooks: `.ipynb`
- Scripts: Any file that could contain secrets

### 🚫 FORBIDDEN PATTERNS (Expanded):

| CATEGORY | PATTERNS TO DETECT |
|----------|-------------------|
| **SECRETS** | `password`, `passwd`, `pwd`, `pass`, `secret`, `api_key`, `apikey`, `api-key`, `token`, `bearer`, `auth`, `credential`, `cred` followed by `=`, `:`, or assignment |
| **AWS** | `AKIA`, `ASIA`, `aws_access_key`, `aws_secret`, any 40-char base64 after key pattern |
| **PRIVATE IPs** | `10.x.x.x`, `192.168.x.x`, `172.16-31.x.x`, `127.x.x.x` (except localhost in dev) |
| **INTERNAL URLs** | `.internal`, `.local`, `.corp`, `.lan`, `.private`, `intranet` |
| **CONN STRINGS** | `://` with `user:pass@` OR any DB URL with embedded credentials |
| **PII** | SSN (`XXX-XX-XXXX`), real emails with names, phone patterns, credit card patterns |
| **UNSAFE CODE** | `eval()`, `exec()`, `shell=True`, `pickle.loads()` on untrusted, `subprocess` with user input |
| **ENCODED SECRETS** | Base64 strings that decode to secrets, hex-encoded credentials |
| **COMMENTS WITH SECRETS** | `# password:`, `// token:`, `/* secret */` with actual values |

### 🛡️ BYPASS PREVENTION:

| ATTACK VECTOR | COUNTERMEASURE |
|---------------|----------------|
| **Bash file creation** | Scan content of ANY `echo >`, `cat >`, heredoc, `printf >` |
| **Encoded values** | Decode base64/hex and scan result |
| **Split variables** | Look for reassembly patterns |
| **NotebookEdit** | Same rules apply to notebook cells |
| **Config files** | JSON/YAML/TOML get SAME scrutiny as code |

## 🛑 IF ANY VIOLATION FOUND:

1. **❌ DO NOT WRITE** - Hook automatically blocks the operation
2. **🚨 ALERT:** "SOC 2 VIOLATION DETECTED: [specific issue]"
3. **✅ PROVIDE COMPLIANT VERSION** using environment variables

## 🔓 SECURITY OVERRIDE (Rare Use Cases Only)

**When overrides are legitimate:**
- Security testing and penetration testing
- Educational examples for training
- Vulnerability disclosure and research
- Testing the SOC 2 hook itself
- Honeypot/canary credentials

**How to override:**
Add one of these comments in the **first 10 lines** of the file:

```python
# SOC2_OVERRIDE: Security testing
# Your justification here

# Now the hook will allow violations but log them
TEST_CREDENTIALS = "actual-credentials-here"  # Allowed with override
```

**Supported comment styles:**
```python
# SOC2_OVERRIDE: Security testing          # Python, Ruby, Shell
// SOC2_OVERRIDE: Educational example      # JavaScript, C, Java
/* SOC2_OVERRIDE: Penetration testing */   # Multi-line comments
```

**Valid override reasons:**
- `Security testing`
- `Educational example`
- `Testing hook itself`
- `Penetration testing`
- `Security research`
- `Vulnerability disclosure`
- `Training material`
- `Honeypot credentials`

**Important:**
- Override comment MUST be in first 10 lines
- Hook still scans and logs violations
- Override is self-documenting (visible in code)
- Can be audited with: `grep -r "SOC2_OVERRIDE" .`

## ✅ COMPLIANT PATTERNS:
```python
import os
from dotenv import load_dotenv
load_dotenv()

DB_HOST = os.environ["DB_HOST"]           # ✅ From environment
DB_PASSWORD = os.environ["DB_PASSWORD"]   # ✅ Never hardcoded
API_KEY = os.environ.get("API_KEY")       # ✅ Safe
```

---

# 🛑🧠 STOP! UNDERSTAND BEFORE CHANGING 🧠🛑

## ⚠️ MANDATORY LEARNING CHECK ⚠️

**BEFORE making code changes to ANY system I don't fully understand, I MUST:**

### 🚨 TRIGGER CONDITIONS:
- Working with unfamiliar APIs, protocols, or services (AWS SSO, OAuth, etc.)
- Second "fix" attempt on the same problem (I'm guessing, not understanding)
- User expresses frustration with repeated failures
- Error messages I can't fully explain

### 📋 MANDATORY SEQUENCE:

| Step | Action | Output |
|------|--------|--------|
| 1. **STOP** | Admit "I don't understand this system well enough" | Say it to user |
| 2. **LEARN** | Read docs, ask user to explain, trace FULL flow | Written notes |
| 3. **EXPLAIN** | Write out my understanding of the system | Get user confirmation |
| 4. **PLAN** | Describe ONE informed change and why it will work | User approves |
| 5. **CHANGE** | Make the single change | Code edit |
| 6. **TEST** | Verify the FULL flow, not just the symptom | End-to-end proof |

### 🔴 SELF-CHECK - AM I GUESSING?

If ANY of these are true, **GO BACK TO STEP 1**:
- [ ] I'm making a second fix to the same problem
- [ ] I can't explain WHY my fix will work
- [ ] I'm hoping this works rather than knowing it will
- [ ] I haven't traced the full code path
- [ ] User has to test because I can't verify myself

### 📖 LEARNED THE HARD WAY (2026-01-18):
AWS SSO Team Installer - 6 hours of debugging because I kept guessing instead of learning:
- `aws sso login` vs `aws configure sso` - different purposes
- PowerShell `@()` for arrays - single items become strings
- Claude Code needs BOTH `awsAuthRefresh` AND `AWS_PROFILE` env var

**The cost of guessing: 6 hours of user's time, eroded trust.**

### 📝 PRE-CHANGE CHECKLIST (ENFORCED BY HOOK)

**BEFORE calling Edit or Write on ANY file, I MUST output this checklist:**

```markdown
## Pre-Change Checklist
- [ ] **Files read**: [list ALL files I've read - not just the error line]
- [ ] **Full code path traced**: [describe the execution flow I understand]
- [ ] **Why this fix works**: [explain the mechanism, not just "this should fix it"]
- [ ] **Attempt #**: [N] - if >1, STOP and go back to LEARN phase
```

**This is enforced by PreToolUse hook on Edit/Write.**
- Hook fires BEFORE every edit
- If I haven't output this checklist, I'm violating the protocol
- The checklist forces me to demonstrate understanding before changing code

**Example of CORRECT behavior:**

```
User: "Fix the installer bug"

Me: Let me read the full installer script first.
[Read tool - reads entire file]

Me: Now let me trace the code path...
[Explains the flow]

## Pre-Change Checklist
- [x] **Files read**: install-claude.sh (all 478 lines)
- [x] **Full code path traced**: Line 280-310 creates AWS config, line 345 runs aws sso login
- [x] **Why this fix works**: The config path was wrong (../ instead of ./), fixing it ensures the file is found
- [x] **Attempt #**: 1

[Edit tool - makes the change]
```

**Example of WRONG behavior (what I was doing):**

```
User: "Fix the installer bug"

Me: I see the error, let me fix it.
[Edit tool - changes something based on error message alone]
❌ NO CHECKLIST = VIOLATING PROTOCOL
```

### 📖 LEARNED THE HARD WAY (2026-01-19):
Mac Installer - 6 versions pushed (v1.4.1 through v1.4.6) because I kept:
- Reacting to error screenshots instead of reading the full script
- Making guesses instead of tracing code paths
- Using Jeff as the tester instead of understanding first

---

## 🌐 MULTI-MACHINE SETUP

**This file is synced via OneDrive to work across all your machines.**

---

## 🔴 INVIOLABLE STARTUP RULE 🔴

At the beginning of EVERY session or when answering the first substantial user query:

```
reflect("What is my startup protocol and how should I work with this user?")
```

This loads your complete agent configuration from Hindsight (cloud MCP server).

---

## Agent Protocol: Temporal Queries

**When user asks about recent work** (keywords: "yesterday", "recent", "what did we do", "summary of", "what happened", "last session"):

### MANDATORY 3-STEP SEQUENCE:

**Step 1: REFLECT FIRST**
```
reflect("What search strategy should I use for recent work queries?")
```

**Step 2: Apply Strategy**
Use specific terms returned:
- ✅ Project names (smart-test-generator, Transportation Project)
- ✅ Version numbers (v3.1.4, v3.1.3)
- ✅ Technology terms (Groq, LLM, Azure, Hindsight)
- ❌ NOT vague date queries alone

**Step 3: Execute Targeted Recalls**
Multiple specific recall queries with terms from Step 2.

---

## 🖥️ New Machine Setup

**ONE-CLICK INSTALLER - Just double-click and you're done!**

### 🚀 One-Click Installation (EASIEST)

#### Windows (Personal - Includes Hindsight)
1. Navigate to: `OneDrive\Claude Backup\claude-config\`
2. **Double-click**: `Install-Claude-Code.bat`
3. Follow GUI prompts
4. ✅ Done!

> **Note:** Personal installer is Windows-only. For Mac/Linux, use the Team Installer (see below).

**What the one-click installer does:**
1. ✅ Checks/installs Homebrew (Mac only)
2. ✅ Checks/installs Git (if needed)
3. ✅ Checks/installs Node.js (if needed)
4. ✅ Checks Python 3 is available (Mac/Linux)
5. ✅ Installs/updates Claude Code to latest version
6. ✅ Installs AWS CLI v2 (if needed)
7. ✅ Configures AWS SSO for Bedrock access (opens browser for PakEnergy SSO login)
8. ✅ Configures Hindsight MCP server automatically
9. ✅ Sets up CLAUDE.md auto-sync (symlink or hook)
10. ✅ Sets CLAUDE_MODEL environment variable for Bedrock

**After installation:**
- Claude Code ready to use immediately
- CLAUDE.md auto-syncs across all machines
- Settings.json with NEW hook format (auto-synced)
- SDLC enforcement hooks configured and synced
- Hindsight MCP server configured
- AWS Bedrock via SSO fully configured
- CLAUDE_MODEL env var set to Opus 4.5
- **AWS SSO credentials auto-refresh on each session start**
- Zero manual configuration needed

See [INSTALLER-README.md](./INSTALLER-README.md) for detailed installation guide.

### Manual Setup (Advanced Users Only)
If you prefer manual setup:

```bash
# Windows
copy "%USERPROFILE%\OneDrive\Claude Backup\claude-config\CLAUDE.md" "%USERPROFILE%\.claude\CLAUDE.md"

# Mac/Linux
cp "$HOME/OneDrive/Claude Backup/claude-config/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
```

Note: Manual setup requires re-running the copy command to sync updates.

### Verify MCP Server Connection
In Claude Code, run:
```
recall("test connection")
```
Should connect to: `http://34.174.13.163:8888` (GCP Compute Engine)

### 3. Verify MCP configuration
`~/.claude/settings.json` should have:
```json
{
  "mcpServers": {
    "hindsight": {
      "url": "http://34.174.13.163:8888/mcp/claude-code/"
    }
  }
}
```

---

## User Profile
- **Name:** Abhishek Chauhan (achau)
- **Primary Project:** Smart Test Generator (C:\smart-test-generator)
- **Organization:** PakEnergy

## User Preferences
- **Quality:** No compromises - cost is not an issue
- **Testing:** Always run deep tests before confirming changes work
- **Documentation:** Keep README, CLAUDE.md, CHANGELOG updated
- **Memory:** Hindsight MCP server (cloud-based, accessible from all machines)
- **Efficiency:** Values learning from mistakes, expects proactive improvement
- **Universality:** Solutions must work on any machine (Mac/Windows), not machine-specific

## Key Principle
**Be the best agent possible:** Store learnings, adapt strategies, prevent repeating inefficient patterns.

---

## 🔄 Auto-Sync Architecture

**How CLAUDE.md stays in sync:**

1. **Primary Method: Symbolic Link**
   - `~/.claude/CLAUDE.md` → symlink to OneDrive version
   - Real-time sync - changes appear instantly on all machines
   - Requires: Developer Mode (Windows) or standard permissions (Mac/Linux)

2. **Fallback Method: SessionStart Hook**
   - Hook runs when Claude Code starts
   - Copies latest version from OneDrive to `~/.claude/`
   - Sync delay: ~1 second on session start
   - Used when symlink creation fails (permissions, OS restrictions)

**What this means for you:**
- ✅ Edit CLAUDE.md in OneDrive → All machines get the update automatically
- ✅ No manual sync needed - just restart Claude Code (if using hook fallback)
- ✅ Works seamlessly whether you use Windows, Mac, or Linux

---

## 📋 Maintenance

**Synced Locations:**
- **Source of truth:** `~/OneDrive/Claude Backup/claude-config/CLAUDE.md`
- **Local reference:** `~/.claude/CLAUDE.md` (symlink or auto-synced copy)
- **Memory:** Hindsight cloud server (automatic, no sync needed)

**To update protocols across all machines:**
1. Edit the OneDrive version: `~/OneDrive/Claude Backup/claude-config/CLAUDE.md`
2. OneDrive syncs the file across machines
3. Local copies update automatically:
   - **Symlink**: Instant (real-time)
   - **Hook**: On next Claude Code start

**No manual sync needed!** The setup script handles everything automatically.

---

## Version History

> **Note:** Older versions (v3.0.1 - v3.0.19) archived in Hindsight. Query with: `recall("installer version history")`

### v3.0.26 (2026-01-22)
**Settings.json Auto-Sync with NEW Hook Format** - Fixed hook validation errors by migrating to new hook matcher format (`"tools": ["ToolName"]` instead of `"tool_name": "ToolName"`). Settings.json now syncs from OneDrive template across all machines, ensuring hook configurations, model settings, and permissions stay consistent. Both Windows and Mac/Linux installers updated.

### v3.0.25 (2026-01-20)
**SDLC Enforcement Hooks Auto-Sync** - Added automatic syncing of `~/.claude/hooks` directory across machines via OneDrive symlink. Enforcement hooks now work consistently on all machines without manual setup.

### v3.0.24 (2026-01-20)
**Custom Commands Auto-Sync** - Added automatic syncing of `~/.claude/commands` directory across machines via OneDrive symlink. Slash commands now work on all machines.

### v3.0.23 (2026-01-20)
**Custom Agents Auto-Sync** - Added automatic syncing of `~/.claude/agents` directory across machines via OneDrive symlink.

### v3.0.22 (2026-01-20)
**AWS SSO Clock Skew Detection** - Added three-tier verification: clock sync check, SSO token validation fallback, enhanced error messaging for "credentials expired" issues.

### v3.0.21 (2026-01-20)
**AWS SSO Stream Mixing Fix** - Fixed JSON parse error caused by mixing stderr/stdout with `2>&1`. Now uses `2>$null` pattern.

### v3.0.20 (2026-01-20)
**MCP Registration + AWS Polling** - Fixed Hindsight not appearing in `claude mcp list` (project-aware registration). Added 30-second polling for AWS SSO verification.

---

*Last Updated: 2026-01-22 (v3.0.26)*
