#!/bin/bash

# Health Check Script for Manticore Search
# This script provides detailed health check functionality

set -e

# Load connection configuration
if [ -f "configs/connection.conf" ]; then
    source configs/connection.conf
else
    echo "Error: Connection configuration not found. Run setup.sh first."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check container status
check_container() {
    log_info "Checking container status..."
    
    if ! docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -q "^${CONTAINER_NAME}"; then
        log_error "Container '$CONTAINER_NAME' is not running"
        return 1
    fi
    
    local status=$(docker ps --format '{{.Status}}' --filter "name=${CONTAINER_NAME}")
    log_info "Container status: $status"
    return 0
}

# Check HTTP API
check_http_api() {
    log_info "Checking HTTP API..."
    
    local response=$(curl -s -w "%{http_code}" "http://localhost:$HTTP_PORT/" -o /dev/null)
    
    if [ "$response" = "200" ]; then
        log_info "HTTP API is responding (HTTP $response)"
        return 0
    else
        log_error "HTTP API check failed (HTTP $response)"
        return 1
    fi
}

# Check CLI endpoint
check_cli_endpoint() {
    log_info "Checking CLI endpoint..."
    
    local response=$(curl -s -X POST "http://localhost:$HTTP_PORT/cli" \
        -H "Content-Type: application/json" \
        -d '{"query": "SHOW STATUS"}')
    
    if echo "$response" | grep -q "Query OK"; then
        log_info "CLI endpoint is working"
        return 0
    else
        log_error "CLI endpoint check failed"
        log_error "Response: $response"
        return 1
    fi
}

# Check if Auto Embeddings are available
check_auto_embeddings() {
    log_info "Checking Auto Embeddings availability..."
    
    local response=$(curl -s -X POST "http://localhost:$HTTP_PORT/cli" \
        -H "Content-Type: application/json" \
        -d '{"query": "SHOW VARIABLES"}')
    
    if echo "$response" | grep -q "Query OK"; then
        log_info "Variables query successful - Manticore is responding to commands"
        return 0
    else
        log_warn "Could not verify Auto Embeddings configuration"
        log_warn "Response: $response"
        return 1
    fi
}

# Main health check
main() {
    log_info "Starting comprehensive health check..."
    
    local checks_passed=0
    local total_checks=4
    
    if check_container; then
        checks_passed=$((checks_passed + 1))
    fi
    
    if check_http_api; then
        checks_passed=$((checks_passed + 1))
    fi
    
    if check_cli_endpoint; then
        checks_passed=$((checks_passed + 1))
    fi
    
    if check_auto_embeddings; then
        checks_passed=$((checks_passed + 1))
    fi
    
    log_info "Health check completed: $checks_passed/$total_checks checks passed"
    
    if [ $checks_passed -eq $total_checks ]; then
        log_info "All health checks passed - Manticore Search is ready for testing"
        exit 0
    else
        log_error "Some health checks failed - please review the setup"
        exit 1
    fi
}

main "$@"