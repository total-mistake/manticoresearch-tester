#!/bin/bash

# Automated Test Scenarios and Reporting Script for Manticore Search AI Testing
# This script runs predefined natural language test queries and generates performance reports

set -e

# Load connection configuration
if [ -f "configs/connection.conf" ]; then
    source configs/connection.conf
else
    echo "Error: Connection configuration not found. Run setup.sh first."
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCH_SCRIPT="$SCRIPT_DIR/search_nl.sh"
OUTPUT_DIR="output"
REPORT_FILE="$OUTPUT_DIR/test_report_$(date +%Y%m%d_%H%M%S).json"
SUMMARY_FILE="$OUTPUT_DIR/test_summary_$(date +%Y%m%d_%H%M%S).txt"
TIMEOUT_SECONDS=30
MAX_RESULTS=10

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

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Predefined test queries in Russian based on the available documentation
declare -a TEST_QUERIES=(
    "Как работает автоматизация в онлайн казино?"
    "Что такое баллы и как их использовать?"
    "Цели и задачи проекта"
    "Настройка домена и FTP доступ"
    "Адаптивные шаблоны и мобильная версия"
    "Будет ли реклама на моем сайте?"
    "Что происходит с сайтом после истечения тарифа?"
    "Как добавить отзывы на главную страницу?"
    "Что такое robots.txt файл?"
    "Эффективные методы контент маркетинга"
    "Есть ли у вас тестовый период?"
    "Подробные видеоинструкции по использованию"
    "Центр конфиденциальности и защита данных"
    "Дополнительные преимущества собственного домена"
    "Потеря данных при смене шаблона"
)



# Function to get expected result count
get_expected_results() {
    local query="$1"
    case "$query" in
        "Как работает автоматизация в онлайн казино?") echo "1" ;;
        "Что такое баллы и как их использовать?") echo "2" ;;
        "Цели и задачи проекта") echo "1" ;;
        "Настройка домена и FTP доступ") echo "2" ;;
        "Адаптивные шаблоны и мобильная версия") echo "1" ;;
        "Будет ли реклама на моем сайте?") echo "1" ;;
        "Что происходит с сайтом после истечения тарифа?") echo "1" ;;
        "Как добавить отзывы на главную страницу?") echo "1" ;;
        "Что такое robots.txt файл?") echo "1" ;;
        "Эффективные методы контент маркетинга") echo "1" ;;
        "Есть ли у вас тестовый период?") echo "1" ;;
        "Подробные видеоинструкции по использованию") echo "1" ;;
        "Центр конфиденциальности и защита данных") echo "1" ;;
        "Дополнительные преимущества собственного домена") echo "1" ;;
        "Потеря данных при смене шаблона") echo "1" ;;
        *) echo "1" ;;
    esac
}

# Display usage information
show_usage() {
    echo -e "${BOLD}Automated Test Scenarios for Manticore Search AI Testing${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -q, --query <query>      Run a single specific query instead of all tests"
    echo ""
    echo "  -l, --limit <number>     Maximum number of results per query (default: $MAX_RESULTS)"
    echo "  -t, --timeout <seconds>  Query timeout in seconds (default: $TIMEOUT_SECONDS)"
    echo "  -v, --verbose           Enable verbose output with detailed information"
    echo "  -j, --json-only         Output only JSON results without summary report"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run all test scenarios"

    echo "  $0 --query \"Что такое баллы?\"        # Run single query"
    echo "  $0 --verbose --limit 5                # Verbose mode with 5 results per query"
    echo ""

}

# Parse command line arguments
parse_arguments() {
    SINGLE_QUERY=""

    LIMIT=$MAX_RESULTS
    TIMEOUT=$TIMEOUT_SECONDS
    VERBOSE=false
    JSON_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--query)
                SINGLE_QUERY="$2"
                shift 2
                ;;

            -l|--limit)
                LIMIT="$2"
                if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
                    log_error "Invalid limit value. Must be a number between 1 and 100."
                    exit 1
                fi
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -lt 5 ] || [ "$TIMEOUT" -gt 300 ]; then
                    log_error "Invalid timeout value. Must be a number between 5 and 300 seconds."
                    exit 1
                fi
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=true
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
                log_error "Unexpected argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    # Check if search script exists
    if [ ! -f "$SEARCH_SCRIPT" ]; then
        log_error "Search script not found at $SEARCH_SCRIPT"
        log_error "Please ensure search_nl.sh exists in the scripts directory"
        return 1
    fi
    
    # Make search script executable
    chmod +x "$SEARCH_SCRIPT"
    
    # Check if output directory exists
    if [ ! -d "$OUTPUT_DIR" ]; then
        log_info "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq not found - JSON processing may be limited"
        if [ "$JSON_ONLY" = true ]; then
            log_error "jq is required for JSON-only mode"
            return 1
        fi
    fi
    
    return 0
}

