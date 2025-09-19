# Быстрый старт - Manticore Search AI Tester

## 🚀 Запуск за 3 минуты

### 1. Подготовка данных
```bash
# Поместите .md файлы в папку data/
ls data/  # Проверьте наличие файлов
```

### 2. Развертывание
```bash
./scripts/setup.sh      # Настройка Docker (1-2 мин)
./scripts/import_data.sh # Импорт данных (30 сек)
```

### 3. Тестирование
```bash
# Полный тест с 27 запросами
./scripts/run_tests.sh

# Или одиночный запрос
./scripts/search_nl.sh "Заменят ли роботы живых дилеров?"
```

## 📊 Ожидаемый результат

```
OVERALL PERFORMANCE:
  - Successful Queries: 27/27 (100.0%)  
  - Average Response Time: 90 ms
  - Average Results per Query: 24
  - Average Relevance Score: 90/100

SEARCH QUALITY ANALYSIS:
  - Excellent Results: 27
  - Good Results: 0
  - Fair Results: 0
  - Poor Results: 0
```

## 🎯 Примеры запросов

```bash
# Технические вопросы
./scripts/search_nl.sh "Есть ли доступ по FTP?"

# Бизнес-вопросы  
./scripts/search_nl.sh "Что случится после окончания подписки?"

# Функциональные вопросы
./scripts/search_nl.sh "Поддерживается ли мобильная версия?"
```

## 📁 Файлы результатов

- `output/test_summary_*.txt` - Сводный отчет
- `output/test_report_*.json` - Детальные метрики
- `logs/` - Логи выполнения

## ❗ Возможные проблемы

**Порт занят:**
```bash
docker stop $(docker ps -q --filter "name=manticore")
./scripts/setup.sh
```

**Docker не запущен:**
```bash
# macOS: Запустите Docker Desktop
# Linux: sudo systemctl start docker
```

**Нет результатов поиска:**
```bash
./scripts/health_check.sh  # Проверка системы
./scripts/import_data.sh   # Повторный импорт
```