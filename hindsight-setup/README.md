# Hindsight GCP Setup (AWS Bedrock)

Hindsight memory server running on GCP with **AWS Bedrock Claude Opus** for LLM.

## Architecture

```
┌──────────────────────────────────────────────────┐
│            GCP Compute Engine VM                 │
│                                                  │
│  ┌─────────────┐    ┌───────────────────────┐   │
│  │  Auth Mgr   │───▶│  AWS SSO (PakEnergy)  │   │
│  │  :8080      │    │  Auto-refresh 6hrs    │   │
│  └──────┬──────┘    └───────────────────────┘   │
│         │ credentials                            │
│         ▼                                        │
│  ┌─────────────┐    ┌───────────────────────┐   │
│  │  LiteLLM    │───▶│  AWS Bedrock          │   │
│  │  Proxy      │    │  Claude Opus 4.5      │   │
│  └──────▲──────┘    └───────────────────────┘   │
│         │                                        │
│  ┌──────┴──────┐    ┌───────────────────────┐   │
│  │  Hindsight  │◀───│  Cloud SQL            │   │
│  │  :8888/9999 │    │  PostgreSQL 18        │   │
│  └─────────────┘    └───────────────────────┘   │
└──────────────────────────────────────────────────┘
```

## Quick Start

```batch
Check-Hindsight.bat        :: Check status
Start-Hindsight.bat        :: Start VM
Stop-Hindsight.bat         :: Stop VM (save costs)
Update-AWS-Credentials.bat :: Manual refresh (backup)
```

## Endpoints

| Service | URL |
|---------|-----|
| MCP API | http://34.174.13.163:8888/mcp/claude-code/ |
| Web UI | http://34.174.13.163:9999/banks/claude-code?view=data |
| Health | http://34.174.13.163:8888/health |
| Auth UI | http://34.174.13.163:8080 |

## AWS Credential Management

**Auto-refresh is enabled!** Credentials refresh automatically every 6 hours.

### Initial Setup (one-time)
1. Go to http://34.174.13.163:8080
2. Click "Login with AWS SSO"
3. Approve in browser (PakEnergy SSO)

### If Auto-refresh Fails
1. Go to http://34.174.13.163:8080
2. Click "Login with AWS SSO" to re-authenticate
3. Or use `Update-AWS-Credentials.bat` as backup

## Data Security

- **LLM calls** → AWS Bedrock (your corporate AWS account)
- **No data** leaves to external LLM providers (Groq, OpenAI, etc.)
- **Database** → GCP Cloud SQL (your project)

## GCP Resources

- **Project:** hindsight-prod-9802
- **VM:** hindsight-vm (e2-medium, us-south1-a)
- **Database:** Cloud SQL PostgreSQL 18

## Cost

- VM + DB running: ~$300/month
- VM stopped: ~$100/month (only Cloud SQL)
