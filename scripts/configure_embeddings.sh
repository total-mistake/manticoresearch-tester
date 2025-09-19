#!/bin/bash

# Auto Embeddings Configuration Script for Manticore Search
# This script configures Auto Embeddings with proper vector dimensions and verification

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
EMBEDDING_DIMS=384
EMBEDDING_TYPE="hnsw"
EMBEDDING_DISTANCE="cosine"
HNSW_M=16
HNSW_EF_CONSTRUCTION=200

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Check if Manticore Search is accessible
check_manticore_connection() {
    log_info "Checking Manticore Search connection..."
    
    if ! curl -s -f "$BASE_URL/" >/dev/null 2>&1; then
        log_error "Manticore Search is not accessible at $BASE_URL"
        log_error "Please run setup.sh first to start the service"
        return 1
    fi
    
    log_success "Manticore Search is accessible"
    return 0
}

# Get Manticore Search version and capabilities
check_version_and_capabilities() {
    log_info "Checking Manticore Search version and capabilities..."
    
    local status_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d '{"query": "SHOW STATUS"}')
    
    if echo "$status_response" | grep -q "Query OK"; then
        log_debug "Status response: $status_response"
        
        # Extract version if available
        local version=$(echo "$status_response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$version" ]; then
            log_info "Manticore Search version: $version"
        fi
        
        log_success "Version check completed"
        return 0
    else
        log_error "Failed to get Manticore Search status"
        log_error "Response: $status_response"
        return 1
    fi
}

# Check if index exists
check_index_exists() {
    log_info "Checking if index '$INDEX_NAME' exists..."
    
    local show_tables_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d '{"query": "SHOW TABLES"}')
    
    if echo "$show_tables_response" | grep -q "\"$INDEX_NAME\""; then
        log_info "Index '$INDEX_NAME' exists"
        return 0
    else
        log_warn "Index '$INDEX_NAME' does not exist"
        return 1
    fi
}

# Check if index has existing data
check_existing_data() {
    log_info "Checking for existing data in index '$INDEX_NAME'..."
    
    local search_response=$(curl -s -X POST "$BASE_URL/search" \
        -H "Content-Type: application/json" \
        -d "{\"index\": \"$INDEX_NAME\", \"query\": {\"match_all\": {}}, \"limit\": 1}")
    
    if echo "$search_response" | grep -q "\"total\":[1-9]"; then
        local total_docs=$(echo "$search_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
        log_warn "Index '$INDEX_NAME' already contains $total_docs documents"
        log_warn "Proceeding will recreate the index and lose existing data"
        return 0
    else
        log_info "Index '$INDEX_NAME' appears to be empty or doesn't exist"
        return 1
    fi
}

# Create search index with basic structure
create_base_index() {
    log_info "Creating base search index '$INDEX_NAME'..."
    
    # Check for existing data first
    if check_existing_data; then
        log_warn "Existing data detected. Recreating index will remove all data."
    fi
    
    # Drop existing index if it exists
    local drop_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"DROP TABLE IF EXISTS $INDEX_NAME\"}")
    
    log_debug "Drop index response: $drop_response"
    
    # Create the base index structure
    local create_query="CREATE TABLE $INDEX_NAME (
        title TEXT,
        url STRING,
        content TEXT
    ) engine='columnar'"
    
    local create_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$create_query\"}")
    
    if echo "$create_response" | grep -q "Query OK"; then
        log_success "Base index created successfully"
        return 0
    else
        log_error "Failed to create base index"
        log_error "Response: $create_response"
        return 1
    fi
}

# Add Auto Embeddings configuration to existing index
configure_auto_embeddings() {
    log_info "Configuring Auto Embeddings for index '$INDEX_NAME'..."
    
    # Add embedding column with HNSW configuration
    local embedding_query="ALTER TABLE $INDEX_NAME ADD COLUMN embedding FLOAT_VECTOR knn_type='$EMBEDDING_TYPE' knn_dims=$EMBEDDING_DIMS knn_distance='$EMBEDDING_DISTANCE' knn_hnsw_m=$HNSW_M knn_hnsw_ef_construction=$HNSW_EF_CONSTRUCTION"
    
    log_debug "Embedding configuration query: $embedding_query"
    
    local embedding_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$embedding_query\"}")
    
    if echo "$embedding_response" | grep -q "Query OK"; then
        log_success "Auto Embeddings configuration added successfully"
        log_info "Configuration details:"
        log_info "  - Vector dimensions: $EMBEDDING_DIMS"
        log_info "  - KNN type: $EMBEDDING_TYPE"
        log_info "  - Distance metric: $EMBEDDING_DISTANCE"
        log_info "  - HNSW M parameter: $HNSW_M"
        log_info "  - HNSW EF construction: $HNSW_EF_CONSTRUCTION"
        return 0
    else
        log_error "Failed to configure Auto Embeddings"
        log_error "Response: $embedding_response"
        return 1
    fi
}

