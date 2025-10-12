#!/bin/bash

# Имя выходного файла
OUTPUT_FILE="repository_listing_bundle.md"

# Очистить файл, если он уже существует
> "$OUTPUT_FILE"

echo "Собираю файлы в $OUTPUT_FILE..."

# Найти все файлы, исключая директорию .git, сам скрипт и выходной файл
find . -type f -not -path "./.git/*" -not -name "$OUTPUT_FILE" -not -name "$(basename "$0")" | while read -r file; do
  echo "Добавляю файл: $file"
  
  # Добавить разделитель и заголовок с именем файла в markdown
  echo "---" >> "$OUTPUT_FILE"
  echo "### \`$file\`" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Добавить содержимое файла в блок кода
  echo "\`\`\`" >> "$OUTPUT_FILE"
  cat "$file" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE" # Добавляем пустую строку для лучшего форматирования
  echo "\`\`\`" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
done

echo "Готово! Все файлы собраны в $OUTPUT_FILE"
