#!/bin/bash
################################################################################
# Hindsight Automatic Update Script
#
# Purpose: Check for Hindsight updates from GitHub, test, and manage lifecycle
# Schedule: Runs daily at 4 AM via cron
# Repository: https://github.com/vectorize-io/hindsight
#
# Workflow:
#   1. Check GitHub for new commits
#   2. Start Hindsight container if stopped
#   3. Pull and apply updates if available
#   4. Run comprehensive health tests
#   5. Rollback if tests fail
#   6. Shutdown container to save costs
#
# Author: Abhishek Chauhan (achau)
# Organization: PakEnergy
# Version: 1.0.0
# Last Updated: 2026-01-25
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_NAME="hindsight-auto-update"
LOG_DIR="/var/log/hindsight"
LOG_FILE="${LOG_DIR}/auto-update.log"
STATE_FILE="${LOG_DIR}/last-update-commit.txt"
BACKUP_DIR="/var/backups/hindsight"

# GitHub Configuration
GITHUB_REPO="https://github.com/vectorize-io/hindsight"
GITHUB_API="https://api.github.com/repos/vectorize-io/hindsight/commits/main"
LOCAL_REPO_DIR="/opt/hindsight"

# Docker Configuration
CONTAINER_NAME="hindsight-server"
DOCKER_IMAGE="vectorize/hindsight:latest"
COMPOSE_FILE="${LOCAL_REPO_DIR}/docker-compose.yml"

# Hindsight API Configuration
CONTROL_PLANE_URL="http://localhost:9999"
MCP_API_URL="http://localhost:8888"
HEALTH_ENDPOINT="${CONTROL_PLANE_URL}/health"
BANK_NAME="claude-code"

# Test Configuration
MAX_STARTUP_WAIT=120  # seconds
MAX_TEST_RETRIES=3
TEST_TIMEOUT=30  # seconds

# Cost Saving Configuration
SHUTDOWN_AFTER_UPDATE=true  # Set to false to keep running after update

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

setup_logging() {
    mkdir -p "${LOG_DIR}"
    mkdir -p "${BACKUP_DIR}"

    # Rotate log if > 10MB
    if [[ -f "${LOG_FILE}" ]] && [[ $(stat -f%z "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}") -gt 10485760 ]]; then
        mv "${LOG_FILE}" "${LOG_FILE}.$(date +%Y%m%d-%H%M%S)"
        gzip "${LOG_FILE}.$(date +%Y%m%d-%H%M%S)" &
    fi
}

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

send_notification() {
    local subject="$1"
    local message="$2"

    # Log notification (extend this to send emails/Slack if needed)
    log_info "NOTIFICATION: ${subject} - ${message}"

    # Example: Send to Cloud Logging
    if command -v gcloud &> /dev/null; then
        echo "${message}" | gcloud logging write hindsight-updates "${message}" \
            --severity=INFO \
            --labels=component=auto-update 2>/dev/null || true
    fi
}

check_dependencies() {
    local missing_deps=()

    for cmd in docker curl jq git; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Install with: apt-get install -y ${missing_deps[*]}"
        return 1
    fi

    log_info "All dependencies satisfied"
    return 0
}

# ============================================================================
# GITHUB VERSION CHECK
# ============================================================================

get_github_latest_commit() {
    log_info "Checking GitHub for latest commit..."

    local latest_commit
    latest_commit=$(curl -s -H "Accept: application/vnd.github.v3+json" "${GITHUB_API}" | jq -r '.sha // empty')

    if [[ -z "${latest_commit}" ]]; then
        log_error "Failed to fetch latest commit from GitHub"
        return 1
    fi

    log_info "GitHub latest commit: ${latest_commit:0:8}"
    echo "${latest_commit}"
}

get_local_commit() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo "none"
        return
    fi

    local local_commit
    local_commit=$(cat "${STATE_FILE}" 2>/dev/null || echo "none")
    log_info "Local tracked commit: ${local_commit:0:8}"
    echo "${local_commit}"
}

