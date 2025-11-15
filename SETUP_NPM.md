# 🌐 НАСТРОЙКА NGINX PROXY MANAGER ДЛЯ КОНТЕЙНЕРА 102

## Информация
- **Контейнер 102 (kolas) IP:** `192.168.0.32`
- **Nginx Proxy Manager:** http://85.113.129.96:81/nginx/proxy
- **Логин:** akakkiy.lalkin@mail.ru
- **Пароль:** 37983798

## Порты в контейнере 102:
- **Backend:** `8080` → `http://192.168.0.32:8080`
- **Frontend:** `3001` → `http://192.168.0.32:3001`

## Настройка в Nginx Proxy Manager

### 1. Откройте Nginx Proxy Manager
```
http://85.113.129.96:81/nginx/proxy
```

### 2. Создайте Proxy Host для Backend API

1. Нажмите **"Add Proxy Host"**
2. **Details:**
   - **Domain Names:** `api.eco.local` (или любой домен)
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `192.168.0.32`
   - **Forward Port:** `8080`
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support** (если нужно)
3. **SSL:**
   - Пока можно оставить без SSL (или настроить позже)
4. Нажмите **"Save"**

### 3. Создайте Proxy Host для Frontend

1. Нажмите **"Add Proxy Host"**
2. **Details:**
   - **Domain Names:** `eco.local` (или `www.eco.local`)
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `192.168.0.32`
   - **Forward Port:** `3001`
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support**
3. **SSL:**
   - Пока можно оставить без SSL
4. Нажмите **"Save"**

### 4. Альтернатива: Проброс через IP и порт

Если не хотите использовать домены, можно пробросить напрямую:

**Для Backend:**
- **Domain Names:** `85.113.129.96` (или оставить пустым)
- **Forward Port:** `8080`

**Для Frontend:**
- **Domain Names:** `85.113.129.96` (или оставить пустым)  
- **Forward Port:** `3001`

## Проверка

После настройки проверьте:

```bash
# В контейнере 102
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:3001
```

## Доступ из интернета

После настройки NPM:
- **Backend:** http://85.113.129.96:8080 (или через домен)
- **Frontend:** http://85.113.129.96:3001 (или через домен)

## Важно

Убедитесь, что в контейнере 102 Docker контейнеры запущены:

```bash
# В контейнере 102
cd /opt/eco-project
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml up -d
```

