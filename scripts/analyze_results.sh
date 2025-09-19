#!/bin/bash

# Performance Analysis Script for Manticore Search Test Results
# This script analyzes test results and provides detailed performance insights

set -e

# Configuration
OUTPUT_DIR="output"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Display usage information
show_usage() {
    echo -e "${BOLD}Performance Analysis for Manticore Search Test Results${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] [REPORT_FILE]"
    echo ""
    echo "Options:"
    echo "  -l, --latest             Analyze the most recent test report"
    echo "  -c, --compare <file>     Compare with another test report"
    echo "  -f, --format <format>    Output format: text, json, csv (default: text)"
    echo "  -o, --output <file>      Save analysis to file"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --latest                                    # Analyze latest report"
    echo "  $0 output/test_report_20231201_120000.json    # Analyze specific report"
    echo "  $0 --compare old_report.json new_report.json  # Compare two reports"
    echo "  $0 --latest --format csv --output analysis.csv # Export to CSV"
}

# Parse command line arguments
parse_arguments() {
    REPORT_FILE=""
    COMPARE_FILE=""
    USE_LATEST=false
    OUTPUT_FORMAT="text"
    OUTPUT_FILE=""
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--latest)
                USE_LATEST=true
                shift
                ;;
            -c|--compare)
                COMPARE_FILE="$2"
                if [ ! -f "$COMPARE_FILE" ]; then
                    log_error "Compare file not found: $COMPARE_FILE"
                    exit 1
                fi
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json|csv)$ ]]; then
                    log_error "Invalid format. Must be: text, json, or csv"
                    exit 1
                fi
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
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
                if [ -z "$REPORT_FILE" ]; then
                    REPORT_FILE="$1"
                else
                    log_error "Multiple report files specified"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Find the latest test report
find_latest_report() {
    local latest_report=$(find "$OUTPUT_DIR" -name "test_report_*.json" -type f -exec ls -t {} + 2>/dev/null | head -1)
    
    if [ -z "$latest_report" ]; then
        log_error "No test reports found in $OUTPUT_DIR"
        log_error "Please run run_tests.sh first to generate test data"
        return 1
    fi
    
    echo "$latest_report"
    return 0
}

# Validate report file
validate_report_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_error "Report file not found: $file"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for report analysis"
        log_error "Please install jq to use this script"
        return 1
    fi
    
    # Validate JSON format
    if ! jq empty "$file" 2>/dev/null; then
        log_error "Invalid JSON format in report file: $file"
        return 1
    fi
    
    return 0
}

