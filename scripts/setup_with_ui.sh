#!/bin/bash

# Complete Setup Script with Web UI for Manticore Search AI Testing Framework
# This script performs full setup including web interface

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

log_step() {
    echo -e "${BOLD}${BLUE}=== $1 ===${NC}"
}

# Display banner
show_banner() {
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           Manticore Search AI Complete Setup                ║"
    echo "║         with Web Interface & Search Testing                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Execute step with error handling
execute_step() {
    local step_name="$1"
    local script_path="$2"
    local required="${3:-true}"
    
    log_step "$step_name"
    
    if [ ! -f "$script_path" ]; then
        if [ "$required" = "true" ]; then
            log_error "Required script not found: $script_path"
            exit 1
        else
            log_warn "Optional script not found: $script_path"
            return 1
        fi
    fi
    
    if bash "$script_path"; then
        log_success "$step_name completed successfully"
        return 0
    else
        if [ "$required" = "true" ]; then
            log_error "$step_name failed"
            exit 1
        else
            log_warn "$step_name failed (non-critical)"
            return 1
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        echo "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running"
        echo "Please start Docker service"
        exit 1
    fi
    
    log_success "Docker is available and running"
    
    # Check Node.js (for web UI)
    if ! command -v node >/dev/null 2>&1; then
        log_warn "Node.js is not installed - web UI will not be available"
        echo "To use web UI, install Node.js: https://nodejs.org/"
        return 1
    fi
    
    local node_version=$(node --version | sed 's/v//' | cut -d'.' -f1)
    if [ "$node_version" -lt "14" ]; then
        log_warn "Node.js version is too old for web UI (minimum: 14)"
        return 1
    fi
    
    log_success "Node.js $(node --version) is available"
    return 0
}

# Check data directory
check_data() {
    log_step "Checking Data Directory"
    
    if [ ! -d "data" ]; then
        log_error "Data directory not found"
        exit 1
    fi
    
    local md_count=$(find data -name "*.md" -type f | wc -l)
    if [ "$md_count" -eq 0 ]; then
        log_error "No markdown files found in data directory"
        echo "Please add .md files to the data/ directory"
        exit 1
    fi
    
    log_success "Found $md_count markdown files in data directory"
}

# Main setup function
main() {
    local start_time=$(date +%s)
    
    show_banner
    
    log_info "Starting complete setup with web interface..."
    echo ""
    
    # Check prerequisites
    local nodejs_available=true
    if ! check_prerequisites; then
        nodejs_available=false
    fi
    
    # Check data
    check_data
    
    echo ""
    log_info "Setup will proceed with the following steps:"
    echo "  1. Setup Manticore Search (Docker)"
    echo "  2. Import markdown data"
    echo "  3. Run search tests"
    if [ "$nodejs_available" = "true" ]; then
        echo "  4. Setup web interface"
        echo "  5. Start web server"
    else
        echo "  4. Web interface setup skipped (Node.js not available)"
    fi
    echo ""
    
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user"
        exit 0
    fi
    
    echo ""
    
    # Step 1: Setup Manticore Search
    execute_step "Setting up Manticore Search" "scripts/setup.sh"
    echo ""
    
    # Step 2: Import data
    execute_step "Importing markdown data" "scripts/import_data.sh"
    echo ""
    
    # Step 3: Run tests
    execute_step "Running search tests" "scripts/run_tests.sh" "false"
    echo ""
    
    # Step 4 & 5: Web interface (if Node.js is available)
    if [ "$nodejs_available" = "true" ]; then
        log_step "Setting up Web Interface"
        
        if [ -f "scripts/start_web_ui.sh" ]; then
            # Install dependencies only
            if bash scripts/start_web_ui.sh --install-only; then
                log_success "Web interface dependencies installed"
                
                echo ""
                log_step "Setup Complete!"
                
                local end_time=$(date +%s)
                local total_time=$((end_time - start_time))
                
                echo -e "${BOLD}${GREEN}✅ Manticore Search AI Testing Framework is ready!${NC}"
                echo ""
                echo -e "${BOLD}Setup Summary:${NC}"
                echo "  • Manticore Search: Running on ports 9306 (MySQL) and 9308 (HTTP)"
                echo "  • Data imported: $(find data -name "*.md" -type f | wc -l) markdown files"
                echo "  • Web interface: Ready to start"
                echo "  • Total setup time: ${total_time}s"
                echo ""
                echo -e "${BOLD}Next Steps:${NC}"
                echo ""
                echo -e "${CYAN}1. Start Web Interface:${NC}"
                echo "   ./scripts/start_web_ui.sh"
                echo "   Then open: http://localhost:3000"
                echo ""
                echo -e "${CYAN}2. Or use Command Line:${NC}"
                echo "   ./scripts/search_nl.sh \"Your natural language query\""
                echo ""
                echo -e "${CYAN}3. Run Full Tests:${NC}"
                echo "   ./scripts/run_tests.sh"
                echo ""
                echo -e "${CYAN}4. Check System Health:${NC}"
                echo "   ./scripts/health_check.sh"
                echo ""
                
                # Ask if user wants to start web interface immediately
                read -p "Start web interface now? (Y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    echo ""
                    log_info "Starting web interface..."
                    exec bash scripts/start_web_ui.sh
                fi
                
            else
                log_error "Failed to install web interface dependencies"
                exit 1
            fi
        else
            log_error "Web interface startup script not found"
            exit 1
        fi
    else
        log_step "Setup Complete!"
        
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        
        echo -e "${BOLD}${GREEN}✅ Manticore Search AI Testing Framework is ready!${NC}"
        echo ""
        echo -e "${BOLD}Setup Summary:${NC}"
        echo "  • Manticore Search: Running on ports 9306 (MySQL) and 9308 (HTTP)"
        echo "  • Data imported: $(find data -name "*.md" -type f | wc -l) markdown files"
        echo "  • Web interface: Not available (Node.js required)"
        echo "  • Total setup time: ${total_time}s"
        echo ""
        echo -e "${BOLD}Next Steps:${NC}"
        echo ""
        echo -e "${CYAN}1. Use Command Line Search:${NC}"
        echo "   ./scripts/search_nl.sh \"Your natural language query\""
        echo ""
        echo -e "${CYAN}2. Run Full Tests:${NC}"
        echo "   ./scripts/run_tests.sh"
        echo ""
        echo -e "${CYAN}3. Check System Health:${NC}"
        echo "   ./scripts/health_check.sh"
        echo ""
        echo -e "${YELLOW}To enable web interface, install Node.js 14+ and run:${NC}"
        echo "   ./scripts/start_web_ui.sh"
    fi
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"