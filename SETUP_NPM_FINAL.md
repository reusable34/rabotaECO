# 🌐 НАСТРОЙКА NGINX PROXY MANAGER ДЛЯ ДОСТУПА В ИНТЕРНЕТ

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

Войдите:
- **Логин:** `akakkiy.lalkin@mail.ru`
- **Пароль:** `37983798`

### 2. Создайте Proxy Host для Backend API

1. Нажмите **"Add Proxy Host"** (или **"Hosts"** → **"Proxy Hosts"** → **"Add Proxy Host"**)
2. **Details:**
   - **Domain Names:** `api.eco.local` (или любой домен, можно оставить пустым)
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `192.168.0.32`
   - **Forward Port:** `8080`
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support** (если нужно для API)
3. **SSL:**
   - Пока можно оставить без SSL (или настроить позже через Let's Encrypt)
4. Нажмите **"Save"**

### 3. Создайте Proxy Host для Frontend

1. Нажмите **"Add Proxy Host"**
2. **Details:**
   - **Domain Names:** `eco.local` (или `www.eco.local`, можно оставить пустым)
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `192.168.0.32`
   - **Forward Port:** `3001`
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support**
3. **SSL:**
   - Пока можно оставить без SSL
4. Нажмите **"Save"**

### 4. Альтернатива: Проброс через IP и порт

Если не хотите использовать домены, можно пробросить напрямую через IP:

**Для Backend:**
- **Domain Names:** оставьте пустым или укажите `85.113.129.96`
- **Forward Port:** `8080`

**Для Frontend:**
- **Domain Names:** оставьте пустым или укажите `85.113.129.96`
- **Forward Port:** `3001`

## Проверка

После настройки проверьте в контейнере 102:

```bash
# Проверка что сервисы работают
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:3001
```

## Доступ из интернета

После настройки NPM сайт будет доступен:

- **Backend API:** http://85.113.129.96:8080 (или через настроенный домен)
- **Frontend:** http://85.113.129.96:3001 (или через настроенный домен)

## Настройка роутера (если нужно)

Если нужно пробросить порты через роутер TP-Link:

1. Откройте настройки роутера: http://192.168.0.1
2. Перейдите в **Переадресация** → **Виртуальные серверы**
3. Добавьте правила:
   - **Порт сервиса:** 8080 → **IP-Адрес:** 192.168.0.32 → **Внутренний порт:** 8080 → **Протокол:** TCP
   - **Порт сервиса:** 3001 → **IP-Адрес:** 192.168.0.32 → **Внутренний порт:** 3001 → **Протокол:** TCP

## Важно

Убедитесь, что в контейнере 102 сервисы запущены:

```bash
# Проверка Nginx
systemctl status nginx

# Проверка PHP-FPM
systemctl status php8.2-fpm

# Проверка портов
ss -tulpn | grep -E "8080|3001"
```

Если сервисы не запущены, запустите:

```bash
systemctl start nginx
systemctl start php8.2-fpm
systemctl enable nginx
systemctl enable php8.2-fpm
```

