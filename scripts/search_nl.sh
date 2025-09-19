#!/bin/bash

# Natural Language Search Script for Manticore Search
# This script executes natural language queries using AI search capabilities with vector similarity

set -e

# Load connection configuration
if [ -f "configs/connection.conf" ]; then
    source configs/connection.conf
else
    echo "Error: Connection configuration not found. Run setup.sh first."
    exit 1
fi

# Configuration
INDEX_NAME="documents"
DEFAULT_LIMIT=10
TIMEOUT_SECONDS=30
MAX_RETRIES=3
RETRY_DELAY=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Display usage information
show_usage() {
    echo -e "${BOLD}Natural Language Search for Manticore Search${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] \"<natural language query>\""
    echo ""
    echo "Options:"
    echo "  -l, --limit <number>     Maximum number of results to return (default: $DEFAULT_LIMIT)"
    echo "  -t, --timeout <seconds>  Query timeout in seconds (default: $TIMEOUT_SECONDS)"
    echo "  -v, --verbose           Enable verbose output with debug information"
    echo "  -j, --json              Output results in JSON format"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 \"How does automation work in online casinos?\""
    echo "  $0 --limit 5 \"What are points and how to use them?\""
    echo "  $0 --json --verbose \"Project goals and objectives\""
    echo ""
    echo "Note: Query must be provided in quotes to handle spaces and special characters."
}

