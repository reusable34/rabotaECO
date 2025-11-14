#!/bin/bash
set -e

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVER_IP="192.168.0.30"
SERVER_USER="root"
PROJECT_DIR="/opt/eco-project"
LOCAL_PROJECT_PATH="/Users/komp/Documents/PROGRAMIROVANIE/rabotaECO"

echo -e "${BLUE}=========================================="
echo "АВТОМАТИЧЕСКИЙ ДЕПЛОЙ ПРОЕКТА"
echo "==========================================${NC}"
echo ""

# Проверка SSH доступа
echo -e "${YELLOW}1. Проверка подключения к серверу...${NC}"
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "echo 'OK'" &>/dev/null; then
    echo -e "${RED}Ошибка: Не могу подключиться к серверу${NC}"
    echo "Проверьте:"
    echo "  - SSH доступ: ssh ${SERVER_USER}@${SERVER_IP}"
    echo "  - IP адрес сервера"
    exit 1
fi
echo -e "${GREEN}✓ Подключение установлено${NC}"

# Загрузка проекта
echo ""
echo -e "${YELLOW}2. Загрузка проекта на сервер...${NC}"
rsync -avz --progress --exclude 'node_modules' --exclude '.next' --exclude 'vendor' --exclude '.git' \
    "${LOCAL_PROJECT_PATH}/" ${SERVER_USER}@${SERVER_IP}:${PROJECT_DIR}/

echo -e "${GREEN}✓ Проект загружен${NC}"

# Загрузка скрипта деплоя на сервер
echo ""
echo -e "${YELLOW}3. Загрузка скрипта деплоя на сервер...${NC}"
scp "${LOCAL_PROJECT_PATH}/one_command_deploy.sh" ${SERVER_USER}@${SERVER_IP}:/tmp/deploy.sh
scp -r "${LOCAL_PROJECT_PATH}" ${SERVER_USER}@${SERVER_IP}:/opt/eco-project

# Выполнение деплоя на сервере
echo ""
echo -e "${YELLOW}4. Выполнение деплоя на сервере...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
set -e

bash /tmp/deploy.sh
ENDSSH

echo ""
echo -e "${GREEN}=========================================="
echo "ДЕПЛОЙ УСПЕШНО ЗАВЕРШЕН!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Доступ к сайту:${NC}"
echo "  Frontend:  http://${SERVER_IP}:3001"
echo "  Backend:   http://${SERVER_IP}:8080"
echo "  Adminer:   http://${SERVER_IP}:8082"
echo ""
echo -e "${YELLOW}Для доступа из интернета:${NC}"
echo "  1. Настройте проброс портов в Proxmox (3001, 8080, 8082)"
echo "  2. Или используйте внешний IP вашего сервера"
echo ""