# Analyze single report
analyze_report() {
    local report_file="$1"
    local report_data
    
    if [ "$VERBOSE" = true ]; then
        log_info "Analyzing report: $report_file"
    fi
    
    report_data=$(cat "$report_file")
    
    # Extract basic statistics
    local total_queries=$(echo "$report_data" | jq '. | length')
    local successful_queries=$(echo "$report_data" | jq '[.[] | select(.success == true)] | length')
    local failed_queries=$(echo "$report_data" | jq '[.[] | select(.success == false)] | length')
    
    # Performance metrics
    local avg_response_time=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.response_time_ms] | add / length' 2>/dev/null)
    local min_response_time=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.response_time_ms] | min' 2>/dev/null)
    local max_response_time=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.response_time_ms] | max' 2>/dev/null)
    
    local avg_results=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.total_results] | add / length' 2>/dev/null)
    local total_results_found=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.total_results] | add' 2>/dev/null)
    
    local avg_relevance=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.relevance_score] | add / length' 2>/dev/null)
    local min_relevance=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.relevance_score] | min' 2>/dev/null)
    local max_relevance=$(echo "$report_data" | jq '[.[] | select(.success == true) | .metrics.relevance_score] | max' 2>/dev/null)
    
    # Quality distribution
    local excellent_count=$(echo "$report_data" | jq '[.[] | select(.metrics.result_quality == "excellent")] | length')
    local good_count=$(echo "$report_data" | jq '[.[] | select(.metrics.result_quality == "good")] | length')
    local fair_count=$(echo "$report_data" | jq '[.[] | select(.metrics.result_quality == "fair")] | length')
    local poor_count=$(echo "$report_data" | jq '[.[] | select(.metrics.result_quality == "poor")] | length')
    

    
    # Create analysis object
    local analysis
    analysis=$(jq -n \
        --argjson total_queries "$total_queries" \
        --argjson successful_queries "$successful_queries" \
        --argjson failed_queries "$failed_queries" \
        --argjson success_rate "$(echo "scale=2; $successful_queries * 100 / $total_queries" | bc -l 2>/dev/null || echo "0")" \
        --argjson avg_response_time "$avg_response_time" \
        --argjson min_response_time "$min_response_time" \
        --argjson max_response_time "$max_response_time" \
        --argjson avg_results "$avg_results" \
        --argjson total_results_found "$total_results_found" \
        --argjson avg_relevance "$avg_relevance" \
        --argjson min_relevance "$min_relevance" \
        --argjson max_relevance "$max_relevance" \
        --argjson excellent_count "$excellent_count" \
        --argjson good_count "$good_count" \
        --argjson fair_count "$fair_count" \
        --argjson poor_count "$poor_count" \
        --arg report_file "$report_file" \
        --arg analysis_timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            report_file: $report_file,
            analysis_timestamp: $analysis_timestamp,
            summary: {
                total_queries: $total_queries,
                successful_queries: $successful_queries,
                failed_queries: $failed_queries,
                success_rate: $success_rate
            },
            performance: {
                response_time: {
                    average: $avg_response_time,
                    minimum: $min_response_time,
                    maximum: $max_response_time
                },
                results: {
                    average_per_query: $avg_results,
                    total_found: $total_results_found
                },
                relevance: {
                    average_score: $avg_relevance,
                    minimum_score: $min_relevance,
                    maximum_score: $max_relevance
                }
            },
            quality_distribution: {
                excellent: $excellent_count,
                good: $good_count,
                fair: $fair_count,
                poor: $poor_count
            }
        }')
    

    
    echo "$analysis"
}

# Format analysis output
format_output() {
    local analysis="$1"
    local format="$2"
    
    case "$format" in
        "json")
            echo "$analysis" | jq '.'
            ;;
        "csv")
            # Create CSV header and data
            echo "metric,value"
            echo "$analysis" | jq -r '
                "total_queries," + (.summary.total_queries | tostring),
                "successful_queries," + (.summary.successful_queries | tostring),
                "failed_queries," + (.summary.failed_queries | tostring),
                "success_rate," + (.summary.success_rate | tostring),
                "avg_response_time," + (.performance.response_time.average | tostring),
                "min_response_time," + (.performance.response_time.minimum | tostring),
                "max_response_time," + (.performance.response_time.maximum | tostring),
                "avg_results_per_query," + (.performance.results.average_per_query | tostring),
                "total_results_found," + (.performance.results.total_found | tostring),
                "avg_relevance_score," + (.performance.relevance.average_score | tostring),
                "excellent_quality," + (.quality_distribution.excellent | tostring),
                "good_quality," + (.quality_distribution.good | tostring),
                "fair_quality," + (.quality_distribution.fair | tostring),
                "poor_quality," + (.quality_distribution.poor | tostring)
            '
            ;;
        "text"|*)
            # Human-readable text format
            echo "=========================================="
            echo "MANTICORE SEARCH PERFORMANCE ANALYSIS"
            echo "=========================================="
            echo "Report: $(echo "$analysis" | jq -r '.report_file')"
            echo "Analysis Time: $(echo "$analysis" | jq -r '.analysis_timestamp')"
            echo ""
            
            echo "SUMMARY STATISTICS:"
            echo "  Total Queries: $(echo "$analysis" | jq -r '.summary.total_queries')"
            echo "  Successful: $(echo "$analysis" | jq -r '.summary.successful_queries')"
            echo "  Failed: $(echo "$analysis" | jq -r '.summary.failed_queries')"
            echo "  Success Rate: $(echo "$analysis" | jq -r '.summary.success_rate')%"
            echo ""
            
            echo "PERFORMANCE METRICS:"
            echo "  Response Time:"
            echo "    Average: $(echo "$analysis" | jq -r '.performance.response_time.average | floor')ms"
            echo "    Minimum: $(echo "$analysis" | jq -r '.performance.response_time.minimum | floor')ms"
            echo "    Maximum: $(echo "$analysis" | jq -r '.performance.response_time.maximum | floor')ms"
            echo "  Results:"
            echo "    Average per Query: $(echo "$analysis" | jq -r '.performance.results.average_per_query | floor')"
            echo "    Total Found: $(echo "$analysis" | jq -r '.performance.results.total_found')"
            echo "  Relevance:"
            echo "    Average Score: $(echo "$analysis" | jq -r '.performance.relevance.average_score | floor')/100"
            echo "    Score Range: $(echo "$analysis" | jq -r '.performance.relevance.minimum_score | floor')-$(echo "$analysis" | jq -r '.performance.relevance.maximum_score | floor')"
            echo ""
            
            echo "QUALITY DISTRIBUTION:"
            echo "  Excellent: $(echo "$analysis" | jq -r '.quality_distribution.excellent')"
            echo "  Good: $(echo "$analysis" | jq -r '.quality_distribution.good')"
            echo "  Fair: $(echo "$analysis" | jq -r '.quality_distribution.fair')"
            echo "  Poor: $(echo "$analysis" | jq -r '.quality_distribution.poor')"
            echo ""
            

            
            echo "=========================================="
            ;;
    esac
}

