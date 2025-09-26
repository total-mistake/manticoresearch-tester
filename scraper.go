package main

import (
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

type URLSet struct {
	XMLName xml.Name `xml:"urlset"`
	URLs    []URL    `xml:"url"`
}

type URL struct {
	Loc string `xml:"loc"`
}

func main() {
	// Параметры конфигурации
	maxPages := 0                                             // Максимальное количество страниц для скачивания (0 = без ограничений)
	requestDelay := 1 * time.Second                           // Задержка между запросами
	targetPrefix := "https://nethouse.ru/about/instructions/" // Фильтр URL

	if len(os.Args) < 2 {
		fmt.Println("Usage: go run scraper.go <sitemap_url>")
		os.Exit(1)
	}

	sitemapURL := os.Args[1]

	// Создаем папку data если не существует
	outputDir := "data"
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		log.Fatal("Ошибка создания директории:", err)
	}

	// Получаем все URL из sitemap.xml
	urls, err := getSitemapURLs(sitemapURL)
	if err != nil {
		log.Fatal("Ошибка получения sitemap:", err)
	}

	// Фильтруем URL, которые начинаются с нужного префикса
	var filteredURLs []string
	for _, url := range urls {
		if strings.HasPrefix(url, targetPrefix) {
			filteredURLs = append(filteredURLs, url)
		}
	}

	fmt.Printf("Найдено %d страниц для скачивания (ограничение: %d)\n", len(filteredURLs), maxPages)

	// Применяем ограничение на количество страниц
	if maxPages > 0 && len(filteredURLs) > maxPages {
		filteredURLs = filteredURLs[:maxPages]
	}

	// Обрабатываем каждый URL
	for i, url := range filteredURLs {
		fmt.Printf("Processing %d/%d: %s\n", i+1, len(filteredURLs), url)

		if err := processURL(url); err != nil {
			fmt.Printf("Error processing %s: %v\n", url, err)
			continue
		}

		// Задержка между запросами
		time.Sleep(requestDelay)
	}

	fmt.Println("Scraping completed!")
}

func getSitemapURLs(sitemapURL string) ([]string, error) {
	resp, err := http.Get(sitemapURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var urlset URLSet
	if err := xml.Unmarshal(body, &urlset); err != nil {
		return nil, err
	}

	var urls []string
	for _, url := range urlset.URLs {
		urls = append(urls, url.Loc)
	}

	return urls, nil
}

func processURL(url string) error {
	// Загружаем страницу
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Парсим HTML
	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return err
	}

	// Извлекаем данные с HTML тегами
	titleHtml, _ := doc.Find("article.help-article__body h1.help-article__title").Html()
	title := strings.TrimSpace(titleHtml)
	if title == "" {
		return fmt.Errorf("title not found")
	}

	articleBodyHtml, _ := doc.Find("article.help-article__body div.help-article__main").Html()
	articleBody := strings.TrimSpace(articleBodyHtml)
	if articleBody == "" {
		return fmt.Errorf("article body not found")
	}

	// Создаем имя файла из URL
	filename := createFilename(url)

	// Формируем содержимое MD файла
	content := fmt.Sprintf("# %s\n\n**URL:** %s\n\n%s", title, url, strings.TrimSpace(articleBody))

	// Сохраняем файл
	filepath := filepath.Join("data", filename+".md")
	return os.WriteFile(filepath, []byte(content), 0644)
}

func createFilename(url string) string {
	// Извлекаем последнюю часть URL
	parts := strings.Split(url, "/")
	filename := parts[len(parts)-1]

	// Убираем недопустимые символы
	reg := regexp.MustCompile(`[^a-zA-Z0-9_-]`)
	filename = reg.ReplaceAllString(filename, "_")

	// Убираем множественные подчеркивания
	reg = regexp.MustCompile(`_+`)
	filename = reg.ReplaceAllString(filename, "_")

	// Убираем подчеркивания в начале и конце
	filename = strings.Trim(filename, "_")

	if filename == "" {
		filename = "page"
	}

	return filename
}
