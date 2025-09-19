# Manticore Search AI Testing Guide

This guide explains how to use the automated test scenarios and reporting system for Manticore Search AI features.

## Overview

The testing system consists of three main components:

1. **run_tests.sh** - Executes predefined natural language test queries
2. **analyze_results.sh** - Analyzes test results and generates performance reports
3. **search_nl.sh** - Individual natural language search functionality (used by run_tests.sh)

## Quick Start

### 1. Run All Test Scenarios

```bash
./scripts/run_tests.sh
```

This will execute all 15 predefined Russian test queries and generate:
- JSON report: `output/test_report_YYYYMMDD_HHMMSS.json`
- Summary report: `output/test_summary_YYYYMMDD_HHMMSS.txt`

### 2. Analyze Results

```bash
./scripts/analyze_results.sh --latest
```

This will analyze the most recent test report and display detailed performance metrics.

## Test Queries

The system includes 15 predefined test queries in Russian, covering different categories:

### Predefined Test Queries
- "Как работает автоматизация в онлайн казино?"
- "Что такое баллы и как их использовать?"
- "Цели и задачи проекта"
- "Настройка домена и FTP доступ"
- "Адаптивные шаблоны и мобильная версия"
- "Будет ли реклама на моем сайте?"
- "Что происходит с сайтом после истечения тарифа?"
- "Как добавить отзывы на главную страницу?"
- "Что такое robots.txt файл?"
- "Эффективные методы контент маркетинга"
- "Есть ли у вас тестовый период?"
- "Подробные видеоинструкции по использованию"
- "Центр конфиденциальности и защита данных"
- "Дополнительные преимущества собственного домена"
- "Потеря данных при смене шаблона"

## Advanced Usage



### Run Single Query

```bash
./scripts/run_tests.sh --query "Что такое баллы и как их использовать?"
```

### Verbose Mode with Custom Limits

```bash
./scripts/run_tests.sh --verbose --limit 5 --timeout 60
```

### JSON-Only Output

```bash
./scripts/run_tests.sh --json-only > my_results.json
```

## Performance Analysis

### Basic Analysis

```bash
# Analyze latest report
./scripts/analyze_results.sh --latest

# Analyze specific report
./scripts/analyze_results.sh output/test_report_20231201_120000.json
```

### Export Analysis

```bash
# Export to CSV
./scripts/analyze_results.sh --latest --format csv --output analysis.csv

# Export to JSON
./scripts/analyze_results.sh --latest --format json --output analysis.json
```

### Compare Reports

```bash
./scripts/analyze_results.sh --compare old_report.json new_report.json
```

## Metrics Collected

### Performance Metrics
- **Response Time**: Total time from query start to completion (milliseconds)
- **Search Time**: Internal Manticore search processing time (milliseconds)
- **Result Count**: Number of documents returned
- **Top Score**: Highest relevance score in results

### Quality Metrics
- **Relevance Score**: Calculated quality score (0-100)
- **Result Quality**: Categorical assessment (excellent, good, fair, poor)
- **Success Rate**: Percentage of successful queries
- **Expected vs Actual**: Comparison with expected result counts



## Output Files

### JSON Report Format
```json
[
  {
    "query": "Test query",
    "metrics": {
      "response_time_ms": 1250,
      "search_time_ms": 45,
      "total_results": 3,
      "expected_results": 2,
      "top_score": 0.85,
      "relevance_score": 90,
      "result_quality": "excellent"
    },
    "success": true,
    "error": "",
    "timestamp": "2023-12-01T12:00:00Z"
  }
]
```

### Summary Report Sections
1. **Overall Performance**: Success rates, averages, totals
2. **Search Quality Analysis**: Quality distribution
3. **Top Performing Queries**: Best results by relevance
4. **Failed Queries**: Error analysis and suggestions
5. **Recommendations**: Performance improvement suggestions

## Troubleshooting

### Common Issues

1. **"Connection configuration not found"**
   - Run `setup.sh` first to initialize Manticore Search

2. **"Index 'documents' does not exist"**
   - Run `configure_embeddings.sh` and `import_data.sh`

3. **"jq not found"**
   - Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

4. **"bc not found"**
   - Install bc: `brew install bc` (macOS) or `apt-get install bc` (Linux)

### Performance Issues

- **Slow queries**: Increase timeout with `--timeout` option
- **Low relevance scores**: Check index configuration and data quality
- **High failure rates**: Verify Manticore Search is running and accessible

## Integration with CI/CD

The testing system can be integrated into continuous integration pipelines:

```bash
# Run tests and check success rate
./scripts/run_tests.sh --json-only | jq '.[] | select(.success == false) | length' | xargs test 0 -eq
```

## Customization

### Adding New Test Queries

1. Edit `scripts/run_tests.sh`
2. Add queries to the `TEST_QUERIES` array
3. Update the `get_expected_results()` function
4. Test the new queries

### Modifying Quality Assessment

The quality assessment logic is in the `execute_test_query()` function and can be customized based on your specific requirements for relevance scoring.

## Best Practices

1. **Regular Testing**: Run tests after configuration changes
2. **Baseline Establishment**: Create baseline reports for comparison
3. **Performance Monitoring**: Track response times over time
4. **Quality Validation**: Review low-scoring queries manually
5. **Documentation**: Keep test queries aligned with actual use cases