# Compare two reports
compare_reports() {
    local report1="$1"
    local report2="$2"
    
    log_info "Comparing reports..."
    log_info "  Report 1: $report1"
    log_info "  Report 2: $report2"
    
    local analysis1=$(analyze_report "$report1")
    local analysis2=$(analyze_report "$report2")
    
    # Create comparison
    local comparison
    comparison=$(jq -n \
        --argjson report1 "$analysis1" \
        --argjson report2 "$analysis2" \
        '{
            comparison_timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            report1: $report1,
            report2: $report2,
            differences: {
                success_rate: ($report2.summary.success_rate - $report1.summary.success_rate),
                avg_response_time: ($report2.performance.response_time.average - $report1.performance.response_time.average),
                avg_relevance: ($report2.performance.relevance.average_score - $report1.performance.relevance.average_score),
                total_queries: ($report2.summary.total_queries - $report1.summary.total_queries)
            }
        }')
    
    echo "$comparison"
}

# Main function
main() {
    parse_arguments "$@"
    
    # Determine which report to analyze
    if [ "$USE_LATEST" = true ]; then
        if ! REPORT_FILE=$(find_latest_report); then
            exit 1
        fi
        log_info "Using latest report: $REPORT_FILE"
    elif [ -z "$REPORT_FILE" ]; then
        log_error "No report file specified"
        show_usage
        exit 1
    fi
    
    # Validate report file
    if ! validate_report_file "$REPORT_FILE"; then
        exit 1
    fi
    
    # Perform analysis
    local result
    if [ -n "$COMPARE_FILE" ]; then
        if ! validate_report_file "$COMPARE_FILE"; then
            exit 1
        fi
        result=$(compare_reports "$REPORT_FILE" "$COMPARE_FILE")
    else
        result=$(analyze_report "$REPORT_FILE")
    fi
    
    # Format and output result
    local formatted_output
    formatted_output=$(format_output "$result" "$OUTPUT_FORMAT")
    
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$formatted_output" > "$OUTPUT_FILE"
        log_success "Analysis saved to: $OUTPUT_FILE"
    else
        echo "$formatted_output"
    fi
}

# Handle script interruption
trap 'log_error "Analysis interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"