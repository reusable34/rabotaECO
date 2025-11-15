# Настройка Nginx Proxy Manager для Frontend и Backend

## Вариант 1: Один Proxy Host (РЕКОМЕНДУЕТСЯ)

Создайте **один** Proxy Host в Nginx Proxy Manager:

### Основные настройки:
- **Domain Names**: `eco.local` (или ваш домен)
- **Scheme**: `http`
- **Forward Hostname/IP**: `192.168.0.32` (IP вашего LXC контейнера)
- **Forward Port**: `3384` (порт frontend)
- **Block Common Exploits**: ✅ Включено
- **Websockets Support**: ✅ Включено

### Advanced (Custom Nginx Configuration):
```nginx
location / {
    proxy_pass http://192.168.0.32:3384;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /api {
    proxy_pass http://192.168.0.32:8080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Вариант 2: Два отдельных Proxy Host

### Frontend:
- **Domain Names**: `eco.local`
- **Forward Hostname/IP**: `192.168.0.32`
- **Forward Port**: `3384`

### Backend:
- **Domain Names**: `api.eco.local` (поддомен)
- **Forward Hostname/IP**: `192.168.0.32`
- **Forward Port**: `8080`

Тогда в frontend `.env.local`:
```
NEXT_PUBLIC_API_URL=http://api.eco.local
```

## После настройки Nginx Proxy Manager:

1. Выполните на сервере:
```bash
cd /opt/eco-project
git stash
git pull
bash SETUP_PROPER_API_URL.sh
```

2. Скрипт настроит frontend на использование `/api` (относительный путь)

3. Проверьте доступность:
   - Frontend: `http://ваш-домен/` или `http://85.113.129.96:3384`
   - Backend API: `http://ваш-домен/api/health` или `http://85.113.129.96:8080/health`

## Важно:

- Backend **НЕ НУЖНО** пробрасывать наружу отдельно
- Все запросы идут через Nginx Proxy Manager
- Frontend обращается к API через тот же домен (`/api`)

