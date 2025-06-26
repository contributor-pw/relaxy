# File Listings

## .github/workflows/deploy.yml

```yaml
name: Deploy on Push

on:
  push:
    branches:
      - master # Or your default branch, e.g., master

jobs:
  deploy:
    name: Deploy to server
    runs-on: self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          clean: false

      - name: Deploy services
        env:
          DOMAIN: ${{ secrets.DOMAIN }}
          EMAIL: ${{ secrets.EMAIL }}
        run: |
          # Navigate to your project directory on the server
          cd ${{ github.workspace }}

          # Rebuild and restart your services with Docker Compose
          # Environment variables are passed from the 'env' context above
          # We explicitly specify `nginx` to ensure only the proxy server is started on deploy.
          sudo -E docker compose -f docker-compose.yml up -d --build --force-recreate --remove-orphans nginx
```

## docker-compose.yml

```dockercompose
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - DOMAIN
    volumes:
      - ./nginx.conf.template:/etc/nginx/templates/default.conf.template
      - ./data/certbot/conf:/etc/letsencrypt
      - ./data/certbot/www:/var/www/certbot
    command: /bin/sh -c "envsubst '$DOMAIN' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
    networks:
      - net

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./data/certbot/conf:/etc/letsencrypt
      - ./data/certbot/www:/var/www/certbot
    networks:
      - net

networks:
  net:
    external: true
```

## nginx.conf.template

```properties
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location /vk-api-service/ {
        proxy_pass http://vk-api-service:3057/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        return 200 'OK';
    }
}
```
