#!/bin/bash

# Web UI Startup Script for Manticore Search AI Testing Framework
# This script starts the web interface for search testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Configuration
WEB_DIR="web"
PORT=${PORT:-3000}
NODE_MIN_VERSION="14"

# Display banner
show_banner() {
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 Manticore Search Web UI                     ║"
    echo "║              Semantic Search Interface                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if Node.js is installed
check_nodejs() {
    log_info "Checking Node.js installation..."
    
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js is not installed"
        echo ""
        echo "Please install Node.js (version $NODE_MIN_VERSION or higher):"
        echo "• Visit: https://nodejs.org/"
        echo "• Or use package manager:"
        echo "  - Ubuntu/Debian: sudo apt install nodejs npm"
        echo "  - macOS: brew install node"
        echo "  - CentOS/RHEL: sudo yum install nodejs npm"
        return 1
    fi
    
    local node_version=$(node --version | sed 's/v//' | cut -d'.' -f1)
    if [ "$node_version" -lt "$NODE_MIN_VERSION" ]; then
        log_error "Node.js version $node_version is too old (minimum: $NODE_MIN_VERSION)"
        echo "Please update Node.js to version $NODE_MIN_VERSION or higher"
        return 1
    fi
    
    log_success "Node.js $(node --version) is installed"
    return 0
}

# Check if npm is installed
check_npm() {
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is not installed"
        echo "Please install npm (usually comes with Node.js)"
        return 1
    fi
    
    log_success "npm $(npm --version) is available"
    return 0
}

# Check if web directory exists
check_web_directory() {
    if [ ! -d "$WEB_DIR" ]; then
        log_error "Web directory not found: $WEB_DIR"
        echo "Please ensure you're running this script from the project root"
        return 1
    fi
    
    if [ ! -f "$WEB_DIR/package.json" ]; then
        log_error "package.json not found in $WEB_DIR"
        return 1
    fi
    
    if [ ! -f "$WEB_DIR/server.js" ]; then
        log_error "server.js not found in $WEB_DIR"
        return 1
    fi
    
    if [ ! -f "$WEB_DIR/index.html" ]; then
        log_error "index.html not found in $WEB_DIR"
        return 1
    fi
    
    log_success "Web directory structure is valid"
    return 0
}

# Install dependencies
install_dependencies() {
    log_info "Installing Node.js dependencies..."
    
    cd "$WEB_DIR"
    
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        log_info "Running npm install..."
        if npm install; then
            log_success "Dependencies installed successfully"
        else
            log_error "Failed to install dependencies"
            return 1
        fi
    else
        log_info "Dependencies already installed, checking for updates..."
        if npm ci --only=production; then
            log_success "Dependencies verified"
        else
            log_warn "Dependency verification failed, trying fresh install..."
            rm -rf node_modules package-lock.json
            if npm install; then
                log_success "Dependencies installed successfully"
            else
                log_error "Failed to install dependencies"
                return 1
            fi
        fi
    fi
    
    cd ..
    return 0
}

# Check if Manticore Search is running
check_manticore_status() {
    log_info "Checking Manticore Search status..."
    
    if [ -f "scripts/health_check.sh" ]; then
        if ./scripts/health_check.sh >/dev/null 2>&1; then
            log_success "Manticore Search is running and accessible"
            return 0
        else
            log_warn "Manticore Search is not running or not accessible"
            echo ""
            echo "To start Manticore Search:"
            echo "  ./scripts/setup.sh"
            echo ""
            echo "To import data:"
            echo "  ./scripts/import_data.sh"
            echo ""
            echo "The web UI will still start, but search functionality may not work."
            return 1
        fi
    else
        log_warn "Health check script not found"
        return 1
    fi
}

# Check if port is available
check_port_availability() {
    log_info "Checking if port $PORT is available..."
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i :$PORT >/dev/null 2>&1; then
            log_warn "Port $PORT is already in use"
            echo ""
            echo "To use a different port, set the PORT environment variable:"
            echo "  PORT=3001 $0"
            echo ""
            echo "Or stop the process using port $PORT:"
            echo "  lsof -ti :$PORT | xargs kill"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ln | grep ":$PORT " >/dev/null 2>&1; then
            log_warn "Port $PORT appears to be in use"
            return 1
        fi
    fi
    
    log_success "Port $PORT is available"
    return 0
}

# Start the web server
start_web_server() {
    log_info "Starting web server on port $PORT..."
    
    cd "$WEB_DIR"
    
    # Set environment variables
    export PORT="$PORT"
    export NODE_ENV="production"
    
    echo ""
    log_success "Starting Manticore Search Web UI..."
    echo -e "${BOLD}${CYAN}URL: http://localhost:$PORT${NC}"
    echo -e "${BOLD}Logs: logs/web_ui_$(date +%Y-%m-%d).log${NC}"
    echo -e "${BOLD}Press Ctrl+C to stop the server${NC}"
    echo ""
    
    # Start the server
    exec node server.js
}

# Display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port <port>    Set server port (default: 3000)"
    echo "  -h, --help          Show this help message"
    echo "  --check-only        Only check prerequisites, don't start server"
    echo "  --install-only      Only install dependencies, don't start server"
    echo ""
    echo "Environment Variables:"
    echo "  PORT                Server port (default: 3000)"
    echo ""
    echo "Examples:"
    echo "  $0                  Start server on default port 3000"
    echo "  $0 -p 8080          Start server on port 8080"
    echo "  PORT=3001 $0        Start server on port 3001"
    echo "  $0 --check-only     Check prerequisites only"
}

# Parse command line arguments
parse_arguments() {
    CHECK_ONLY=false
    INSTALL_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                PORT="$2"
                if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
                    log_error "Invalid port number: $PORT"
                    exit 1
                fi
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            --install-only)
                INSTALL_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show banner
    show_banner
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    
    if ! check_nodejs; then
        exit 1
    fi
    
    if ! check_npm; then
        exit 1
    fi
    
    if ! check_web_directory; then
        exit 1
    fi
    
    # Install dependencies
    if ! install_dependencies; then
        exit 1
    fi
    
    if [ "$INSTALL_ONLY" = true ]; then
        log_success "Dependencies installed successfully"
        echo ""
        echo "To start the web server:"
        echo "  $0"
        exit 0
    fi
    
    # Check Manticore status (non-blocking)
    check_manticore_status || true
    
    if [ "$CHECK_ONLY" = true ]; then
        log_success "All prerequisites are satisfied"
        echo ""
        echo "To start the web server:"
        echo "  $0"
        exit 0
    fi
    
    # Check port availability
    if ! check_port_availability; then
        log_error "Cannot start server - port $PORT is not available"
        exit 1
    fi
    
    # Start the web server
    start_web_server
}

# Handle script interruption
trap 'log_error "Startup interrupted"; exit 1' INT TERM

# Run main function
main "$@"