#!/bin/bash

# Markdown Data Parser and Import Script
# This script parses markdown files and imports them into Manticore Search

set -e

# Load connection configuration
if [ -f "configs/connection.conf" ]; then
    source configs/connection.conf
else
    echo "Error: Connection configuration not found. Run setup.sh first."
    exit 1
fi

# Configuration
DATA_DIR="data"
INDEX_NAME="documents"
BATCH_SIZE=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Validate markdown file structure
validate_markdown_file() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    if [ ! -f "$file_path" ]; then
        log_error "File does not exist: $file_path"
        return 1
    fi
    
    if [ ! -s "$file_path" ]; then
        log_warn "File is empty: $filename"
        return 1
    fi
    
    # Check if file has .md extension
    if [[ ! "$filename" =~ \.md$ ]]; then
        log_warn "File does not have .md extension: $filename"
        return 1
    fi
    
    # Check if file contains at least a title (starts with #)
    if ! grep -q "^#" "$file_path"; then
        log_warn "File does not contain a title (no # header): $filename"
        return 1
    fi
    
    log_debug "File validation passed: $filename"
    return 0
}

# Extract title from markdown file
extract_title() {
    local file_path="$1"
    local title=""
    
    # Get the first line that starts with # (title) and remove # characters and spaces
    title=$(grep -m 1 "^#" "$file_path" | sed 's/^#* *//' | sed 's/\s*$//')
    
    if [ -z "$title" ]; then
        # Fallback to filename without extension
        title=$(basename "$file_path" .md | tr '_' ' ')
        log_warn "No title found in $file_path, using filename: $title"
    fi
    
    echo "$title"
}

# Extract URL from markdown file
extract_url() {
    local file_path="$1"
    local url=""
    
    # Look for URL pattern: **URL:** https://...
    url=$(grep -i "^\*\*URL:\*\*" "$file_path" | sed 's/^\*\*URL:\*\*\s*//' | sed 's/^\s*//' | sed 's/\s*$//' | head -1)
    
    if [ -z "$url" ]; then
        # Look for alternative URL patterns
        url=$(grep -oE "https?://[^\s]+" "$file_path" | head -1)
    fi
    
    if [ -z "$url" ]; then
        # Generate a placeholder URL based on filename
        local filename=$(basename "$file_path" .md)
        url="https://nethouse.ru/about/instructions/$filename"
        log_debug "No URL found in $file_path, generated: $url"
    fi
    
    echo "$url"
}

# Extract content from markdown file (excluding title and URL lines)
extract_content() {
    local file_path="$1"
    local content=""
    
    # Read file content, skip first line (title), skip URL line, skip empty lines, then clean up
    content=$(tail -n +2 "$file_path" | \
        grep -v "^\*\*URL:\*\*" | \
        sed '/^$/d' | \
        sed 's/\r$//' | \
        tr '\n' ' ' | \
        sed 's/  */ /g' | \
        sed 's/^ *//' | \
        sed 's/ *$//')
    
    if [ -z "$content" ]; then
        log_warn "No content extracted from $file_path"
        return 1
    fi
    
    echo "$content"
}



# Escape JSON string
escape_json_string() {
    local input="$1"
    # Escape backslashes first, then quotes, then control characters, and trim spaces
    echo "$input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/\\t/g' | sed 's/\r/\\r/g' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//'
}

# Parse single markdown file and return JSON
parse_markdown_file() {
    local file_path="$1"
    local id="$2"
    
    # Validate file silently
    if ! validate_markdown_file "$file_path" >/dev/null 2>&1; then
        return 1
    fi
    
    local title=$(extract_title "$file_path")
    local url=$(extract_url "$file_path")
    local content=$(extract_content "$file_path")
    
    if [ -z "$content" ]; then
        log_error "Failed to extract content from $file_path"
        return 1
    fi
    
    # Escape JSON strings
    title=$(escape_json_string "$title")
    url=$(escape_json_string "$url")
    content=$(escape_json_string "$content")
    
    # Create JSON object (let Manticore auto-generate ID)
    cat << EOF
{
  "title": "$title",
  "url": "$url",
  "content": "$content"
}
EOF
}

# Create search index with Auto Embeddings configuration
create_search_index() {
    log_info "Creating search index with Auto Embeddings configuration..."
    
    # First, drop the index if it exists
    local drop_response=$(curl -s -X POST "$BASE_URL/sql?mode=raw" \
        -d "DROP TABLE IF EXISTS $INDEX_NAME")
    
    log_debug "Drop index response: $drop_response"
    
    # Create the index with Auto Embeddings (ID will be auto-generated)
    local create_query="CREATE TABLE $INDEX_NAME (
        title TEXT,
        url STRING,
        content TEXT,
        vector FLOAT_VECTOR KNN_TYPE='hnsw' HNSW_SIMILARITY='l2'
        MODEL_NAME='sergeyzh/BERTA'
        FROM='title,content'
    ) engine='columnar'"
    
    local create_response=$(curl -s -X POST "$BASE_URL/sql?mode=raw" \
        -d "$create_query")
    
    if echo "$create_response" | grep -q "[{\"total\":0,\"error\":\"\",\"warning\":\"\"}]"; then
        log_info "Search index created successfully"
    else
        log_error "Failed to create search index"
        log_error "Response: $create_response"
        return 1
    fi
}

