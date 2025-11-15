# 🔧 ФИНАЛЬНОЕ РЕШЕНИЕ ПРОБЛЕМЫ С DOCKER В LXC

## ❌ Проблема

```
Error response from daemon: failed to create task for container: 
failed to create shim task: OCI runtime create failed: runc create failed: 
unable to start container process: error during container init: 
open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied
```

**Это происходит даже при `docker run`**, потому что Docker runtime (runc) пытается использовать sysctl при создании ЛЮБОГО контейнера в LXC.

## ✅ Решение: Настроить контейнер на ХОСТЕ Proxmox

**Это ОБЯЗАТЕЛЬНО!** Без этого Docker не будет работать в LXC контейнере.

### Способ 1: Через веб-интерфейс Proxmox

1. В веб-интерфейсе Proxmox выберите узел **"citadel"** (НЕ контейнер 102!)
2. Нажмите кнопку **">_ Shell"** вверху справа
3. Выполните команды:

```bash
pct set 102 -features nesting=1,keyctl=1,fuse=1
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p
pct reboot 102
```

### Способ 2: Через SSH на хост Proxmox

```bash
ssh root@85.113.129.96
pct set 102 -features nesting=1,keyctl=1,fuse=1
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p
pct reboot 102
```

### Способ 3: Через веб-интерфейс (GUI)

1. Выберите контейнер **102 (kolas)**
2. Перейдите в **Options** → **Features**
3. Включите:
   - ✅ **nesting**
   - ✅ **keyctl**
   - ✅ **fuse**
4. Нажмите **OK**
5. Перезапустите: **Actions** → **Reboot**

## После настройки

Войдите в контейнер 102 и выполните:

```bash
cd /opt/eco-project
git pull
bash RUN_MANUAL.sh
```

## 🔄 Альтернатива: Версия БЕЗ Docker

Если настройка хоста невозможна, используйте версию БЕЗ Docker (уже работает на сервере):

```bash
cd /opt/eco-project
bash FULL_DEPLOY_NO_DOCKER.sh
```

Это установит всё напрямую на систему:
- PostgreSQL напрямую
- PHP-FPM + Nginx
- Node.js для frontend
- Без Docker

## Почему это происходит?

LXC контейнеры изолированы от хоста. Docker пытается использовать sysctl для настройки сети, но в LXC это требует специальных разрешений, которые настраиваются на хосте Proxmox.

## Проверка

После настройки проверьте:

```bash
# В контейнере 102
docker run --rm hello-world
```

Если это работает, значит Docker настроен правильно.

