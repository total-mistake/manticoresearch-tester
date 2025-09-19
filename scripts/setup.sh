#!/bin/bash

# Manticore Search 13.11.0 Docker Setup Script
# This script pulls and runs Manticore Search in Docker with health checks

set -e

# Configuration
CONTAINER_NAME="manticore-search-test"
IMAGE_NAME="manticoresearch/manticore:latest"
HTTP_PORT="9308"
MYSQL_PORT="9306"
MAX_RETRIES=30
RETRY_INTERVAL=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed and running
check_docker() {
    log_info "Checking Docker availability..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    log_info "Docker is available and running"
}

# Check if ports are available
check_ports() {
    log_info "Checking port availability..."
    
    if lsof -Pi :$HTTP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Port $HTTP_PORT is already in use. Please free the port or change HTTP_PORT in the script."
        exit 1
    fi
    
    if lsof -Pi :$MYSQL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Port $MYSQL_PORT is already in use. Please free the port or change MYSQL_PORT in the script."
        exit 1
    fi
    
    log_info "Ports $HTTP_PORT and $MYSQL_PORT are available"
}

# Stop and remove existing container if it exists
cleanup_existing_container() {
    if docker ps -a --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warn "Existing container '$CONTAINER_NAME' found. Stopping and removing..."
        docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
        docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
        log_info "Existing container removed"
    fi
}

# Pull Docker image
pull_image() {
    log_info "Pulling Manticore Search Docker image..."
    
    if ! docker pull $IMAGE_NAME; then
        log_error "Failed to pull Docker image $IMAGE_NAME"
        log_error "Please check your internet connection and Docker Hub access"
        exit 1
    fi
    
    log_info "Docker image pulled successfully"
}

# Start Manticore Search container
start_container() {
    log_info "Starting Manticore Search container..."
    
    # Start container with default configuration first
    if ! docker run -d \
        --name $CONTAINER_NAME \
        -p $HTTP_PORT:9308 \
        -p $MYSQL_PORT:9306 \
        -v "$(pwd)/output:/var/lib/manticore" \
        $IMAGE_NAME; then
        log_error "Failed to start Manticore Search container"
        exit 1
    fi
    
    log_info "Container started successfully"
}

# Health check function
health_check() {
    log_info "Performing health check..."
    
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s -f "http://localhost:$HTTP_PORT/" >/dev/null 2>&1; then
            log_info "Health check passed - Manticore Search is responding"
            return 0
        fi
        
        retries=$((retries + 1))
        log_warn "Health check attempt $retries/$MAX_RETRIES failed, retrying in ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
    done
    
    log_error "Health check failed after $MAX_RETRIES attempts"
    log_error "Container logs:"
    docker logs $CONTAINER_NAME
    return 1
}

# Verify API endpoints
verify_api() {
    log_info "Verifying API endpoints..."
    
    # Test HTTP API root endpoint
    if ! curl -s -f "http://localhost:$HTTP_PORT/" >/dev/null 2>&1; then
        log_error "HTTP API endpoint is not accessible"
        return 1
    fi
    
    # Test CLI endpoint with a simple query
    local response=$(curl -s -X POST "http://localhost:$HTTP_PORT/cli" \
        -H "Content-Type: application/json" \
        -d '{"query": "SHOW STATUS"}' 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$response" | grep -q "Query OK"; then
        log_info "API endpoints verified successfully"
        return 0
    else
        log_error "API verification failed"
        log_error "Response: $response"
        return 1
    fi
}

# Main setup function
main() {
    log_info "Starting Manticore Search 13.11.0 setup..."
    
    # Create directory structure if it doesn't exist
    mkdir -p configs output logs
    
    # Perform setup steps
    check_docker
    check_ports
    cleanup_existing_container
    pull_image
    start_container
    
    # Wait a moment for container to initialize
    sleep 3
    
    # Perform health checks
    if health_check && verify_api; then
        log_info "Setup completed successfully!"
        log_info "Manticore Search is running on:"
        log_info "  HTTP API: http://localhost:$HTTP_PORT"
        log_info "  MySQL API: localhost:$MYSQL_PORT"
        log_info "Container name: $CONTAINER_NAME"
        
        # Save connection info for other scripts
        cat > configs/connection.conf << EOF
HTTP_PORT=$HTTP_PORT
MYSQL_PORT=$MYSQL_PORT
CONTAINER_NAME=$CONTAINER_NAME
BASE_URL=http://localhost:$HTTP_PORT
EOF
        
        exit 0
    else
        log_error "Setup failed during health checks"
        log_error "Cleaning up failed container..."
        docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
        docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"