# Format JSON for bulk insert (NDJSON format)
format_bulk_insert_json() {
    local documents_array="$1"
    
    # Convert JSON array to NDJSON format for Manticore bulk insert
    echo "$documents_array" | jq -c '.[]' | while read -r doc; do
        echo "{\"insert\":{\"index\":\"$INDEX_NAME\",\"doc\":$doc}}"
    done
}

# Insert documents via bulk API
bulk_insert_documents() {
    local documents_array="$1"
    
    log_info "Inserting documents via bulk API..."
    
    # Create bulk insert NDJSON
    local bulk_ndjson=$(format_bulk_insert_json "$documents_array")
    
    log_debug "Bulk insert NDJSON: $bulk_ndjson"
    
    # Send bulk insert request with correct content type
    local response=$(curl -s -X POST "$BASE_URL/bulk" \
        -H "Content-Type: application/x-ndjson" \
        -d "$bulk_ndjson")
    
    if echo "$response" | grep -q "\"errors\":false"; then
        log_info "Bulk insert completed successfully"
        return 0
    else
        log_error "Bulk insert failed"
        log_error "Response: $response"
        return 1
    fi
}

# Insert single document
insert_single_document() {
    local document_json="$1"
    
    local insert_json="{\"index\": \"$INDEX_NAME\", \"doc\": $document_json}"
    
    local response=$(curl -s -X POST "$BASE_URL/insert" \
        -H "Content-Type: application/json" \
        -d "$insert_json")
    
    if echo "$response" | grep -q "\"created\":true\|\"result\":\"created\""; then
        return 0
    else
        log_debug "Single insert response: $response"
        return 1
    fi
}

# Process all markdown files in data directory
process_markdown_files() {
    log_info "Processing markdown files from $DATA_DIR directory..."
    
    if [ ! -d "$DATA_DIR" ]; then
        log_error "Data directory does not exist: $DATA_DIR"
        return 1
    fi
    
    local md_files=($(find "$DATA_DIR" -name "*.md" -type f | sort))
    local total_files=${#md_files[@]}
    
    if [ $total_files -eq 0 ]; then
        log_error "No markdown files found in $DATA_DIR directory"
        return 1
    fi
    
    log_info "Found $total_files markdown files to process"
    
    local processed_count=0
    local failed_count=0
    
    for file_path in "${md_files[@]}"; do
        local filename=$(basename "$file_path")
        local id=$((processed_count + failed_count + 1))
        
        log_debug "Processing file: $filename (ID: $id)"
        
        local document_json=$(parse_markdown_file "$file_path" "$id")
        
        if [ $? -eq 0 ] && [ -n "$document_json" ]; then
            log_info "Processed: $filename"
            
            # Insert individual document immediately
            if insert_single_document "$document_json"; then
                processed_count=$((processed_count + 1))
                log_debug "Successfully inserted: $filename"
            else
                log_warn "Failed to insert document: $filename"
                failed_count=$((failed_count + 1))
            fi
        else
            failed_count=$((failed_count + 1))
            log_warn "Failed to process: $filename"
        fi
    done
    
    log_info "Processing completed: $processed_count successful, $failed_count failed"
    return 0
}

# Verify data insertion
verify_data_insertion() {
    log_info "Verifying data insertion..."
    
    # Use SQL query to count documents
    local count_response=$(curl -s -X POST "$BASE_URL/cli" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"SELECT COUNT(*) FROM $INDEX_NAME\"}")
    
    if echo "$count_response" | grep -q "Query OK"; then
        local total_docs=$(echo "$count_response" | grep -o '"COUNT(\\*)":"[0-9]*"' | cut -d'"' -f4)
        if [ -z "$total_docs" ]; then
            # Try alternative parsing
            total_docs=$(echo "$count_response" | grep -o '"data":\[\[.*\]\]' | grep -o '[0-9]\+' | head -1)
        fi
        log_info "Verification successful: $total_docs documents in index"
        
        # Show a sample document
        local sample_response=$(curl -s -X POST "$BASE_URL/cli" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"SELECT * FROM $INDEX_NAME LIMIT 1\"}")
        
        log_debug "Sample document: $sample_response"
        return 0
    else
        log_error "Verification failed"
        log_error "Response: $count_response"
        return 1
    fi
}

# Main import function
main() {
    log_info "Starting markdown data import process..."
    
    # Check if Manticore Search is running
    if ! curl -s -f "$BASE_URL/" >/dev/null 2>&1; then
        log_error "Manticore Search is not accessible at $BASE_URL"
        log_error "Please run setup.sh first to start the service"
        exit 1
    fi
    
    # Create search index
    if ! create_search_index; then
        log_error "Failed to create search index"
        exit 1

    fi
    
    # Process and import markdown files
    if ! process_markdown_files; then
        log_error "Failed to process markdown files"
        exit 1
    fi
    
    # Verify the import
    if ! verify_data_insertion; then
        log_error "Data verification failed"
        exit 1
    fi
    
    log_info "Markdown data import completed successfully!"
    log_info "Index: $INDEX_NAME"
    log_info "Data source: $DATA_DIR"
    
    exit 0
}

# Handle script interruption
trap 'log_error "Import interrupted"; exit 1' INT TERM

# Run main function
main "$@"