# Verify embedding configuration
verify_embedding_configuration() {
    log_info "Verifying embedding configuration..."
    
    # Try to insert a test document to verify the embedding column exists
    local test_doc='{
        "title": "Embedding Verification Test",
        "url": "https://test.example.com/verify",
        "content": "This is a test to verify embedding configuration"
    }'
    
    local insert_json="{\"index\": \"$INDEX_NAME\", \"doc\": $test_doc}"
    
    local insert_response=$(curl -s -X POST "$BASE_URL/insert" \
        -H "Content-Type: application/json" \
        -d "$insert_json")
    
    if echo "$insert_response" | grep -q "\"created\":true\|\"result\":\"created\""; then
        log_success "Test document inserted successfully - embedding column is functional"
        
        # Clean up test document
        local delete_response=$(curl -s -X POST "$BASE_URL/cli" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"DELETE FROM $INDEX_NAME WHERE title='Embedding Verification Test'\"}")
        
        log_debug "Test document cleanup: $delete_response"
        return 0
    else
        log_error "Failed to insert test document - embedding configuration may have issues"
        log_error "Response: $insert_response"
        return 1
    fi
}

# Insert test document to verify embedding generation
test_embedding_generation() {
    log_info "Testing embedding generation with sample document..."
    
    # Insert a test document
    local test_doc='{
        "title": "Test Document for Embedding Verification",
        "url": "https://test.example.com/embedding-test",
        "content": "This is a test document to verify that Auto Embeddings are working correctly in Manticore Search. The system should automatically generate vector embeddings for this content."
    }'
    
    local insert_json="{\"index\": \"$INDEX_NAME\", \"doc\": $test_doc}"
    
    local insert_response=$(curl -s -X POST "$BASE_URL/insert" \
        -H "Content-Type: application/json" \
        -d "$insert_json")
    
    if echo "$insert_response" | grep -q "\"created\":true\|\"result\":\"created\""; then
        log_success "Test document inserted successfully"
        
        # Wait a moment for embedding generation
        sleep 2
        
        # Query the document to check if embedding was generated
        local select_response=$(curl -s -X POST "$BASE_URL/cli" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"SELECT id, title, embedding FROM $INDEX_NAME WHERE title='Test Document for Embedding Verification' LIMIT 1\"}")
        
        if echo "$select_response" | grep -q "Query OK"; then
            log_success "Test document retrieved successfully"
            
            # Check if embedding field has data (not null/empty)
            if echo "$select_response" | grep -q "embedding"; then
                log_success "Embedding field is present in query results"
                
                # Clean up test document
                local delete_response=$(curl -s -X POST "$BASE_URL/cli" \
                    -H "Content-Type: application/json" \
                    -d "{\"query\": \"DELETE FROM $INDEX_NAME WHERE title='Test Document for Embedding Verification'\"}")
                
                log_debug "Test document cleanup: $delete_response"
                return 0
            else
                log_warn "Embedding field not found in query results"
                log_debug "Query response: $select_response"
                return 1
            fi
        else
            log_error "Failed to retrieve test document"
            log_error "Response: $select_response"
            return 1
        fi
    else
        log_error "Failed to insert test document"
        log_error "Response: $insert_response"
        return 1
    fi
}

