# Auto-Push AWS Credentials to GCP Hindsight
# Runs silently on Windows login via Scheduled Task
# If SSO session is active, pushes credentials automatically
# If SSO session expired, logs warning (user will see on next manual login)

$LogFile = "$env:USERPROFILE\hindsight-auto-push.log"

function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -Append $LogFile
}

Log "=== Auto-Push AWS Credentials Started ==="

# Try to get credentials without prompting
try {
    $credJson = aws configure export-credentials 2>$null
    if (-not $credJson) {
        Log "No valid AWS credentials available (SSO session may be expired)"
        Log "Run 'Update-AWS-Credentials.bat' manually to refresh"
        exit 0
    }

    $creds = $credJson | ConvertFrom-Json
    $accessKey = $creds.AccessKeyId
    $secretKey = $creds.SecretAccessKey
    $sessionToken = $creds.SessionToken

    if (-not $accessKey) {
        Log "Failed to parse credentials"
        exit 1
    }

    Log "Got valid AWS credentials (AccessKeyId: $($accessKey.Substring(0,10))...)"

} catch {
    Log "Error getting credentials: $_"
    exit 1
}

# Push to GCP VM and restart containers directly
Log "Pushing credentials to GCP Hindsight..."

try {
    # Write credentials to the shared volume AND .env file for docker-compose
    $writeCredsCmd = "docker run --rm -v aws-creds:/shared -v /home/achau:/app alpine sh -c 'echo AWS_ACCESS_KEY_ID=$accessKey > /shared/credentials.env && echo AWS_SECRET_ACCESS_KEY=$secretKey >> /shared/credentials.env && echo AWS_SESSION_TOKEN=$sessionToken >> /shared/credentials.env && echo AWS_REGION=us-east-1 >> /shared/credentials.env && cp /shared/credentials.env /app/.env'"

    $result = gcloud compute ssh hindsight-vm --project=hindsight-prod-9802 --zone=us-south1-a --command=$writeCredsCmd 2>&1

    if ($LASTEXITCODE -eq 0) {
        Log "Credentials written to volume and .env file"

        # Recreate litellm-proxy to re-read env_file (restart doesn't re-read env_file)
        Log "Recreating litellm-proxy with new credentials..."
        $restartCmd = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /home/achau:/app -w /app docker:cli docker compose --env-file .env up -d --force-recreate litellm-proxy"
        $restartResult = gcloud compute ssh hindsight-vm --project=hindsight-prod-9802 --zone=us-south1-a --command=$restartCmd 2>&1

        if ($LASTEXITCODE -eq 0) {
            Log "litellm-proxy recreated successfully"
        } else {
            Log "Recreate command output: $restartResult"
        }

        # Wait and verify
        Start-Sleep -Seconds 45
        $health = Invoke-RestMethod -Uri "http://34.174.13.163:8888/health" -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($health.status -eq "healthy") {
            Log "Health check PASSED: Hindsight is healthy"
        } else {
            Log "Health check: Waiting for containers to fully start..."
        }
    } else {
        Log "SSH command failed: $result"
    }

} catch {
    Log "Error pushing to GCP: $_"
}

Log "=== Auto-Push Complete ==="
