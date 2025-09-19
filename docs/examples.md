# Примеры использования Manticore Search AI Tester

## 🎯 Примеры естественных запросов

### Базовые поисковые запросы

```bash
# Поиск информации о технологиях
./scripts/search_nl.sh "Заменят ли роботы живых дилеров в казино?"

# Вопросы о функциональности
./scripts/search_nl.sh "Поддерживается ли мобильная версия сайта?"

# Технические вопросы
./scripts/search_nl.sh "Есть ли доступ по FTP?"
```

### Альтернативные формулировки

```bash
# Разные способы спросить об одном и том же
./scripts/search_nl.sh "Есть ли пробный период?"
./scripts/search_nl.sh "Можно ли получить пробную версию?"

# Синонимы и вариации
./scripts/search_nl.sh "Как защищены личные данные?"
./scripts/search_nl.sh "Безопасность и конфиденциальность"
```

### Запросы с параметрами

```bash
# Ограничение количества результатов
./scripts/search_nl.sh --limit 3 "Что такое система баллов?"

# JSON-вывод для программной обработки
./scripts/search_nl.sh --json "Какие цели у проекта?" | jq '.hits.total'

# Подробный режим с отладочной информацией
./scripts/search_nl.sh --verbose "Как продвигать контент?"
```

## 📊 Интерпретация результатов

### Пример вывода поиска

```
=== Natural Language Search Results ===
Query: "Заменят ли роботы живых дилеров в казино?"
Total Results: 54
Execution Time: 0s
Search Time: 1ms

--- Result 1 ---
ID: 6848853769505996801
Relevance Score: 4576
Title: Автоматизация в онлайн казино: заменят ли алгоритмы живых крупье?
URL: https://nethouse.ru/about/instructions/avtomatizatsiya_v_onlayn_kazino
Content: В последние годы технологии радикально изменили индустрию онлайн-гемблинга...
```

### Показатели качества

- **Relevance Score 4576** - Очень высокая релевантность
- **Total Results 54** - Много потенциально релевантных документов
- **Search Time 1ms** - Быстрый поиск

## 🧪 Тестовые сценарии

### Полное тестирование качества

```bash
# Запуск всех 27 тестовых запросов
./scripts/run_tests.sh

# Анализ результатов
cat output/test_summary_$(date +%Y%m%d)*.txt
```

### Тестирование производительности

```bash
# Измерение времени выполнения запросов
time ./scripts/search_nl.sh "Ваш запрос"

# Нагрузочное тестирование (10 запросов подряд)
for i in {1..10}; do
    ./scripts/search_nl.sh "Тестовый запрос $i"
done
```

### Тестирование различных языков запросов

```bash
# Русский (основной)
./scripts/search_nl.sh "Как работает система баллов?"

# Смешанный русский + английский
./scripts/search_nl.sh "Система баллов и bonuses"

# Техническая терминология
./scripts/search_nl.sh "FTP доступ к файлам"
```

## 📈 Анализ метрик качества

### Просмотр JSON-отчета

```bash
# Последний отчет
jq '.[0]' output/test_report_*.json

# Топ-5 запросов по релевантности
jq '.[] | select(.metrics.top_score > 3000) | .query' output/test_report_*.json

# Среднее время ответа
jq '[.[] | .metrics.response_time_ms] | add / length' output/test_report_*.json
```

### Фильтрация по качеству

```bash
# Только отличные результаты
jq '.[] | select(.metrics.result_quality == "excellent")' output/test_report_*.json

# Запросы с низкой производительностью  
jq '.[] | select(.metrics.response_time_ms > 100)' output/test_report_*.json
```

## 🔧 Кастомизация тестов

### Добавление собственных запросов

Отредактируйте `scripts/run_tests.sh`:

```bash
# В массив TEST_QUERIES добавьте:
"Ваш кастомный естественный запрос"

# В функцию get_expected_results() добавьте:
"Ваш кастомный естественный запрос") echo "1" ;;
```

### Настройка собственных данных

```bash
# 1. Добавьте .md файлы в папку data/
cp ваши_файлы.md data/

# 2. Переимпортируйте данные
./scripts/import_data.sh

# 3. Протестируйте новые запросы
./scripts/search_nl.sh "Запрос по вашим данным"
```

## 🐛 Диагностика проблем

### Отладка конкретного запроса

```bash
# Подробный режим для диагностики
./scripts/search_nl.sh --verbose --json "проблемный запрос" | jq '.'

# Проверка индекса
curl -s "http://localhost:9308/search" -d '{"index":"documents","query":{"match_all":{}},"limit":1}' | jq '.hits.total'
```

### Проверка состояния системы

```bash
# Полная диагностика
./scripts/health_check.sh

# Состояние Docker-контейнера
docker ps --filter "name=manticore"

# Логи контейнера
docker logs manticore-search-test --tail 50
```

## 💡 Полезные команды

### Экспорт результатов

```bash
# Создание CSV с результатами
jq -r '.[] | [.query, .metrics.total_results, .metrics.response_time_ms, .metrics.result_quality] | @csv' output/test_report_*.json > results.csv

# Создание markdown-отчета
echo "# Результаты тестирования" > report.md
echo "" >> report.md
jq -r '.[] | "- **\(.query)**: \(.metrics.total_results) результатов, \(.metrics.response_time_ms)ms"' output/test_report_*.json >> report.md
```

### Мониторинг в реальном времени

```bash
# Мониторинг логов поиска
tail -f logs/*.log

# Отслеживание производительности контейнера
docker stats manticore-search-test
```