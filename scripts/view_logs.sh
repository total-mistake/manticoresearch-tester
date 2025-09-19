#!/bin/bash

# Log Viewer Script for Manticore Search Web UI
# This script helps view and analyze web UI logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
LOGS_DIR="logs"
DEFAULT_LINES=50

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

# Display usage information
show_usage() {
    echo -e "${BOLD}Web UI Log Viewer${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --follow         Follow log output (like tail -f)"
    echo "  -n, --lines <num>    Number of lines to show (default: $DEFAULT_LINES)"
    echo "  -d, --date <date>    Show logs for specific date (YYYY-MM-DD)"
    echo "  -s, --search <term>  Search for specific term in logs"
    echo "  -e, --errors         Show only error messages"
    echo "  -l, --list           List available log files"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Show last $DEFAULT_LINES lines of today's log"
    echo "  $0 -f                Follow current log output"
    echo "  $0 -d 2025-01-19     Show logs for specific date"
    echo "  $0 -s \"search\"       Search for 'search' in logs"
    echo "  $0 -e                Show only errors"
    echo "  $0 -l                List all log files"
}

# List available log files
list_log_files() {
    log_info "Available log files in $LOGS_DIR:"
    echo ""
    
    if [ ! -d "$LOGS_DIR" ]; then
        log_warn "Logs directory not found: $LOGS_DIR"
        return 1
    fi
    
    local log_files=($(find "$LOGS_DIR" -name "web_ui_*.log" -type f | sort -r))
    
    if [ ${#log_files[@]} -eq 0 ]; then
        log_warn "No web UI log files found"
        echo "Start the web UI to generate logs: ./scripts/start_web_ui.sh"
        return 1
    fi
    
    for log_file in "${log_files[@]}"; do
        local filename=$(basename "$log_file")
        local size=$(du -h "$log_file" | cut -f1)
        local lines=$(wc -l < "$log_file")
        local date=$(echo "$filename" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}')
        
        echo -e "${CYAN}$filename${NC} (${size}, ${lines} lines) - $date"
    done
    
    return 0
}

# Get log file path for specific date
get_log_file() {
    local date="$1"
    echo "$LOGS_DIR/web_ui_${date}.log"
}

# Get today's log file
get_today_log_file() {
    local today=$(date +%Y-%m-%d)
    get_log_file "$today"
}

# View logs with options
view_logs() {
    local log_file="$1"
    local lines="$2"
    local follow="$3"
    local search_term="$4"
    local errors_only="$5"
    
    if [ ! -f "$log_file" ]; then
        log_error "Log file not found: $log_file"
        echo ""
        echo "Available options:"
        echo "• Check if the date is correct"
        echo "• Run: $0 -l to list available log files"
        echo "• Start web UI to generate logs: ./scripts/start_web_ui.sh"
        return 1
    fi
    
    log_info "Viewing log file: $log_file"
    echo ""
    
    # Build command
    local cmd="cat"
    
    # Apply filters
    if [ "$errors_only" = true ]; then
        cmd="$cmd \"$log_file\" | grep -E '\\[ERROR\\]|\\[WARN\\]'"
    elif [ -n "$search_term" ]; then
        cmd="$cmd \"$log_file\" | grep -i \"$search_term\""
    else
        cmd="$cmd \"$log_file\""
    fi
    
    # Apply line limit or follow
    if [ "$follow" = true ]; then
        if [ "$errors_only" = true ] || [ -n "$search_term" ]; then
            log_warn "Follow mode not compatible with filtering. Showing recent filtered results instead."
            eval "$cmd | tail -n $lines"
        else
            log_info "Following log output (Press Ctrl+C to stop)..."
            tail -f "$log_file"
        fi
    else
        eval "$cmd | tail -n $lines"
    fi
}

# Colorize log output
colorize_logs() {
    sed -E "
        s/\[ERROR\]/$(echo -e "${RED}[ERROR]${NC}")/g;
        s/\[WARN\]/$(echo -e "${YELLOW}[WARN]${NC}")/g;
        s/\[INFO\]/$(echo -e "${GREEN}[INFO]${NC}")/g;
        s/\[DEBUG\]/$(echo -e "${BLUE}[DEBUG]${NC}")/g;
        s/Search request/$(echo -e "${CYAN}Search request${NC}")/g;
        s/Search completed/$(echo -e "${GREEN}Search completed${NC}")/g;
    "
}

# Parse command line arguments
parse_arguments() {
    FOLLOW=false
    LINES=$DEFAULT_LINES
    DATE=""
    SEARCH_TERM=""
    ERRORS_ONLY=false
    LIST_FILES=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                FOLLOW=true
                shift
                ;;
            -n|--lines)
                LINES="$2"
                if ! [[ "$LINES" =~ ^[0-9]+$ ]] || [ "$LINES" -lt 1 ]; then
                    log_error "Invalid lines number: $LINES"
                    exit 1
                fi
                shift 2
                ;;
            -d|--date)
                DATE="$2"
                if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    log_error "Invalid date format: $DATE (use YYYY-MM-DD)"
                    exit 1
                fi
                shift 2
                ;;
            -s|--search)
                SEARCH_TERM="$2"
                if [ -z "$SEARCH_TERM" ]; then
                    log_error "Search term cannot be empty"
                    exit 1
                fi
                shift 2
                ;;
            -e|--errors)
                ERRORS_ONLY=true
                shift
                ;;
            -l|--list)
                LIST_FILES=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
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
    
    # Handle list files option
    if [ "$LIST_FILES" = true ]; then
        list_log_files
        exit $?
    fi
    
    # Determine log file
    local log_file
    if [ -n "$DATE" ]; then
        log_file=$(get_log_file "$DATE")
    else
        log_file=$(get_today_log_file)
    fi
    
    # View logs
    view_logs "$log_file" "$LINES" "$FOLLOW" "$SEARCH_TERM" "$ERRORS_ONLY" | colorize_logs
}

# Handle script interruption
trap 'log_info "Log viewer stopped"; exit 0' INT TERM

# Run main function
main "$@"