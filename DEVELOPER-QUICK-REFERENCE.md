# SOC2_OVERRIDE: Educational example
# This developer guide contains example security violations for training purposes

# SOC 2 Hook - Developer Quick Reference

**1-Page Cheat Sheet** | Keep this handy while coding with Claude Code

---

## What It Does

🛡️ **Blocks hardcoded secrets** before files are saved
✅ **Suggests secure alternatives** using environment variables
🔍 **Scans automatically** - no action needed from you

---

## What Gets Blocked

```python
❌ BAD (blocked):
password = "secret123"
API_KEY = "sk-1234567890"
DB_HOST = "10.0.1.50"
url = "https://api.internal.company.com"
conn = "postgres://user:pass@host/db"

✅ GOOD (allowed):
password = os.environ["PASSWORD"]
API_KEY = os.getenv("API_KEY")
DB_HOST = os.environ["DB_HOST"]
url = os.environ["API_URL"]
conn = os.environ["DATABASE_URL"]
```

---

## Common Scenarios

### Scenario 1: "My file won't save!"

**Problem:** Claude says "SOC 2 VIOLATION DETECTED"

**Solution:**
1. Look for hardcoded passwords, API keys, IPs, or URLs
2. Replace with `os.environ["VARIABLE_NAME"]`
3. Add values to `.env` file (not committed to git)

**Example:**
```python
# Before (blocked)
API_KEY = "sk-1234567890"

# After (works)
API_KEY = os.environ["API_KEY"]

# In .env file (gitignored)
API_KEY=sk-1234567890
```

---

### Scenario 2: "I need test credentials"

**Problem:** Need hardcoded values for unit tests

**Solution:** Use override comment in first 10 lines:

```python
# SOC2_OVERRIDE: Security testing

# Now you can use test credentials
TEST_API_KEY = "sk-test-1234567890"
TEST_PASSWORD = "mock123"
```

**Valid override reasons:**
- `Security testing`
- `Educational example`
- `Penetration testing`
- `Testing hook itself`

---

### Scenario 3: "I'm working with config files"

**Problem:** JSON/YAML files also get scanned

**Solution:** Same rules apply - use placeholders or env vars

```yaml
# ❌ BAD (blocked)
database:
  host: 10.0.1.50
  password: secret123

# ✅ GOOD (allowed)
database:
  host: ${DB_HOST}
  password: ${DB_PASSWORD}
```

---

## Environment Variables Best Practices

### 1. Create `.env` file (local development)

```bash
# .env (add to .gitignore!)
DATABASE_URL=postgres://localhost:5432/mydb
API_KEY=sk-your-key-here
AWS_ACCESS_KEY=AKIA...
```

### 2. Load in your code

**Python:**
```python
from dotenv import load_dotenv
import os

load_dotenv()
API_KEY = os.environ["API_KEY"]
```

**JavaScript:**
```javascript
require('dotenv').config();
const API_KEY = process.env.API_KEY;
```

**TypeScript:**
```typescript
import * as dotenv from 'dotenv';
dotenv.config();
const API_KEY = process.env.API_KEY!;
```

### 3. Never commit `.env` to git

```bash
# Add to .gitignore
.env
.env.local
.env.*.local
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **"False positive - this isn't sensitive"** | Contact #claude-code-support if pattern needs adjustment |
| **"I need to commit a config template"** | Use placeholders like `YOUR_API_KEY_HERE` or `<INSERT_TOKEN>` |
| **"Override not working"** | Check comment is in **first 10 lines** and matches exact format |
| **"Need urgent production fix"** | Use override, but document why in commit message |

---

## Quick Commands

```bash
# Check if hook is installed
python ~/.claude/hooks/soc2-validator.py --version

# Find all overrides in codebase (for audit)
grep -r "SOC2_OVERRIDE" .

# Test if .env is loaded
python -c "import os; print(os.getenv('API_KEY'))"
```

---

## Why We Do This

- ✅ **SOC 2 compliance** - Required for security audits
- ✅ **Prevents incidents** - Leaked credentials cost $15K-$50K to rotate
- ✅ **Best practice** - Industry standard (12-factor app methodology)
- ✅ **Protects production** - Credentials never in git history

---

## Support

- **Questions:** #claude-code-support on Slack
- **Security team:** security@pakenergy.com
- **Documentation:** [Internal Wiki - SOC 2 Hook Guide]

---

**Remember:** The hook is your friend! It prevents expensive mistakes before they happen.

*Last Updated: 2026-01-17 | Version: 1.0*
