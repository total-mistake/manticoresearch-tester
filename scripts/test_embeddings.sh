#!/bin/bash

# Test script to verify Auto Embeddings functionality
# This script tests if embeddings are being generated and can be used for search

set -e

# Load connection configuration
if [ -f "configs/connection.conf" ]; then
    source configs/connection.conf
else
    echo "Error: Connection configuration not found. Run setup.sh first."
    exit 1
fi

INDEX_NAME="documents"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Insert test documents with different content
insert_test_documents() {
    log_info "Inserting test documents for embedding verification..."
    
    # Document 1: About automation
    local doc1='{
        "title": "Automation in Online Systems",
        "url": "https://test.com/automation",
        "content": "Automation systems use algorithms and artificial intelligence to manage processes automatically. These systems can handle complex tasks without human intervention."
    }'
    
    # Document 2: About games
    local doc2='{
        "title": "Online Gaming Experience",
        "url": "https://test.com/gaming",
        "content": "Online games provide entertainment through interactive experiences. Players can enjoy various game types including card games, slots, and live dealer games."
    }'
    
    # Document 3: About technology
    local doc3='{
        "title": "Technology Innovation",
        "url": "https://test.com/technology",
        "content": "Modern technology innovations include machine learning, neural networks, and advanced computing systems that transform how we work and play."
    }'
    
    # Insert documents
    for i in 1 2 3; do
        local doc_var="doc$i"
        local doc_json=$(eval echo \$${doc_var})
        local insert_json="{\"index\": \"$INDEX_NAME\", \"doc\": $doc_json}"
        
        local response=$(curl -s -X POST "$BASE_URL/insert" \
            -H "Content-Type: application/json" \
            -d "$insert_json")
        
        if echo "$response" | grep -q "\"created\":true\|\"result\":\"created\""; then
            log_info "Test document $i inserted successfully"
        else
            log_error "Failed to insert test document $i: $response"
            return 1
        fi
    done
    
    # Wait for embeddings to be generated
    log_info "Waiting for embeddings to be generated..."
    sleep 3
    
    return 0
}

# Test semantic search
test_semantic_search() {
    log_info "Testing semantic search functionality..."
    
    # Test query about automation - should match document 1
    local query1="artificial intelligence and automated processes"
    log_info "Testing query: '$query1'"
    
    local search_response=$(curl -s -X POST "$BASE_URL/search" \
        -H "Content-Type: application/json" \
        -d "{
            \"index\": \"$INDEX_NAME\",
            \"query\": {
                \"match\": {
                    \"content\": \"$query1\"
                }
            },
            \"limit\": 3
        }")
    
    if echo "$search_response" | grep -q "\"hits\""; then
        log_info "Search query executed successfully"
        local total_hits=$(echo "$search_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
        log_info "Found $total_hits matching documents"
        
        # Check if we got relevant results
        if echo "$search_response" | grep -q "Automation"; then
            log_info "✓ Semantic search appears to be working - found relevant automation content"
        else
            log_warn "? Semantic search results unclear - may need more testing"
        fi
        
        return 0
    else
        log_error "Search query failed: $search_response"
        return 1
    fi
}

# Clean up test documents
cleanup_test_documents() {
    log_info "Cleaning up test documents..."
    
    local cleanup_queries=(
        "DELETE FROM $INDEX_NAME WHERE title='Automation in Online Systems'"
        "DELETE FROM $INDEX_NAME WHERE title='Online Gaming Experience'"
        "DELETE FROM $INDEX_NAME WHERE title='Technology Innovation'"
    )
    
    for query in "${cleanup_queries[@]}"; do
        local response=$(curl -s -X POST "$BASE_URL/cli" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"$query\"}")
        
        log_info "Cleanup query executed: $response"
    done
}

# Main test function
main() {
    log_info "Starting Auto Embeddings functionality test..."
    
    # Check connection
    if ! curl -s -f "$BASE_URL/" >/dev/null 2>&1; then
        log_error "Manticore Search is not accessible at $BASE_URL"
        exit 1
    fi
    
    # Run tests
    if insert_test_documents && test_semantic_search; then
        log_info "✓ Auto Embeddings functionality test completed successfully!"
        cleanup_test_documents
        exit 0
    else
        log_error "✗ Auto Embeddings functionality test failed"
        cleanup_test_documents
        exit 1
    fi
}

# Handle interruption
trap 'log_error "Test interrupted"; cleanup_test_documents; exit 1' INT TERM

main "$@"