# Execute a single search query and collect metrics
execute_test_query() {
    local query="$1"
    local query_index="$2"
    local total_queries="$3"
    
    if [ "$VERBOSE" = true ]; then
        log_info "[$query_index/$total_queries] Testing query: \"$query\""
    fi
    
    # Record start time
    local start_time=$(date +%s.%N)
    
    # Execute search query
    local search_output=""
    local search_exit_code=0
    
    if [ -f "$SEARCH_SCRIPT" ] && [ -x "$SEARCH_SCRIPT" ]; then
        search_output=$("$SEARCH_SCRIPT" --json --limit "$LIMIT" --timeout "$TIMEOUT" "$query" 2>&1) || search_exit_code=$?
    else
        search_exit_code=127
        search_output="Search script not found or not executable"
    fi
    
    # Record end time
    local end_time=$(date +%s.%N)
    
    # Calculate response time in milliseconds
    local response_time=$(echo "($end_time - $start_time) * 1000" | bc -l 2>/dev/null || echo "0")
    response_time=$(printf "%.0f" "$response_time" 2>/dev/null || echo "0")
    
    # Parse search results
    local total_results=0
    local search_time=0
    local top_score=0
    local has_results=false
    local error_message=""
    
    if [ $search_exit_code -eq 0 ] && echo "$search_output" | grep -q "\"total\""; then
        has_results=true
        
        if command -v jq >/dev/null 2>&1; then
            total_results=$(echo "$search_output" | jq -r '.total // 0' 2>/dev/null || echo "0")
            search_time=$(echo "$search_output" | jq -r '.took // 0' 2>/dev/null || echo "0")
            top_score=$(echo "$search_output" | jq -r '.hits.hits[0]._score // .hits[0]._score // 0' 2>/dev/null || echo "0")
        else
            # Fallback parsing without jq
            total_results=$(echo "$search_output" | grep -o '"total":[0-9]*' | cut -d':' -f2 | head -1)
            search_time=$(echo "$search_output" | grep -o '"took":[0-9]*' | cut -d':' -f2 | head -1)
            top_score=$(echo "$search_output" | grep -o '"_score":[0-9.]*' | cut -d':' -f2 | head -1)
        fi
        
        # Set defaults if parsing failed
        total_results=${total_results:-0}
        search_time=${search_time:-0}
        top_score=${top_score:-0}
    else
        error_message="Search failed or returned no results"
        if [ $search_exit_code -ne 0 ]; then
            error_message="Search script exited with code $search_exit_code"
        fi
    fi
    
    # Create result object
    local expected_count=$(get_expected_results "$query")
    
    # Calculate quality metrics
    local relevance_score=0
    local result_quality="poor"
    
    if [ "$has_results" = true ] && [ "$total_results" -gt 0 ]; then
        # Simple quality assessment based on result count and top score
        if [ "$total_results" -ge "$expected_count" ] && [ "$(echo "$top_score > 0.5" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
            result_quality="excellent"
            relevance_score=90
        elif [ "$total_results" -ge "$expected_count" ] || [ "$(echo "$top_score > 0.3" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
            result_quality="good"
            relevance_score=70
        elif [ "$total_results" -gt 0 ]; then
            result_quality="fair"
            relevance_score=50
        fi
    fi
    
    # Ensure numeric values are valid
    response_time=${response_time:-0}
    search_time=${search_time:-0}
    total_results=${total_results:-0}
    expected_count=${expected_count:-1}
    top_score=${top_score:-0}
    relevance_score=${relevance_score:-0}
    
    # Validate numeric values
    if ! [[ "$response_time" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then response_time=0; fi
    if ! [[ "$search_time" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then search_time=0; fi
    if ! [[ "$total_results" =~ ^[0-9]+$ ]]; then total_results=0; fi
    if ! [[ "$expected_count" =~ ^[0-9]+$ ]]; then expected_count=1; fi
    if ! [[ "$top_score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then top_score=0; fi
    if ! [[ "$relevance_score" =~ ^[0-9]+$ ]]; then relevance_score=0; fi
    
    # Create JSON result
    local json_result
    if command -v jq >/dev/null 2>&1; then
        json_result=$(jq -n \
            --arg query "$query" \
            --arg response_time "$response_time" \
            --arg search_time "$search_time" \
            --arg total_results "$total_results" \
            --arg expected_results "$expected_count" \
            --arg top_score "$top_score" \
            --arg relevance_score "$relevance_score" \
            --arg result_quality "$result_quality" \
            --arg has_results "$has_results" \
            --arg error_message "$error_message" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                query: $query,
                metrics: {
                    response_time_ms: ($response_time | tonumber),
                    search_time_ms: ($search_time | tonumber),
                    total_results: ($total_results | tonumber),
                    expected_results: ($expected_results | tonumber),
                    top_score: ($top_score | tonumber),
                    relevance_score: ($relevance_score | tonumber),
                    result_quality: $result_quality
                },
                success: ($has_results == "true"),
                error: $error_message,
                timestamp: $timestamp
            }')
    else
        # Fallback JSON creation without jq
        json_result="{\"query\":\"$query\",\"metrics\":{\"response_time_ms\":$response_time,\"search_time_ms\":$search_time,\"total_results\":$total_results,\"expected_results\":$expected_count,\"top_score\":$top_score,\"relevance_score\":$relevance_score,\"result_quality\":\"$result_quality\"},\"success\":$has_results,\"error\":\"$error_message\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    fi
    
    echo "$json_result"
    
    if [ "$VERBOSE" = true ]; then
        if [ "$has_results" = true ]; then
            log_success "Query completed: $total_results results, ${response_time}ms response time, quality: $result_quality"
        else
            log_error "Query failed: $error_message"
        fi
    fi
}

# Generate summary report
generate_summary_report() {
    local results_json="$1"
    
    if [ "$JSON_ONLY" = true ]; then
        return 0
    fi
    
    log_info "Generating summary report..."
    
    # Create summary report
    {
        echo "=========================================="
        echo "MANTICORE SEARCH AI TESTING SUMMARY REPORT"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Test Configuration:"
        echo "  - Max Results per Query: $LIMIT"
        echo "  - Query Timeout: $TIMEOUT seconds"
        echo "  - Total Test Queries: $(echo "$results_json" | jq '. | length' 2>/dev/null || echo "N/A")"
        echo ""
        
        # Overall statistics
        if command -v jq >/dev/null 2>&1; then
            local total_queries=$(echo "$results_json" | jq '. | length' 2>/dev/null || echo "0")
            local successful_queries=$(echo "$results_json" | jq '[.[] | select(.success == true)] | length' 2>/dev/null || echo "0")
            local failed_queries=$(echo "$results_json" | jq '[.[] | select(.success == false)] | length' 2>/dev/null || echo "0")
            local avg_response_time=$(echo "$results_json" | jq '[.[] | select(.success == true) | .metrics.response_time_ms] | if length > 0 then add / length else 0 end' 2>/dev/null | cut -d'.' -f1 || echo "0")
            local avg_results=$(echo "$results_json" | jq '[.[] | select(.success == true) | .metrics.total_results] | if length > 0 then add / length else 0 end' 2>/dev/null | cut -d'.' -f1 || echo "0")
            local avg_relevance=$(echo "$results_json" | jq '[.[] | select(.success == true) | .metrics.relevance_score] | if length > 0 then add / length else 0 end' 2>/dev/null | cut -d'.' -f1 || echo "0")
            
            echo "OVERALL PERFORMANCE:"
            local success_rate="N/A"
            if [ "$total_queries" -gt 0 ]; then
                success_rate=$(echo "scale=1; $successful_queries * 100 / $total_queries" | bc -l 2>/dev/null || echo "N/A")
            fi
            echo "  - Successful Queries: $successful_queries/$total_queries ($success_rate%)"
            echo "  - Failed Queries: $failed_queries"
            echo "  - Average Response Time: ${avg_response_time:-N/A} ms"
            echo "  - Average Results per Query: ${avg_results:-N/A}"
            echo "  - Average Relevance Score: ${avg_relevance:-N/A}/100"
            echo ""
            

            
            # Quality analysis
            echo "SEARCH QUALITY ANALYSIS:"
            local excellent_count=$(echo "$results_json" | jq '[.[] | select(.metrics.result_quality == "excellent")] | length' 2>/dev/null || echo "0")
            local good_count=$(echo "$results_json" | jq '[.[] | select(.metrics.result_quality == "good")] | length' 2>/dev/null || echo "0")
            local fair_count=$(echo "$results_json" | jq '[.[] | select(.metrics.result_quality == "fair")] | length' 2>/dev/null || echo "0")
            local poor_count=$(echo "$results_json" | jq '[.[] | select(.metrics.result_quality == "poor")] | length' 2>/dev/null || echo "0")
            
            echo "  - Excellent Results: $excellent_count"
            echo "  - Good Results: $good_count"
            echo "  - Fair Results: $fair_count"
            echo "  - Poor Results: $poor_count"
            echo ""
            
            # Top performing queries
            echo "TOP 5 PERFORMING QUERIES:"
            echo "$results_json" | jq -r '[.[] | select(.success == true)] | sort_by(-.metrics.relevance_score) | .[0:5] | .[] | "  - \(.query) (Score: \(.metrics.relevance_score), Time: \(.metrics.response_time_ms)ms)"' 2>/dev/null || echo "  Unable to generate top queries list"
            echo ""
            
            # Failed queries
            if [ "$failed_queries" -gt 0 ]; then
                echo "FAILED QUERIES:"
                echo "$results_json" | jq -r '.[] | select(.success == false) | "  - \(.query): \(.error)"' 2>/dev/null || echo "  Unable to list failed queries"
                echo ""
            fi
        else
            echo "OVERALL PERFORMANCE:"
            echo "  - jq not available for detailed statistics"
            echo "  - Check JSON report for detailed results"
            echo ""
        fi
        
        echo "RECOMMENDATIONS:"
        echo "  - Review queries with poor quality scores"
        echo "  - Consider optimizing index configuration for slow queries"
        echo "  - Analyze failed queries for common patterns"
        echo "  - Monitor response times for performance regression"
        echo ""
        echo "Files Generated:"
        echo "  - JSON Report: $REPORT_FILE"
        echo "  - Summary Report: $SUMMARY_FILE"
        echo "=========================================="
        
    } > "$SUMMARY_FILE"
    
    log_success "Summary report saved to: $SUMMARY_FILE"
}

# Main test execution function
run_tests() {
    local queries_to_run=()
    
    # Determine which queries to run
    if [ -n "$SINGLE_QUERY" ]; then
        queries_to_run=("$SINGLE_QUERY")

    else
        queries_to_run=("${TEST_QUERIES[@]}")
    fi
    
    local total_queries=${#queries_to_run[@]}
    log_info "Starting test execution with $total_queries queries..."
    
    # Initialize results array
    local all_results="[]"
    
    # Execute each query
    local query_index=1
    for query in "${queries_to_run[@]}"; do
        local result_json
        result_json=$(execute_test_query "$query" "$query_index" "$total_queries")
        
        # Add result to array
        if command -v jq >/dev/null 2>&1 && [ -n "$result_json" ]; then
            all_results=$(echo "$all_results" | jq ". + [$result_json]" --argjson result_json "$result_json" 2>/dev/null || echo "$all_results")
        elif [ -n "$result_json" ]; then
            # Fallback: simple JSON array construction
            if [ "$all_results" = "[]" ]; then
                all_results="[$result_json]"
            else
                all_results="${all_results%]}, $result_json]"
            fi
        fi
        
        query_index=$((query_index + 1))
        
        # Small delay between queries to avoid overwhelming the server
        sleep 0.5
    done
    
    # Save JSON report
    echo "$all_results" > "$REPORT_FILE"
    log_success "JSON report saved to: $REPORT_FILE"
    
    # Generate summary report
    generate_summary_report "$all_results"
    
    # Display summary if not JSON-only mode
    if [ "$JSON_ONLY" = false ]; then
        echo ""
        log_info "Test execution completed!"
        echo ""
        cat "$SUMMARY_FILE"
    else
        # Output JSON results
        echo "$all_results"
    fi
}

# Main function
main() {
    parse_arguments "$@"
    
    if [ "$VERBOSE" = true ]; then
        log_info "Starting Manticore Search AI testing..."
        if [ -n "$SINGLE_QUERY" ]; then
            log_info "Running single query: \"$SINGLE_QUERY\""

        else
            log_info "Running all ${#TEST_QUERIES[@]} predefined test queries"
        fi
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Run tests
    if ! run_tests; then
        log_error "Test execution failed"
        exit 1
    fi
    
    log_success "All tests completed successfully!"
}

# Handle script interruption
trap 'log_error "Test execution interrupted by user"; exit 1' INT TERM

# Ensure bc is available for calculations
if ! command -v bc >/dev/null 2>&1; then
    log_warn "bc not found - some calculations may be limited"
fi

# Run main function
main "$@"