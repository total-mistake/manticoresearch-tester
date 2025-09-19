#!/usr/bin/env node

const express = require('express');
const cors = require('cors');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

// Log file path
const logFilePath = path.join(logsDir, `web_ui_${new Date().toISOString().split('T')[0]}.log`);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

// Logging function
function log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level}] ${message}`;
    
    // Log to console
    console.log(logMessage);
    
    // Log to file
    try {
        fs.appendFileSync(logFilePath, logMessage + '\n');
    } catch (error) {
        console.error(`Failed to write to log file: ${error.message}`);
    }
}

// Check if Manticore Search is running
async function checkManticoreHealth() {
    return new Promise((resolve) => {
        const healthCheck = spawn('./scripts/health_check.sh', [], {
            cwd: path.join(__dirname, '..'),
            stdio: 'pipe'
        });

        let output = '';
        healthCheck.stdout.on('data', (data) => {
            output += data.toString();
        });

        healthCheck.stderr.on('data', (data) => {
            output += data.toString();
        });

        healthCheck.on('close', (code) => {
            resolve({
                healthy: code === 0,
                output: output.trim()
            });
        });
    });
}

// Execute search using the existing script
async function executeSearch(query, options = {}) {
    const startTime = Date.now();
    
    return new Promise((resolve, reject) => {
        const args = [];
        
        // Add options
        if (options.limit) {
            args.push('--limit', options.limit.toString());
        }
        
        if (options.verbose) {
            args.push('--verbose');
        }
        
        // Always use JSON output for API
        args.push('--json');
        args.push(query);

        log(`Executing search: ${query} with args: ${args.join(' ')}`);

        const searchProcess = spawn('./scripts/search_nl.sh', args, {
            cwd: path.join(__dirname, '..'),
            stdio: 'pipe'
        });

        let stdout = '';
        let stderr = '';

        searchProcess.stdout.on('data', (data) => {
            stdout += data.toString();
        });

        searchProcess.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        searchProcess.on('close', (code) => {
            const endTime = Date.now();
            const executionTime = endTime - startTime;
            
            log(`Search completed in ${executionTime}ms with exit code: ${code}`);
            
            if (stderr) {
                log(`Search stderr: ${stderr}`, 'DEBUG');
            }

            if (code === 0) {
                try {
                    // Try to parse JSON from stdout
                    const jsonMatch = stdout.match(/\{[\s\S]*\}/);
                    if (jsonMatch) {
                        const result = JSON.parse(jsonMatch[0]);
                        
                        // Transform the result to a consistent format
                        const transformedResult = transformSearchResult(result, executionTime);
                        log(`Search successful: ${transformedResult.total} results found`);
                        resolve(transformedResult);
                    } else {
                        log(`No JSON found in output: ${stdout}`, 'WARN');
                        resolve({
                            total: 0,
                            hits: [],
                            took: executionTime,
                            max_score: 0,
                            error: 'No valid JSON response from search'
                        });
                    }
                } catch (parseError) {
                    log(`JSON parse error: ${parseError.message}`, 'ERROR');
                    log(`Raw output: ${stdout}`, 'DEBUG');
                    resolve({
                        total: 0,
                        hits: [],
                        took: executionTime,
                        max_score: 0,
                        error: `Parse error: ${parseError.message}`
                    });
                }
            } else {
                log(`Search failed with code ${code}: ${stderr}`, 'ERROR');
                reject(new Error(`Search failed: ${stderr || 'Unknown error'}`));
            }
        });

        searchProcess.on('error', (error) => {
            log(`Search process error: ${error.message}`, 'ERROR');
            reject(new Error(`Process error: ${error.message}`));
        });
    });
}

// Transform search result to consistent format
function transformSearchResult(result, executionTime) {
    // Handle different response formats from Manticore
    let hits = [];
    let total = 0;
    let took = executionTime;
    let maxScore = 0;

    if (result.hits) {
        if (Array.isArray(result.hits)) {
            // Format: { hits: [...] }
            hits = result.hits;
            total = hits.length;
        } else if (result.hits.hits && Array.isArray(result.hits.hits)) {
            // Format: { hits: { hits: [...], total: ... } }
            hits = result.hits.hits;
            total = result.hits.total || hits.length;
        }
    } else if (Array.isArray(result)) {
        // Format: [...]
        hits = result;
        total = hits.length;
    }

    // Extract took time if available
    if (result.took !== undefined) {
        took = result.took;
    }

    // Calculate max score
    if (hits.length > 0) {
        maxScore = Math.max(...hits.map(hit => {
            return hit._score || hit.score || 0;
        }));
    }

    // Normalize hit format
    const normalizedHits = hits.map((hit, index) => {
        const source = hit._source || hit;
        return {
            _id: hit._id || hit.id || (index + 1).toString(),
            _score: hit._score || hit.score || 0,
            _source: {
                title: source.title || 'Без названия',
                url: source.url || '#',
                content: source.content || 'Содержимое недоступно'
            }
        };
    });

    return {
        total: total,
        hits: normalizedHits,
        took: took,
        max_score: maxScore
    };
}

// API Routes

// Health check endpoint
app.get('/health', async (req, res) => {
    const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
    log(`Health check requested from ${clientIP}`);
    
    try {
        const health = await checkManticoreHealth();
        
        if (health.healthy) {
            log('Health check passed - Manticore Search is running');
            res.json({
                status: 'healthy',
                message: 'Manticore Search is running',
                details: health.output
            });
        } else {
            log('Health check failed - Manticore Search is not accessible');
            res.status(503).json({
                status: 'unhealthy',
                message: 'Manticore Search is not accessible',
                details: health.output
            });
        }
    } catch (error) {
        log(`Health check error: ${error.message}`, 'ERROR');
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

// Search endpoint
app.post('/search', async (req, res) => {
    const { query, limit = 10, verbose = false } = req.body;
    const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
    
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
        log(`Invalid search query received from ${clientIP}`, 'WARN');
        return res.status(400).json({
            error: 'Query parameter is required and must be a non-empty string'
        });
    }

    const trimmedQuery = query.trim();
    const searchLimit = Math.min(Math.max(1, parseInt(limit) || 10), 100);
    
    log(`Search request from ${clientIP}: "${trimmedQuery}" (limit: ${searchLimit}, verbose: ${verbose})`);

    try {
        const startTime = Date.now();
        const result = await executeSearch(trimmedQuery, {
            limit: searchLimit,
            verbose: Boolean(verbose)
        });
        const endTime = Date.now();
        const totalTime = endTime - startTime;

        log(`Search completed: ${result.total} results, max_score: ${result.max_score}, time: ${totalTime}ms`);
        
        // Log individual result scores for debugging
        if (result.hits && result.hits.length > 0) {
            const scores = result.hits.map(hit => Math.round((hit._score || 0) * 100)).join(', ');
            log(`Result scores: [${scores}]`, 'DEBUG');
        }
        
        res.json(result);

    } catch (error) {
        log(`Search error for "${trimmedQuery}": ${error.message}`, 'ERROR');
        res.status(500).json({
            error: error.message,
            total: 0,
            hits: [],
            took: 0,
            max_score: 0
        });
    }
});

// Serve the main HTML file
app.get('/', (req, res) => {
    const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
    log(`Main page requested from ${clientIP}`);
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Error handling middleware
app.use((error, req, res, next) => {
    const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
    log(`Unhandled error from ${clientIP}: ${error.message}`, 'ERROR');
    res.status(500).json({
        error: 'Internal server error',
        message: error.message
    });
});

// 404 handler
app.use((req, res) => {
    const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
    log(`404 - Not found from ${clientIP}: ${req.method} ${req.url}`, 'WARN');
    res.status(404).json({
        error: 'Not found',
        message: `Route ${req.method} ${req.url} not found`
    });
});

// Start server
app.listen(PORT, () => {
    log(`Manticore Search UI Server started on port ${PORT}`);
    log(`Open http://localhost:${PORT} in your browser`);
    log(`Logs are being saved to: ${logFilePath}`);
    log('Press Ctrl+C to stop the server');
});

// Graceful shutdown
process.on('SIGINT', () => {
    log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});

process.on('SIGTERM', () => {
    log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});