# Parse command line arguments
parse_arguments() {
    QUERY=""
    LIMIT=$DEFAULT_LIMIT
    TIMEOUT=$TIMEOUT_SECONDS
    VERBOSE=false
    JSON_OUTPUT=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--limit)
                LIMIT="$2"
                if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 1000 ]; then
                    log_error "Invalid limit value. Must be a number between 1 and 1000."
                    exit 1
                fi
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -lt 1 ] || [ "$TIMEOUT" -gt 300 ]; then
                    log_error "Invalid timeout value. Must be a number between 1 and 300 seconds."
                    exit 1
                fi
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$QUERY" ]; then
                    QUERY="$1"
                else
                    log_error "Multiple queries provided. Please provide only one query in quotes."
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate that query was provided
    if [ -z "$QUERY" ]; then
        log_error "No query provided."
        show_usage
        exit 1
    fi
    
    # Validate query length
    if [ ${#QUERY} -lt 3 ]; then
        log_error "Query too short. Please provide at least 3 characters."
        exit 1
    fi
    
    if [ ${#QUERY} -gt 1000 ]; then
        log_error "Query too long. Maximum 1000 characters allowed."
        exit 1
    fi
}

# Check if Manticore Search is accessible
check_manticore_connection() {
    if [ "$VERBOSE" = true ]; then
        log_info "Checking Manticore Search connection at $BASE_URL..."
    fi
    
    if ! curl -s -f --max-time 5 "$BASE_URL/" >/dev/null 2>&1; then
        log_error "Manticore Search is not accessible at $BASE_URL"
        log_error "Please ensure the service is running (run setup.sh if needed)"
        return 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_success "Manticore Search connection verified"
    fi
    return 0
}

# Check if index exists and has data
check_index_status() {
    if [ "$VERBOSE" = true ]; then
        log_info "Checking index '$INDEX_NAME' status..."
    fi
    
    # Check if index exists by trying to search it
    local test_search_response=$(curl -s --max-time 10 -X POST "$BASE_URL/search" \
        -H "Content-Type: application/json" \
        -d "{\"index\": \"$INDEX_NAME\", \"query\": {\"match_all\": {}}, \"limit\": 1}" 2>/dev/null)
    
    if echo "$test_search_response" | grep -q "index_not_found\|no such index\|unknown index"; then
        log_error "Index '$INDEX_NAME' does not exist"
        log_error "Please run configure_embeddings.sh and import_data.sh first"
        return 1
    fi
    
    # Check if index has data (reuse the same response)
    if echo "$test_search_response" | grep -q "\"total\":0"; then
        log_warn "Index '$INDEX_NAME' exists but appears to be empty"
        log_warn "Please run import_data.sh to populate the index with documents"
        return 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        local total_docs=$(echo "$test_search_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
        log_success "Index '$INDEX_NAME' is ready with $total_docs documents"
    fi
    
    return 0
}

# Execute search query with retry logic
execute_search_query() {
    local query="$1"
    local limit="$2"
    local timeout="$3"
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        if [ "$VERBOSE" = true ] && [ $attempt -gt 1 ]; then
            log_info "Search attempt $attempt/$MAX_RETRIES..."
        fi
        
        # Try different search approaches for better AI search results
        local search_queries=(
            # Approach 1: KNN search with match query for semantic similarity
            "{\"index\": \"$INDEX_NAME\", \"query\": {\"bool\": {\"should\": [{\"match\": {\"content\": \"$query\"}}, {\"match\": {\"title\": \"$query\"}}]}}, \"limit\": $limit, \"_source\": [\"title\", \"url\", \"content\"]}"
            
            # Approach 2: Full-text search with content and title
            "{\"index\": \"$INDEX_NAME\", \"query\": {\"multi_match\": {\"query\": \"$query\", \"fields\": [\"title^2\", \"content\"]}}, \"limit\": $limit, \"_source\": [\"title\", \"url\", \"content\"]}"
            
            # Approach 3: Simple match_all with text search
            "{\"index\": \"$INDEX_NAME\", \"query\": {\"match\": {\"_all\": \"$query\"}}, \"limit\": $limit}"
        )
        
        for search_json in "${search_queries[@]}"; do
            if [ "$VERBOSE" = true ]; then
                log_debug "Trying search approach with query: ${search_json:0:100}..."
            fi
            
            local response=$(curl -s --max-time "$timeout" -X POST "$BASE_URL/search" \
                -H "Content-Type: application/json" \
                -d "$search_json" 2>/dev/null)
            
            # Check if we got a valid response
            if echo "$response" | grep -q "\"hits\""; then
                echo "$response"
                return 0
            elif echo "$response" | grep -q "\"total\""; then
                echo "$response"
                return 0
            fi
            
            if [ "$VERBOSE" = true ]; then
                log_debug "Search approach failed, trying next..."
            fi
        done
        
        # If all approaches failed, wait and retry
        if [ $attempt -lt $MAX_RETRIES ]; then
            log_warn "Search attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "All search attempts failed after $MAX_RETRIES retries"
    return 1
}

# Format and display search results
format_search_results() {
    local response="$1"
    local query="$2"
    local start_time="$3"
    local end_time="$4"
    
    # Calculate execution time
    local execution_time=$((end_time - start_time))
    
    # Parse response
    local total_hits=$(echo "$response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    local took_time=$(echo "$response" | grep -o '"took":[0-9]*' | cut -d':' -f2)
    
    if [ -z "$total_hits" ]; then
        total_hits=0
    fi
    
    if [ "$JSON_OUTPUT" = true ]; then
        # Output in JSON format
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        return 0
    fi
    
    # Human-readable format
    echo ""
    echo -e "${BOLD}=== Natural Language Search Results ===${NC}"
    echo -e "${CYAN}Query:${NC} \"$query\""
    echo -e "${CYAN}Total Results:${NC} $total_hits"
    echo -e "${CYAN}Execution Time:${NC} ${execution_time}s"
    if [ -n "$took_time" ]; then
        echo -e "${CYAN}Search Time:${NC} ${took_time}ms"
    fi
    echo ""
    
    if [ "$total_hits" -eq 0 ]; then
        echo -e "${YELLOW}No results found.${NC}"
        echo ""
        echo "Suggestions:"
        echo "• Try different keywords or phrases"
        echo "• Use more general terms"
        echo "• Check spelling and try synonyms"
        echo "• Ensure the index contains relevant documents"
        return 0
    fi
    
    # Extract and display individual results
    local result_count=0
    
    # Try to parse hits array
    if echo "$response" | grep -q "\"hits\""; then
        # Check if jq is available for proper JSON parsing
        if command -v jq >/dev/null 2>&1; then
            # Use jq for proper JSON parsing
            echo "$response" | jq -r '.hits.hits[]? // .hits[]? // empty | 
                "RESULT_START\n" +
                "ID: " + (._id // .id // "N/A" | tostring) + "\n" +
                "SCORE: " + (._score // .score // "N/A" | tostring) + "\n" +
                "TITLE: " + (._source.title // .title // "N/A") + "\n" +
                "URL: " + (._source.url // .url // "N/A") + "\n" +
                "CONTENT: " + (._source.content // .content // "N/A") + "\n" +
                "RESULT_END"' 2>/dev/null | while IFS= read -r line; do
                
                if [ "$line" = "RESULT_START" ]; then
                    result_count=$((result_count + 1))
                    echo -e "${MAGENTA}--- Result $result_count ---${NC}"
                elif [ "$line" = "RESULT_END" ]; then
                    echo ""
                elif [[ "$line" =~ ^ID: ]]; then
                    echo -e "${BLUE}ID:${NC} ${line#ID: }"
                elif [[ "$line" =~ ^SCORE: ]]; then
                    local score="${line#SCORE: }"
                    if [ "$score" != "N/A" ]; then
                        echo -e "${BLUE}Relevance Score:${NC} $score"
                    fi
                elif [[ "$line" =~ ^TITLE: ]]; then
                    local title="${line#TITLE: }"
                    if [ "$title" != "N/A" ]; then
                        echo -e "${BOLD}Title:${NC} $title"
                    fi
                elif [[ "$line" =~ ^URL: ]]; then
                    local url="${line#URL: }"
                    if [ "$url" != "N/A" ]; then
                        echo -e "${BLUE}URL:${NC} $url"
                    fi
                elif [[ "$line" =~ ^CONTENT: ]]; then
                    local content="${line#CONTENT: }"
                    if [ "$content" != "N/A" ]; then
                        # Truncate content if too long
                        if [ ${#content} -gt 200 ]; then
                            content="${content:0:200}..."
                        fi
                        echo -e "${NC}Content:${NC} $content"
                    fi
                fi
            done
        else
            # Fallback parsing without jq
            echo -e "${YELLOW}jq not available - using basic parsing${NC}"
            
            # Extract basic information using grep and sed
            local hits_section=$(echo "$response" | grep -o '"hits":\[.*\]' | head -1)
            
            if [ -n "$hits_section" ]; then
                # Simple extraction of first few results
                local count=1
                echo "$response" | grep -o '"_id":[^,]*' | head -5 | while read -r id_line; do
                    echo -e "${MAGENTA}--- Result $count ---${NC}"
                    echo -e "${BLUE}ID:${NC} ${id_line#\"_id\":}"
                    count=$((count + 1))
                done
            fi
        fi
    else
        # Fallback: try to extract basic information
        echo -e "${YELLOW}Results found but format parsing failed.${NC}"
        if [ "$VERBOSE" = true ]; then
            echo -e "${BLUE}Raw response:${NC}"
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
        fi
    fi
    
    echo -e "${BOLD}=== End of Results ===${NC}"
    echo ""
}

# Handle search errors and provide suggestions
handle_search_error() {
    local response="$1"
    local query="$2"
    
    log_error "Search query failed"
    
    if [ "$VERBOSE" = true ]; then
        log_debug "Error response: $response"
    fi
    
    # Analyze error and provide suggestions
    if echo "$response" | grep -qi "timeout"; then
        log_error "Query timed out. Try:"
        echo "• Using a shorter, more specific query"
        echo "• Increasing timeout with --timeout option"
        echo "• Checking system performance"
    elif echo "$response" | grep -qi "index.*not.*found\|table.*not.*found"; then
        log_error "Index not found. Please:"
        echo "• Run configure_embeddings.sh to create the index"
        echo "• Run import_data.sh to populate with data"
    elif echo "$response" | grep -qi "connection.*refused\|connection.*failed"; then
        log_error "Connection failed. Please:"
        echo "• Ensure Manticore Search is running (run setup.sh)"
        echo "• Check if the service is accessible at $BASE_URL"
    elif echo "$response" | grep -qi "syntax.*error\|parse.*error"; then
        log_error "Query syntax error. Try:"
        echo "• Using simpler, more natural language"
        echo "• Avoiding special characters"
        echo "• Using quotes around phrases"
    else
        log_error "Unknown error occurred. Try:"
        echo "• Checking service status"
        echo "• Using --verbose flag for more details"
        echo "• Verifying index configuration"
    fi
    
    return 1
}

# Main search function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    if [ "$VERBOSE" = true ]; then
        log_info "Starting natural language search..."
        log_info "Query: \"$QUERY\""
        log_info "Limit: $LIMIT results"
        log_info "Timeout: $TIMEOUT seconds"
    fi
    
    # Check prerequisites
    if ! check_manticore_connection; then
        exit 1
    fi
    
    if ! check_index_status; then
        exit 1
    fi
    
    # Record start time
    local start_time=$(date +%s)
    
    # Execute search query
    if [ "$VERBOSE" = true ]; then
        log_info "Executing search query..."
    fi
    
    local search_response
    if search_response=$(execute_search_query "$QUERY" "$LIMIT" "$TIMEOUT"); then
        local end_time=$(date +%s)
        
        if [ "$VERBOSE" = true ]; then
            log_success "Search completed successfully"
        fi
        
        # Format and display results
        format_search_results "$search_response" "$QUERY" "$start_time" "$end_time"
        exit 0
    else
        local end_time=$(date +%s)
        handle_search_error "$search_response" "$QUERY"
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Search interrupted by user"; exit 1' INT TERM

# Ensure jq is available for JSON parsing (with fallback)
if ! command -v jq >/dev/null 2>&1; then
    if [ "$JSON_OUTPUT" = true ]; then
        log_warn "jq not found - JSON output may not be formatted"
    fi
    if [ "$VERBOSE" = true ]; then
        log_warn "jq not found - result parsing may be limited"
    fi
fi

# Run main function
main "$@"