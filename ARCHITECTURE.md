# Архитектура проекта

## Обзор системы

Проект представляет собой комплексную систему для сравнительного тестирования двух поисковых движков:

- **Manticore Search 13.11.0** - современный движок с AI и Auto Embeddings
- **Sphinx Search 2.2.7** - классический полнотекстовый поисковый движок

## Компоненты системы

### 1. Поисковые движки

#### Manticore Search
- **Порты**: 9306 (MySQL), 9308 (HTTP API)
- **Особенности**: Auto Embeddings, семантический поиск, AI-возможности
- **Конфигурация**: `configs/manticore.conf`
- **Индексы**: Хранятся в `output/`

#### Sphinx Search  
- **Порты**: 9304 (MySQL), 9312 (SphinxQL)
- **Особенности**: Классический полнотекстовый поиск, морфология
- **Конфигурация**: `configs/sphinx.conf`
- **Генератор данных**: `scripts/sphinx_data_generator.sh`

### 2. Веб-интерфейс

#### Frontend (index.html)
- Адаптивный интерфейс на чистом JavaScript
- Выбор поискового движка через dropdown
- Отображение результатов с метриками

#### Backend (server.js)
- Node.js сервер на Express
- API endpoints: `/search`, `/health`
- Проксирование запросов к поисковым движкам
- Унификация форматов ответов

### 3. Скрипты автоматизации

#### Основные скрипты
- `start_all.sh` - Запуск всех сервисов одной командой
- `setup.sh` - Настройка Manticore Search
- `start_sphinx.sh` - Запуск Sphinx Search
- `start_web_ui.sh` - Запуск веб-интерфейса

#### Поисковые скрипты
- `search_nl.sh` - Поиск через Manticore
- `sphinx_search.sh` - Поиск через Sphinx
- `run_tests.sh` - Автотесты (27 запросов)

#### Утилиты
- `health_check.sh` - Проверка состояния системы
- `import_data.sh` - Импорт данных в Manticore
- `view_logs.sh` - Просмотр логов

## Поток данных

### 1. Индексация данных

```
Markdown файлы (data/) 
    ↓
Manticore: Прямой импорт через HTTP API
    ↓
Sphinx: XML генерация → Индексация
    ↓
Готовые индексы в обоих движках
```

### 2. Поисковые запросы

```
Веб-интерфейс (http://localhost:3000)
    ↓
Node.js сервер (server.js)
    ↓
Выбор движка (engine parameter)
    ↓
Manticore: HTTP API (9308) | Sphinx: MySQL (9304)
    ↓
Унификация ответа в JSON
    ↓
Отображение результатов
```

## Структуры данных

### Формат документа в Manticore
```json
{
  "title": "Заголовок документа",
  "content": "Полное содержимое",
  "url": "https://example.com/page"
}
```

### Формат документа в Sphinx
```sql
CREATE TABLE documents (
  id BIGINT,
  title FIELD,           -- для поиска
  content FIELD,         -- для поиска  
  title_text STRING,     -- для отображения
  content_text STRING,   -- для отображения
  url STRING,
  created_at TIMESTAMP
);
```

### Унифицированный API ответ
```json
{
  "total": 10,
  "took": 25,
  "max_score": 0.95,
  "hits": [
    {
      "_id": "123",
      "_score": 0.95,
      "_source": {
        "title": "Заголовок",
        "url": "https://example.com",
        "content": "Содержимое..."
      }
    }
  ]
}
```

## Конфигурация портов

| Сервис | Порт | Протокол | Назначение |
|--------|------|----------|------------|
| Manticore HTTP | 9308 | HTTP | API запросы |
| Manticore MySQL | 9306 | MySQL | SQL запросы |
| Sphinx MySQL | 9304 | MySQL | SQL запросы |
| Sphinx SphinxQL | 9312 | SphinxQL | Нативные запросы |
| Web UI | 3000 | HTTP | Веб-интерфейс |

## Docker контейнеры

### Manticore Search
```bash
manticoresearch/manticore:6.3.6
# Volumes: configs/, data/, output/
# Ports: 9306:9306, 9308:9308
```

### Sphinx Search  
```bash
sphinxsearch:2.2.7
# Volumes: configs/, data/, output/, logs/
# Ports: 9304:9306, 9312:9312
```

## Логирование

### Структура логов
- `logs/web_ui_YYYY-MM-DD.log` - Логи веб-сервера
- `logs/searchd.log` - Логи Sphinx
- `output/searchd.log` - Логи Manticore
- Console output - Все скрипты

### Уровни логирования
- **INFO** - Общая информация
- **DEBUG** - Отладочная информация  
- **WARN** - Предупреждения
- **ERROR** - Ошибки

## Масштабирование

### Горизонтальное масштабирование
- Несколько экземпляров веб-сервера за load balancer
- Реплики поисковых движков для распределения нагрузки
- Кэширование результатов поиска

### Вертикальное масштабирование
- Увеличение ресурсов Docker контейнеров
- Оптимизация конфигураций поисковых движков
- SSD диски для индексов

## Мониторинг

### Метрики производительности
- Время ответа (response time)
- Количество результатов (total results)
- Релевантность (max score)
- Пропускная способность (requests/sec)

### Health checks
- Доступность HTTP API
- Состояние индексов
- Использование ресурсов
- Статус Docker контейнеров

## Безопасность

### Сетевая безопасность
- Все сервисы доступны только на localhost
- Нет внешних подключений к базам данных
- Веб-интерфейс без аутентификации (для тестирования)

### Данные
- Нет персональных данных в тестовых файлах
- Логи не содержат чувствительной информации
- Временные файлы очищаются автоматически