save_commit() {
    local commit="$1"
    echo "${commit}" > "${STATE_FILE}"
    log_info "Saved commit to state file: ${commit:0:8}"
}

check_for_updates() {
    local github_commit
    local local_commit

    github_commit=$(get_github_latest_commit) || return 1
    local_commit=$(get_local_commit)

    if [[ "${github_commit}" == "${local_commit}" ]]; then
        log_info "No updates available (already at ${github_commit:0:8})"
        return 1
    fi

    log_success "Update available: ${local_commit:0:8} → ${github_commit:0:8}"
    return 0
}

# ============================================================================
# DOCKER CONTAINER MANAGEMENT
# ============================================================================

is_container_running() {
    docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

start_container() {
    log_info "Starting Hindsight container..."

    if is_container_running; then
        log_info "Container already running"
        return 0
    fi

    # Try docker-compose first, fallback to docker run
    if [[ -f "${COMPOSE_FILE}" ]]; then
        cd "$(dirname "${COMPOSE_FILE}")"
        docker-compose up -d
    else
        docker start "${CONTAINER_NAME}" 2>/dev/null || {
            log_warn "Container doesn't exist, pulling and starting fresh..."
            docker run -d \
                --name "${CONTAINER_NAME}" \
                -p 8888:8888 \
                -p 9999:9999 \
                -v /var/lib/hindsight:/app/data \
                -v /root/.aws:/root/.aws:ro \
                --restart unless-stopped \
                "${DOCKER_IMAGE}"
        }
    fi

    # Wait for container to be healthy
    log_info "Waiting for container to start (max ${MAX_STARTUP_WAIT}s)..."
    local elapsed=0
    while ! is_container_running && [[ $elapsed -lt $MAX_STARTUP_WAIT ]]; do
        sleep 2
        elapsed=$((elapsed + 2))
    done

    if ! is_container_running; then
        log_error "Container failed to start within ${MAX_STARTUP_WAIT}s"
        return 1
    fi

    log_success "Container started successfully"
    return 0
}

stop_container() {
    log_info "Stopping Hindsight container..."

    if ! is_container_running; then
        log_info "Container already stopped"
        return 0
    fi

    if [[ -f "${COMPOSE_FILE}" ]]; then
        cd "$(dirname "${COMPOSE_FILE}")"
        docker-compose down
    else
        docker stop "${CONTAINER_NAME}"
    fi

    log_success "Container stopped"
    return 0
}

backup_container() {
    local backup_name="hindsight-backup-$(date +%Y%m%d-%H%M%S)"
    log_info "Creating container backup: ${backup_name}"

    # Backup container volumes
    docker run --rm \
        -v hindsight_data:/source \
        -v "${BACKUP_DIR}:/backup" \
        alpine tar czf "/backup/${backup_name}.tar.gz" -C /source .

    # Keep only last 7 backups
    cd "${BACKUP_DIR}"
    ls -t hindsight-backup-*.tar.gz | tail -n +8 | xargs -r rm

    log_success "Backup created: ${BACKUP_DIR}/${backup_name}.tar.gz"
}

restore_container() {
    local backup_file="$1"
    log_warn "Restoring from backup: ${backup_file}"

    docker run --rm \
        -v hindsight_data:/target \
        -v "${BACKUP_DIR}:/backup" \
        alpine tar xzf "/backup/${backup_file}" -C /target

    log_success "Restore completed"
}

# ============================================================================
# UPDATE PROCESS
# ============================================================================

clone_or_update_repo() {
    if [[ ! -d "${LOCAL_REPO_DIR}/.git" ]]; then
        log_info "Cloning Hindsight repository..."
        git clone "${GITHUB_REPO}" "${LOCAL_REPO_DIR}"
    else
        log_info "Updating local repository..."
        cd "${LOCAL_REPO_DIR}"
        git fetch origin
        git reset --hard origin/main
    fi

    log_success "Repository updated"
}

pull_docker_image() {
    log_info "Pulling latest Docker image: ${DOCKER_IMAGE}"
    docker pull "${DOCKER_IMAGE}"
    log_success "Docker image updated"
}

apply_update() {
    log_info "Applying Hindsight update..."

    # Backup before update
    backup_container

    # Clone/update repository
    clone_or_update_repo

    # Pull latest Docker image
    pull_docker_image

    # Restart container with new image
    stop_container
    sleep 5
    start_container

    # Wait for services to be ready
    wait_for_health_check

    log_success "Update applied successfully"
}

# ============================================================================
# HEALTH TESTS
# ============================================================================

wait_for_health_check() {
    log_info "Waiting for Hindsight to become healthy..."

    local elapsed=0
    while [[ $elapsed -lt $MAX_STARTUP_WAIT ]]; do
        if curl -sf "${HEALTH_ENDPOINT}" > /dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    log_error "Health check failed after ${MAX_STARTUP_WAIT}s"
    return 1
}

test_control_plane() {
    log_info "Testing Control Plane API..."

    local response
    response=$(curl -sf "${HEALTH_ENDPOINT}" 2>/dev/null || echo "")

    if [[ -z "${response}" ]]; then
        log_error "Control Plane not responding"
        return 1
    fi

    if echo "${response}" | jq -e '.status == "healthy"' > /dev/null 2>&1; then
        log_success "Control Plane: healthy"
        return 0
    else
        log_error "Control Plane: unhealthy response: ${response}"
        return 1
    fi
}

test_mcp_server() {
    log_info "Testing MCP Server API..."

    local response
    response=$(curl -sf "${MCP_API_URL}/" 2>/dev/null || echo "")

    if [[ -z "${response}" ]]; then
        log_error "MCP Server not responding"
        return 1
    fi

    log_success "MCP Server: responding"
    return 0
}

test_memory_bank() {
    log_info "Testing memory bank access..."

    local bank_url="${CONTROL_PLANE_URL}/api/banks/${BANK_NAME}"
    local response
    response=$(curl -sf "${bank_url}" 2>/dev/null || echo "")

    if [[ -z "${response}" ]]; then
        log_error "Memory bank not accessible"
        return 1
    fi

    # Extract memory count
    local memory_count
    memory_count=$(echo "${response}" | jq -r '.total_nodes // 0' 2>/dev/null || echo "0")

    if [[ "${memory_count}" -gt 0 ]]; then
        log_success "Memory bank: ${memory_count} memories accessible"
        return 0
    else
        log_error "Memory bank: no memories found (possible data loss)"
        return 1
    fi
}

test_recall_operation() {
    log_info "Testing recall operation..."

    local recall_url="${MCP_API_URL}/recall"
    local test_query="test connection"

    local response
    response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"${test_query}\", \"bank\": \"${BANK_NAME}\"}" \
        "${recall_url}" 2>/dev/null || echo "")

    if [[ -z "${response}" ]]; then
        log_error "Recall operation failed"
        return 1
    fi

    log_success "Recall operation: working"
    return 0
}

