# 🔧 ИНСТРУКЦИЯ: НАСТРОЙКА DOCKER В LXC КОНТЕЙНЕРЕ 102

## ⚠️ ВАЖНО: Команды выполняются на ХОСТЕ Proxmox, НЕ в контейнере!

## Способ 1: Через веб-интерфейс Proxmox (РЕКОМЕНДУЕТСЯ)

1. **В веб-интерфейсе Proxmox:**
   - Выберите узел **"citadel"** (НЕ контейнер 102!)
   - Нажмите кнопку **">_ Shell"** вверху справа
   - Откроется терминал хоста Proxmox

2. **Выполните команды:**
```bash
pct set 102 -features nesting=1,keyctl=1,fuse=1
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p
pct reboot 102
```

3. **Подождите 30 секунд**, затем войдите в контейнер 102 и выполните:
```bash
cd /opt/eco-project && git pull && bash GIT_DEPLOY.sh
```

## Способ 2: Через SSH на хост Proxmox

Если у вас есть SSH доступ к хосту Proxmox:

```bash
ssh root@85.113.129.96  # или IP вашего Proxmox хоста
pct set 102 -features nesting=1,keyctl=1,fuse=1
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p
pct reboot 102
```

## Способ 3: Через веб-интерфейс (GUI)

1. В Proxmox веб-интерфейсе выберите контейнер **102 (kolas)**
2. Перейдите в **Options** → **Features**
3. Включите:
   - ✅ **nesting**
   - ✅ **keyctl**
   - ✅ **fuse**
4. Нажмите **OK**
5. Перезапустите контейнер: **Actions** → **Reboot**

## После настройки

Войдите в контейнер 102 и выполните:

```bash
cd /opt/eco-project
git pull
bash GIT_DEPLOY.sh
```

## Проверка

После деплоя проверьте:

```bash
docker ps
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:3001
```

