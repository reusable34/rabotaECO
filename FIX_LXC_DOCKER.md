# 🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С DOCKER В LXC

## Проблема
```
error during container init: open sysctl net.ipv4.ip_unprivileged_port_start file: permission denied
```

## Решение

### Вариант 1: Настройка через Proxmox веб-интерфейс (РЕКОМЕНДУЕТСЯ)

1. Откройте Proxmox веб-интерфейс
2. Найдите контейнер 100 (kolas)
3. Перейдите в **Options** → **Features**
4. Включите следующие опции:
   - ✅ **nesting** - для работы Docker внутри LXC
   - ✅ **keyctl** - для управления ключами
   - ✅ **fuse** - для файловых систем
5. Нажмите **OK**
6. Перезапустите контейнер: **Actions** → **Reboot**

### Вариант 2: Настройка через командную строку Proxmox хоста

**Выполните на хосте Proxmox (НЕ в контейнере):**

```bash
pct set 100 -features nesting=1,keyctl=1,fuse=1
pct reboot 100
```

### Вариант 3: Настройка sysctl на хосте Proxmox

**Выполните на хосте Proxmox (НЕ в контейнере):**

```bash
# Включить не привилегированные порты для контейнера 100
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p

# Перезапустить контейнер
pct reboot 100
```

## После настройки

Вернитесь в контейнер и выполните:

```bash
cd /opt/eco-project && git pull && bash GIT_DEPLOY.sh
```

## Проверка

После настройки проверьте:

```bash
# В контейнере
cat /proc/self/status | grep CapEff
# Должно показать непустое значение

# Проверка Docker
docker info | grep -i "security"
```