test_docker_logs() {
    log_info "Checking Docker logs for errors..."

    local error_count
    error_count=$(docker logs "${CONTAINER_NAME}" --since 5m 2>&1 | grep -ic "error\|exception\|fatal" || echo "0")

    if [[ "${error_count}" -gt 5 ]]; then
        log_error "Found ${error_count} errors in recent logs"
        docker logs "${CONTAINER_NAME}" --tail 20 >> "${LOG_FILE}"
        return 1
    fi

    log_success "Docker logs: no critical errors (${error_count} minor warnings)"
    return 0
}

run_comprehensive_tests() {
    log_info "Running comprehensive health tests..."

    local tests=(
        "test_control_plane"
        "test_mcp_server"
        "test_memory_bank"
        "test_recall_operation"
        "test_docker_logs"
    )

    local failed_tests=()

    for test in "${tests[@]}"; do
        if ! $test; then
            failed_tests+=("$test")
        fi
    done

    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_error "TESTS FAILED: ${failed_tests[*]}"
        return 1
    fi

    log_success "All tests passed ✓"
    return 0
}

# ============================================================================
# ROLLBACK PROCESS
# ============================================================================

rollback_update() {
    log_error "Rolling back update due to test failures..."

    # Find most recent backup
    local latest_backup
    latest_backup=$(ls -t "${BACKUP_DIR}"/hindsight-backup-*.tar.gz 2>/dev/null | head -1)

    if [[ -z "${latest_backup}" ]]; then
        log_error "No backup found for rollback"
        send_notification "Hindsight Update Failed" "Cannot rollback - no backup available"
        return 1
    fi

    # Stop current container
    stop_container

    # Restore from backup
    restore_container "$(basename "${latest_backup}")"

    # Start with old version
    start_container

    # Verify rollback worked
    if run_comprehensive_tests; then
        log_success "Rollback successful - system restored"
        send_notification "Hindsight Update Rolled Back" "Update failed tests, rolled back to previous version"
        return 0
    else
        log_error "Rollback failed - manual intervention required"
        send_notification "Hindsight CRITICAL" "Update and rollback both failed - manual intervention needed"
        return 1
    fi
}

