# Manticore Search AI Testing Framework

This project tests the Auto Embeddings and AI Search features introduced in Manticore Search 13.11.0 using Docker and bash scripts.

## Project Structure

```
.
├── scripts/           # Bash scripts for testing workflow
│   ├── setup.sh      # Docker setup and initialization
│   └── health_check.sh # Health check utilities
├── configs/          # Configuration files
│   ├── manticore.conf # Manticore Search configuration
│   └── connection.conf # Connection settings (auto-generated)
├── data/             # Markdown documentation files for testing
├── output/           # Search index data and logs
├── logs/             # Test execution logs
└── README.md         # This file
```

## Quick Start

1. **Setup Environment**
   ```bash
   ./scripts/setup.sh
   ```
   This will:
   - Pull Manticore Search 13.11.0 Docker image
   - Start the container with proper configuration
   - Perform health checks
   - Create connection configuration

2. **Verify Installation**
   ```bash
   ./scripts/health_check.sh
   ```

## Requirements

- Docker installed and running
- curl command available
- Ports 9306 and 9308 available
- Internet connection for Docker image download

## Configuration

The setup script creates a `configs/connection.conf` file with connection details:
- HTTP API: http://localhost:9308
- MySQL API: localhost:9306

## Error Handling

The setup script includes comprehensive error handling for:
- Docker availability and daemon status
- Port conflicts
- Container startup failures
- API connectivity issues
- Health check timeouts

## Troubleshooting

If setup fails:
1. Check Docker is running: `docker info`
2. Check port availability: `lsof -i :9308` and `lsof -i :9306`
3. Review container logs: `docker logs manticore-search-test`
4. Run health check: `./scripts/health_check.sh`

## Next Steps

After successful setup, you can proceed with:
- Data import (import_data.sh)
- Search testing (test_search.sh)
- Automated test scenarios (run_tests.sh)
- Environment cleanup (cleanup.sh)