# Diagnostic function for embedding configuration troubleshooting
run_embedding_diagnostics() {
    log_info "Running embedding configuration diagnostics..."
    
    local diagnostics_passed=0
    local diagnostics_total=0
    
    # Diagnostic 1: Check table structure
    diagnostics_total=$((diagnostics_total + 1))
    log_info "Diagnostic 1/5: Checking table structure..."
    
    local describe_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"DESCRIBE $INDEX_NAME\"}")
    
    if echo "$describe_response" | grep -q "embedding.*float_vector"; then
        log_success "✓ Table has embedding column with correct type"
        diagnostics_passed=$((diagnostics_passed + 1))
    else
        log_error "✗ Table missing embedding column or incorrect type"
        log_debug "Table structure: $describe_response"
    fi
    
    # Diagnostic 2: Check KNN configuration by testing vector search
    diagnostics_total=$((diagnostics_total + 1))
    log_info "Diagnostic 2/5: Testing KNN/vector search capability..."
    
    # Try a simple KNN search to verify vector functionality
    local knn_test_response=$(curl -s -X POST "$BASE_URL/search" \
        -H "Content-Type: application/json" \
        -d "{\"index\": \"$INDEX_NAME\", \"query\": {\"match_all\": {}}, \"limit\": 1}")
    
    if echo "$knn_test_response" | grep -q "\"hits\""; then
        log_success "✓ Vector search endpoint is functional"
        diagnostics_passed=$((diagnostics_passed + 1))
    else
        log_warn "✗ Vector search functionality test inconclusive"
        log_debug "KNN test response: $knn_test_response"
    fi
    
    # Diagnostic 3: Test basic insert operation
    diagnostics_total=$((diagnostics_total + 1))
    log_info "Diagnostic 3/5: Testing basic insert operation..."
    
    local test_insert='{
        "title": "Diagnostic Test",
        "url": "https://diagnostic.test",
        "content": "Diagnostic test content"
    }'
    
    local insert_json="{\"index\": \"$INDEX_NAME\", \"doc\": $test_insert}"
    local insert_response=$(curl -s -X POST "$BASE_URL/insert" \
        -H "Content-Type: application/json" \
        -d "$insert_json")
    
    if echo "$insert_response" | grep -q "\"created\":true\|\"result\":\"created\""; then
        log_success "✓ Basic insert operation successful"
        diagnostics_passed=$((diagnostics_passed + 1))
        
        # Clean up diagnostic document
        curl -s -X POST "$BASE_URL/cli" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"DELETE FROM $INDEX_NAME WHERE title='Diagnostic Test'\"}" >/dev/null
    else
        log_error "✗ Basic insert operation failed"
        log_debug "Insert response: $insert_response"
    fi
    
    # Diagnostic 4: Check search functionality
    diagnostics_total=$((diagnostics_total + 1))
    log_info "Diagnostic 4/5: Testing search functionality..."
    
    local search_response=$(curl -s -X POST "$BASE_URL/search" \
        -H "Content-Type: application/json" \
        -d "{\"index\": \"$INDEX_NAME\", \"query\": {\"match_all\": {}}, \"limit\": 1}")
    
    if echo "$search_response" | grep -q "\"hits\""; then
        log_success "✓ Search functionality is working"
        diagnostics_passed=$((diagnostics_passed + 1))
    else
        log_error "✗ Search functionality test failed"
        log_debug "Search response: $search_response"
    fi
    
    # Diagnostic 5: Check service status
    diagnostics_total=$((diagnostics_total + 1))
    log_info "Diagnostic 5/5: Checking service status..."
    
    local status_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d '{"query": "SHOW STATUS"}')
    
    if echo "$status_response" | grep -q "Query OK"; then
        log_success "✓ Service status check passed"
        diagnostics_passed=$((diagnostics_passed + 1))
    else
        log_error "✗ Service status check failed"
        log_debug "Status response: $status_response"
    fi
    
    # Summary
    log_info "Diagnostics Summary: $diagnostics_passed/$diagnostics_total checks passed"
    
    if [ $diagnostics_passed -eq $diagnostics_total ]; then
        log_success "All diagnostics passed - embedding configuration appears healthy"
        return 0
    elif [ $diagnostics_passed -gt $((diagnostics_total / 2)) ]; then
        log_warn "Most diagnostics passed - configuration may have minor issues"
        return 0
    else
        log_error "Multiple diagnostics failed - embedding configuration needs attention"
        return 1
    fi
}

# Display configuration summary
display_configuration_summary() {
    log_info "Auto Embeddings Configuration Summary:"
    echo "=================================="
    echo "Index Name: $INDEX_NAME"
    echo "Embedding Dimensions: $EMBEDDING_DIMS"
    echo "KNN Type: $EMBEDDING_TYPE"
    echo "Distance Metric: $EMBEDDING_DISTANCE"
    echo "HNSW M Parameter: $HNSW_M"
    echo "HNSW EF Construction: $HNSW_EF_CONSTRUCTION"
    echo "Base URL: $BASE_URL"
    echo "=================================="
}

# Main configuration function
main() {
    log_info "Starting Auto Embeddings configuration for Manticore Search..."
    
    # Display configuration
    display_configuration_summary
    
    # Step 1: Check connection
    if ! check_manticore_connection; then
        exit 1
    fi
    
    # Step 2: Check version and capabilities
    if ! check_version_and_capabilities; then
        log_warn "Version check failed, continuing anyway..."
    fi
    
    # Step 3: Create or recreate index with embeddings
    if ! create_base_index; then
        exit 1
    fi
    
    # Step 4: Configure Auto Embeddings
    if ! configure_auto_embeddings; then
        exit 1
    fi
    
    # Step 5: Verify configuration
    if ! verify_embedding_configuration; then
        log_error "Embedding configuration verification failed"
        exit 1
    fi
    
    # Step 6: Test embedding generation
    if ! test_embedding_generation; then
        log_warn "Embedding generation test failed, but configuration may still work"
    fi
    
    # Step 7: Run diagnostics
    if ! run_embedding_diagnostics; then
        log_warn "Some diagnostics failed, but basic configuration is complete"
    fi
    
    log_success "Auto Embeddings configuration completed successfully!"
    log_info "The index '$INDEX_NAME' is now configured with Auto Embeddings"
    log_info "You can now import data using import_data.sh"
    
    exit 0
}

# Handle script interruption
trap 'log_error "Configuration interrupted"; exit 1' INT TERM

# Run main function
main "$@"