# ============================================================================
# MAIN UPDATE WORKFLOW
# ============================================================================

main() {
    log_info "=========================================="
    log_info "Hindsight Auto-Update Started"
    log_info "=========================================="

    # Setup
    setup_logging

    # Check dependencies
    if ! check_dependencies; then
        log_error "Missing dependencies - aborting"
        exit 1
    fi

    # Check for updates
    if ! check_for_updates; then
        log_info "No updates needed"

        # Still ensure container is in desired state
        if [[ "${SHUTDOWN_AFTER_UPDATE}" == "true" ]] && is_container_running; then
            log_info "Shutting down container to save costs (no update needed)"
            stop_container
        elif [[ "${SHUTDOWN_AFTER_UPDATE}" == "false" ]] && ! is_container_running; then
            log_info "Starting container (configured to stay running)"
            start_container
        fi

        exit 0
    fi

    # Start container if needed
    if ! is_container_running; then
        start_container || {
            log_error "Failed to start container"
            exit 1
        }
    fi

    # Record current state for rollback
    local github_commit
    github_commit=$(get_github_latest_commit)

    # Apply update
    if ! apply_update; then
        log_error "Update application failed"
        rollback_update
        exit 1
    fi

    # Run comprehensive tests
    log_info "Running post-update tests..."
    if ! run_comprehensive_tests; then
        log_error "Post-update tests failed"
        rollback_update
        exit 1
    fi

    # Update successful
    save_commit "${github_commit}"
    log_success "Update completed successfully: ${github_commit:0:8}"
    send_notification "Hindsight Updated" "Successfully updated to ${github_commit:0:8}"

    # Shutdown to save costs if configured
    if [[ "${SHUTDOWN_AFTER_UPDATE}" == "true" ]]; then
        log_info "Shutting down container to save costs"
        stop_container
        log_info "Container stopped - will restart at next scheduled update or manual start"
    else
        log_info "Container left running (SHUTDOWN_AFTER_UPDATE=false)"
    fi

    log_info "=========================================="
    log_info "Hindsight Auto-Update Completed"
    log_info "=========================================="
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Handle script arguments
case "${1:-run}" in
    run)
        main
        ;;
    test)
        setup_logging
        check_dependencies
        start_container
        run_comprehensive_tests
        ;;
    start)
        setup_logging
        start_container
        ;;
    stop)
        setup_logging
        stop_container
        ;;
    status)
        if is_container_running; then
            echo "Hindsight container is running"
            run_comprehensive_tests
        else
            echo "Hindsight container is stopped"
        fi
        ;;
    *)
        echo "Usage: $0 {run|test|start|stop|status}"
        exit 1
        ;;
esac
