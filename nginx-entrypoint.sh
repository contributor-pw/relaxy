#!/bin/sh
set -e

# Проверяем наличие необходимых переменных
if [ -z "$ROOT_DOMAIN" ] || [ -z "$SUBDOMAINS" ] || [ -z "$CERT_NAME" ]; then
  echo "Ошибка: Переменные ROOT_DOMAIN, SUBDOMAINS и CERT_NAME должны быть установлены."
  exit 1
fi

CONF_FILE="/etc/nginx/conf.d/default.conf"
echo "Генерирую конфигурацию Nginx в $CONF_FILE..."

# Превращаем "sub1,sub2" в "sub1.domain sub2.domain"
server_names=$(echo $SUBDOMAINS | sed "s/,/.$ROOT_DOMAIN /g" | sed "s/$/.$ROOT_DOMAIN/")

# --- Блок для HTTP -> HTTPS редиректа и Certbot ---
echo "server {" > $CONF_FILE
echo "    listen 80;" >> $CONF_FILE
echo "    server_name $server_names;" >> $CONF_FILE
echo "" >> $CONF_FILE
echo "    location /.well-known/acme-challenge/ {" >> $CONF_FILE
echo "        root /var/www/certbot;" >> $CONF_FILE
echo "    }" >> $CONF_FILE
echo "" >> $CONF_FILE
echo "    location / {" >> $CONF_FILE
echo "        return 301 https://\$host\$request_uri;" >> $CONF_FILE
echo "    }" >> $CONF_FILE
echo "}" >> $CONF_FILE

# --- HTTPS server блоки для каждого субдомена ---
OLD_IFS=$IFS
IFS=','
for subdomain in $SUBDOMAINS; do
  full_domain="$subdomain.$ROOT_DOMAIN"
  # Соглашение: имя сервиса в docker-compose совпадает с субдоменом
  backend_service_name=$subdomain

  echo "" >> $CONF_FILE
  echo "server {" >> $CONF_FILE
  echo "    listen 443 ssl;" >> $CONF_FILE
  echo "    server_name $full_domain;" >> $CONF_FILE
  echo "" >> $CONF_FILE
  echo "    # Используем один и тот же сертификат для всех" >> $CONF_FILE
  echo "    ssl_certificate /etc/letsencrypt/live/$CERT_NAME/fullchain.pem;" >> $CONF_FILE
  echo "    ssl_certificate_key /etc/letsencrypt/live/$CERT_NAME/privkey.pem;" >> $CONF_FILE
  echo "    include /etc/letsencrypt/options-ssl-nginx.conf;" >> $CONF_FILE
  echo "    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;" >> $CONF_FILE
  echo "" >> $CONF_FILE
  echo "    location / {" >> $CONF_FILE
  # Проксируем на сервис с таким же именем, как у субдомена.
  # Предполагаем, что сервис слушает порт 80.
  echo "        proxy_pass http://$backend_service_name:80;" >> $CONF_FILE
  echo "        proxy_set_header Host \$host;" >> $CONF_FILE
  echo "        proxy_set_header X-Real-IP \$remote_addr;" >> $CONF_FILE
  echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> $CONF_FILE
  echo "        proxy_set_header X-Forwarded-Proto \$scheme;" >> $CONF_FILE
  echo "    }" >> $CONF_FILE
  echo "}" >> $CONF_FILE
done
IFS=$OLD_IFS

echo "Конфигурация сгенерирована:"
cat $CONF_FILE

echo "Запускаю Nginx..."
exec nginx -g 'daemon off;'
