#!/bin/bash
################################################################################
# Deploy Hindsight Auto-Update Script to GCP VM
#
# This script deploys the auto-update system to the GCP VM
#
# Usage: bash deploy-to-gcp.sh
################################################################################

set -euo pipefail

# GCP Configuration
GCP_PROJECT="hindsight-prod-9802"
GCP_ZONE="us-south1-a"
VM_NAME="hindsight-vm"

echo "=========================================="
echo "Deploying Hindsight Auto-Update to GCP"
echo "=========================================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI not installed"
    echo "Install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "ERROR: Not authenticated with gcloud"
    echo "Run: gcloud auth login"
    exit 1
fi

echo "✓ gcloud authenticated"

# Step 1: Copy script to VM
echo ""
echo "Step 1: Copying auto-update script to VM..."
gcloud compute scp \
    hindsight-auto-update.sh \
    ${VM_NAME}:/tmp/ \
    --zone=${GCP_ZONE} \
    --project=${GCP_PROJECT}

echo "✓ Script copied to /tmp/"

# Step 2: Install on VM
echo ""
echo "Step 2: Installing script and dependencies..."
gcloud compute ssh ${VM_NAME} \
    --zone=${GCP_ZONE} \
    --project=${GCP_PROJECT} \
    --command='
        set -e

        # Create directories
        sudo mkdir -p /opt/hindsight/scripts
        sudo mkdir -p /var/log/hindsight
        sudo mkdir -p /var/backups/hindsight

        # Move script to proper location
        sudo mv /tmp/hindsight-auto-update.sh /opt/hindsight/scripts/
        sudo chmod +x /opt/hindsight/scripts/hindsight-auto-update.sh

        # Install dependencies
        echo "Installing dependencies..."
        sudo apt-get update -qq
        sudo apt-get install -y jq git curl docker.io

        # Ensure Docker is running
        sudo systemctl enable docker
        sudo systemctl start docker

        echo "✓ Script installed to /opt/hindsight/scripts/hindsight-auto-update.sh"
    '

# Step 3: Setup cron job
echo ""
echo "Step 3: Setting up cron job (runs daily at 4 AM)..."
gcloud compute ssh ${VM_NAME} \
    --zone=${GCP_ZONE} \
    --project=${GCP_PROJECT} \
    --command='
        set -e

        # Check if cron job already exists
        if sudo crontab -l 2>/dev/null | grep -q "hindsight-auto-update.sh"; then
            echo "⚠ Cron job already exists, skipping..."
        else
            # Add cron job
            (sudo crontab -l 2>/dev/null || true; echo "0 4 * * * /opt/hindsight/scripts/hindsight-auto-update.sh run >> /var/log/hindsight/cron.log 2>&1") | sudo crontab -
            echo "✓ Cron job added (runs daily at 4 AM)"
        fi

        # Show cron jobs
        echo ""
        echo "Current cron jobs:"
        sudo crontab -l
    '

# Step 4: Test installation
echo ""
echo "Step 4: Testing installation..."
gcloud compute ssh ${VM_NAME} \
    --zone=${GCP_ZONE} \
    --project=${GCP_PROJECT} \
    --command='
        set -e

        echo "Running health tests..."
        sudo /opt/hindsight/scripts/hindsight-auto-update.sh test
    '

echo ""
echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Check logs: gcloud compute ssh ${VM_NAME} -- tail -f /var/log/hindsight/auto-update.log"
echo "  2. Manual run: gcloud compute ssh ${VM_NAME} -- sudo /opt/hindsight/scripts/hindsight-auto-update.sh run"
echo "  3. Check status: gcloud compute ssh ${VM_NAME} -- sudo /opt/hindsight/scripts/hindsight-auto-update.sh status"
echo ""
echo "Cron schedule: Daily at 4 AM (Central Time)"
echo "Next automatic run: Tomorrow at 4:00 AM"
