# Auto Embeddings Configuration Guide

This guide explains how to configure and use Auto Embeddings in Manticore Search 13.11.0 for AI-powered search functionality.

## Overview

Auto Embeddings is a feature in Manticore Search that automatically generates vector embeddings for text content, enabling semantic search capabilities without manual embedding generation.

## Prerequisites

- Manticore Search 13.11.0 running in Docker
- Connection configuration file (`configs/connection.conf`)
- Bash environment with curl support

## Configuration Script

### `scripts/configure_embeddings.sh`

This script configures Auto Embeddings with the following features:

#### Key Configuration Parameters

- **Vector Dimensions**: 384 (optimized for general text content)
- **KNN Type**: HNSW (Hierarchical Navigable Small World)
- **Distance Metric**: Cosine similarity
- **HNSW Parameters**:
  - M parameter: 16 (connectivity)
  - EF Construction: 200 (search accuracy during index building)

#### What the Script Does

1. **Connection Verification**: Checks if Manticore Search is accessible
2. **Version Check**: Verifies service status and capabilities
3. **Index Creation**: Creates base table structure with text fields
4. **Embedding Configuration**: Adds FLOAT_VECTOR column with HNSW settings
5. **Verification**: Tests embedding functionality with sample documents
6. **Diagnostics**: Runs comprehensive health checks

### Usage

```bash
# Make sure Manticore Search is running
./scripts/setup.sh

# Configure Auto Embeddings
./scripts/configure_embeddings.sh
```

### Expected Output

```
[INFO] Starting Auto Embeddings configuration for Manticore Search...
[INFO] Auto Embeddings Configuration Summary:
==================================
Index Name: documents
Embedding Dimensions: 384
KNN Type: hnsw
Distance Metric: cosine
HNSW M Parameter: 16
HNSW EF Construction: 200
Base URL: http://localhost:9308
==================================
[SUCCESS] Manticore Search is accessible
[SUCCESS] Version check completed
[SUCCESS] Base index created successfully
[SUCCESS] Auto Embeddings configuration added successfully
[SUCCESS] Test document inserted successfully - embedding column is functional
[SUCCESS] Auto Embeddings configuration completed successfully!
```

## Testing Script

### `scripts/test_embeddings.sh`

This script verifies that Auto Embeddings are working correctly by:

1. Inserting test documents with different semantic content
2. Performing semantic search queries
3. Verifying that relevant results are returned
4. Cleaning up test data

### Usage

```bash
# Test embedding functionality
./scripts/test_embeddings.sh
```

## Table Structure

After configuration, the `documents` table will have the following structure:

```sql
CREATE TABLE documents (
    title TEXT,
    url STRING,
    content TEXT,
    embedding FLOAT_VECTOR knn_type='hnsw' knn_dims=384 knn_distance='cosine' knn_hnsw_m=16 knn_hnsw_ef_construction=200
) engine='columnar'
```

## How Auto Embeddings Work

1. **Automatic Generation**: When documents are inserted, Manticore automatically generates embeddings for text fields
2. **Vector Storage**: Embeddings are stored in the `embedding` FLOAT_VECTOR column
3. **Search Integration**: Search queries can use vector similarity for semantic matching
4. **No Manual Work**: No need to generate embeddings externally or manage vector data

## Troubleshooting

### Common Issues

1. **Connection Errors**
   - Ensure Manticore Search is running: `docker ps`
   - Check port availability: `curl http://localhost:9308/`

2. **Configuration Failures**
   - Verify Manticore version supports Auto Embeddings
   - Check Docker container logs: `docker logs manticore-search-test`

3. **Embedding Generation Issues**
   - Wait a few seconds after document insertion for embedding generation
   - Check if documents are being inserted successfully
   - Verify table structure includes embedding column

### Diagnostic Commands

```bash
# Check service status
curl -X POST "http://localhost:9308/cli" \
  -H "Content-Type: application/json" \
  -d '{"query": "SHOW STATUS"}'

# Test document insertion
curl -X POST "http://localhost:9308/insert" \
  -H "Content-Type: application/json" \
  -d '{
    "index": "documents",
    "doc": {
      "title": "Test",
      "url": "https://test.com",
      "content": "Test content for embedding generation"
    }
  }'

# Test search functionality
curl -X POST "http://localhost:9308/search" \
  -H "Content-Type: application/json" \
  -d '{
    "index": "documents",
    "query": {"match_all": {}},
    "limit": 1
  }'
```

## Next Steps

After configuring Auto Embeddings:

1. **Import Data**: Use `scripts/import_data.sh` to populate the index
2. **Test Search**: Use `scripts/test_search.sh` for natural language queries
3. **Run Tests**: Execute `scripts/run_tests.sh` for comprehensive testing

## Configuration Details

### Vector Dimensions (384)

- Optimized for general text content
- Balances accuracy and performance
- Compatible with most embedding models

### HNSW Parameters

- **M=16**: Good balance between accuracy and memory usage
- **EF Construction=200**: Higher accuracy during index building
- **Cosine Distance**: Effective for text similarity

### Engine Type

- **Columnar**: Optimized for analytical queries and vector operations
- Better performance for embedding storage and retrieval

## Performance Considerations

- Embedding generation happens automatically but may add slight latency to insertions
- Vector searches are highly optimized with HNSW indexing
- Memory usage scales with document count and vector dimensions
- Consider batch insertions for large datasets

## Security Notes

- Auto Embeddings process text content locally within Manticore
- No external API calls for embedding generation
- All vector data stored within the Manticore instance
- Standard Manticore security practices apply