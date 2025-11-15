# Настройка через Nginx Proxy Manager

Если вы хотите использовать Nginx Proxy Manager вместо локального Nginx:

## Доступ к Nginx Proxy Manager:
- URL: `http://85.113.129.96:81`
- Email: `akakkiy.lalkin@mail.ru`
- Password: `37983798`

## Настройка Proxy Host:

### 1. Создайте Proxy Host для Frontend и Backend:

**Основные настройки:**
- **Domain Names**: `eco.local` (или ваш домен, можно оставить пустым)
- **Scheme**: `http`
- **Forward Hostname/IP**: `192.168.0.32` (IP вашего LXC контейнера)
- **Forward Port**: `3384` (порт, где работает ваш локальный Nginx)
- **Block Common Exploits**: ✅ Включено
- **Websockets Support**: ✅ Включено

### 2. Advanced (Custom Nginx Configuration):

Если нужно настроить отдельные пути, добавьте в **Custom Nginx Configuration**:

```nginx
# Frontend
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

# Backend API
location /api {
    proxy_pass http://192.168.0.32:3384/api;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### 3. Или используйте два отдельных Proxy Host:

**Frontend:**
- Domain: `eco.local`
- Forward to: `192.168.0.32:3384`

**Backend:**
- Domain: `api.eco.local` (поддомен)
- Forward to: `192.168.0.32:3384/api`

Тогда в frontend `.env.local`:
```
NEXT_PUBLIC_API_URL=http://api.eco.local
```

## Важно:

После настройки Nginx Proxy Manager, убедитесь что:
1. Локальный Nginx на порту 3384 работает и правильно проксирует
2. Frontend `.env.local` настроен на правильный API URL
3. Порты проброшены в роутере (если нужно)

