# 🚀 ДЕПЛОЙ ЧЕРЕЗ GIT

## Вариант 1: GitHub (рекомендуется)

### На вашем Mac:
1. Создайте репозиторий на GitHub: https://github.com/new
2. Выполните:
```bash
git remote add origin https://github.com/YOUR_USERNAME/rabotaECO.git
git branch -M main
git push -u origin main
```

### На сервере (одна команда):
```bash
cd /opt && git clone https://github.com/YOUR_USERNAME/rabotaECO.git eco-project && cd eco-project && bash GIT_DEPLOY.sh
```

---

## Вариант 2: Git Bundle (без GitHub)

### На вашем Mac:
Bundle уже создан: `eco-project.bundle` (2.5MB)

Загрузите его на сервер через Proxmox веб-интерфейс в `/opt/`

### На сервере (одна команда):
```bash
cd /opt && git clone eco-project.bundle eco-project && cd eco-project && bash GIT_DEPLOY.sh
```

---

## Что делает GIT_DEPLOY.sh:
1. ✅ Устанавливает Docker и Docker Compose
2. ✅ Клонирует/обновляет проект из Git
3. ✅ Настраивает переменные окружения
4. ✅ Запускает контейнеры
5. ✅ Выполняет миграции
6. ✅ Заполняет тестовыми данными

**Готово!** Сайт будет доступен на `http://IP:3001`

