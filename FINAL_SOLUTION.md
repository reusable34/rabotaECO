# 🔧 ФИНАЛЬНОЕ РЕШЕНИЕ ПРОБЛЕМЫ С DOCKER В LXC

## Проблема
```
Error response from daemon: failed to create task for container: 
failed to create shim task: OCI runtime create failed: runc create failed: 
unable to start container process: error during container init: 
open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied
```

## Причина
Docker пытается использовать sysctl, который недоступен в LXC контейнере без правильной настройки на хосте Proxmox.

## Решение

### ⚠️ ОБЯЗАТЕЛЬНО: Настройте контейнер на ХОСТЕ Proxmox

**Это НЕ обходимо!** Без этого Docker не будет работать.

#### Способ 1: Через веб-интерфейс Proxmox

1. В веб-интерфейсе Proxmox выберите узел **"citadel"** (НЕ контейнер 102!)
2. Нажмите кнопку **">_ Shell"** вверху справа
3. Выполните команды:

```bash
pct set 102 -features nesting=1,keyctl=1,fuse=1
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p
pct reboot 102
```

#### Способ 2: Через SSH на хост Proxmox

```bash
ssh root@85.113.129.96
pct set 102 -features nesting=1,keyctl=1,fuse=1
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p
pct reboot 102
```

#### Способ 3: Через веб-интерфейс (GUI)

1. Выберите контейнер **102 (kolas)**
2. Перейдите в **Options** → **Features**
3. Включите:
   - ✅ **nesting**
   - ✅ **keyctl**
   - ✅ **fuse**
4. Нажмите **OK**
5. Перезапустите: **Actions** → **Reboot**

### После настройки на хосте

Войдите в контейнер 102 и выполните:

```bash
cd /opt/eco-project
git pull
bash FIX_DOCKER_RUNTIME.sh
bash QUICK_FIX.sh
```

## Альтернативное решение (если настройка хоста невозможна)

Если по каким-то причинам нельзя настроить хост, можно попробовать использовать привилегированный контейнер:

**На хосте Proxmox:**
```bash
pct stop 102
pct set 102 -unprivileged 0
pct start 102
```

⚠️ **Внимание:** Привилегированные контейнеры менее безопасны!

## Проверка

После всех настроек проверьте:

```bash
# В контейнере 102
docker ps
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:3001
```

## Если ничего не помогает

Используйте версию БЕЗ Docker - она уже работает:

```bash
cd /opt/eco-project
bash FULL_DEPLOY_NO_DOCKER.sh
```

Это установит всё напрямую на систему без Docker.

