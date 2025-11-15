#!/bin/bash
# ==========================================
# ОСТАНОВКА КОНТЕЙНЕРОВ ЗАПУЩЕННЫХ ВРУЧНУЮ
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Остановка контейнеров...${NC}"

docker stop eco_db eco_backend eco_frontend eco_adminer 2>/dev/null || true
docker rm eco_db eco_backend eco_frontend eco_adminer 2>/dev/null || true

echo -e "${GREEN}✅ Контейнеры остановлены${NC}"

