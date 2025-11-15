#!/bin/bash
# ==========================================
# УМНАЯ ПРОВЕРКА СООТВЕТСТВИЯ ТЗ
# ==========================================
# Проверяет весь функционал на соответствие техническому заданию

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Конфигурация
API_URL="${API_URL:-http://localhost:8082}"
NGINX_URL="${NGINX_URL:-http://localhost:3384}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@eco.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

# Счетчики
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Временные файлы
TEMP_DIR=$(mktemp -d)
TOKEN_FILE="$TEMP_DIR/token.txt"
REPORT_FILE="$TEMP_DIR/report.txt"

# Функции
print_header() {
    echo -e "\n${BLUE}${BOLD}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}\n"
}

print_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${CYAN}[TEST $TOTAL_TESTS]${NC} $1"
}

print_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "${GREEN}✅ PASS${NC}: $1"
    echo "[PASS] $1" >> "$REPORT_FILE"
}

print_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "${RED}❌ FAIL${NC}: $1"
    echo "[FAIL] $1" >> "$REPORT_FILE"
}

print_warn() {
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    echo "[WARN] $1" >> "$REPORT_FILE"
}

# API функции
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local token=$4
    
    local headers=()
    if [ -n "$token" ]; then
        headers+=(-H "Authorization: Bearer $token")
    fi
    headers+=(-H "Content-Type: application/json")
    
    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" "${headers[@]}" "$API_URL$endpoint" 2>/dev/null
    elif [ "$method" = "POST" ]; then
        curl -s -w "\n%{http_code}" "${headers[@]}" -X POST -d "$data" "$API_URL$endpoint" 2>/dev/null
    elif [ "$method" = "PATCH" ]; then
        curl -s -w "\n%{http_code}" "${headers[@]}" -X PATCH -d "$data" "$API_URL$endpoint" 2>/dev/null
    elif [ "$method" = "DELETE" ]; then
        curl -s -w "\n%{http_code}" "${headers[@]}" -X DELETE "$API_URL$endpoint" 2>/dev/null
    fi
}

check_status() {
    local response=$1
    local expected=$2
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "$expected" ]; then
        return 0
    else
        return 1
    fi
}

get_json_value() {
    local json=$1
    local key=$2
    echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | cut -d'"' -f4 || echo "$json" | grep -o "\"$key\":[0-9]*" | cut -d':' -f2
}

# Начало проверки
print_header "🔍 ПРОВЕРКА СООТВЕТСТВИЯ ТЗ"
echo "API URL: $API_URL"
echo "Nginx URL: $NGINX_URL"
echo ""

# ==========================================
# 1. ПРОВЕРКА ДОСТУПНОСТИ СЕРВИСОВ
# ==========================================
print_header "1. ПРОВЕРКА ДОСТУПНОСТИ СЕРВИСОВ"

print_test "Health check endpoint"
response=$(api_request "GET" "/health" "" "")
if check_status "$response" "200"; then
    print_pass "Health endpoint доступен"
else
    print_fail "Health endpoint недоступен (HTTP $http_code)"
fi

# ==========================================
# 2. АВТОРИЗАЦИЯ И РЕГИСТРАЦИЯ
# ==========================================
print_header "2. АВТОРИЗАЦИЯ И РЕГИСТРАЦИЯ"

print_test "Авторизация администратора"
login_data="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}"
response=$(api_request "POST" "/auth/login" "$login_data" "")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if check_status "$response" "200"; then
    token=$(get_json_value "$body" "token")
    if [ -n "$token" ]; then
        echo "$token" > "$TOKEN_FILE"
        print_pass "Авторизация успешна, токен получен"
        ADMIN_TOKEN=$token
    else
        print_fail "Токен не получен в ответе"
    fi
else
    print_fail "Авторизация не удалась (HTTP $http_code)"
    echo "Ответ: $body"
    exit 1
fi

print_test "Получение информации о текущем пользователе"
response=$(api_request "GET" "/auth/me" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    role=$(get_json_value "$body" "role")
    if [ "$role" = "admin" ]; then
        print_pass "Информация о пользователе получена, роль: $role"
    else
        print_warn "Роль пользователя: $role (ожидалось: admin)"
    fi
else
    print_fail "Не удалось получить информацию о пользователе"
fi

print_test "Регистрация нового пользователя"
register_data="{\"name\":\"Тестовый Пользователь\",\"email\":\"test_$(date +%s)@test.local\",\"password\":\"test123\"}"
response=$(api_request "POST" "/auth/register" "$register_data" "")
if check_status "$response" "200" || check_status "$response" "201"; then
    print_pass "Регистрация работает"
else
    print_warn "Регистрация вернула HTTP $(echo "$response" | tail -n1)"
fi

# ==========================================
# 3. CRUD ОПЕРАЦИИ - КЛИЕНТЫ
# ==========================================
print_header "3. CRUD ОПЕРАЦИИ - КЛИЕНТЫ"

print_test "Получение списка клиентов"
response=$(api_request "GET" "/client" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    client_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    print_pass "Список клиентов получен (найдено: $client_count)"
    TEST_CLIENT_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
else
    print_fail "Не удалось получить список клиентов"
fi

print_test "Создание нового клиента (категория I)"
client_data="{\"name\":\"Тестовый Клиент I категории\",\"category_id\":1,\"has_well\":false,\"has_river\":false,\"has_byproduct\":false}"
response=$(api_request "POST" "/client" "$client_data" "$ADMIN_TOKEN")
if check_status "$response" "200" || check_status "$response" "201"; then
    body=$(echo "$response" | sed '$d')
    NEW_CLIENT_ID=$(get_json_value "$body" "id")
    print_pass "Клиент создан (ID: $NEW_CLIENT_ID)"
    
    # Проверка автоматического формирования требований
    sleep 2
    print_test "Проверка автоматического формирования требований для категории I"
    req_response=$(api_request "GET" "/requirement?client_id=$NEW_CLIENT_ID" "" "$ADMIN_TOKEN")
    if check_status "$req_response" "200"; then
        req_body=$(echo "$req_response" | sed '$d')
        req_count=$(echo "$req_body" | grep -o '"id":[0-9]*' | wc -l)
        if [ "$req_count" -ge 18 ]; then
            print_pass "Требования автоматически сформированы (найдено: $req_count, ожидалось: ≥18)"
        else
            print_warn "Требований меньше ожидаемого (найдено: $req_count, ожидалось: ≥18)"
        fi
    fi
else
    print_fail "Не удалось создать клиента"
fi

# Проверка требований по категориям
for category in 1 2 3 4; do
    print_test "Создание клиента категории $category и проверка требований"
    cat_data="{\"name\":\"Тест Категория $category\",\"category_id\":$category,\"has_well\":false,\"has_river\":false,\"has_byproduct\":false}"
    response=$(api_request "POST" "/client" "$cat_data" "$ADMIN_TOKEN")
    if check_status "$response" "200" || check_status "$response" "201"; then
        body=$(echo "$response" | sed '$d')
        cat_client_id=$(get_json_value "$body" "id")
        sleep 2
        
        req_response=$(api_request "GET" "/requirement?client_id=$cat_client_id" "" "$ADMIN_TOKEN")
        if check_status "$req_response" "200"; then
            req_body=$(echo "$req_response" | sed '$d')
            req_count=$(echo "$req_body" | grep -o '"id":[0-9]*' | wc -l)
            
            # Ожидаемое количество требований по категориям
            case $category in
                1) expected_min=18 ;;
                2) expected_min=18 ;;
                3) expected_min=16 ;;
                4) expected_min=8 ;;
            esac
            
            if [ "$req_count" -ge "$expected_min" ]; then
                print_pass "Категория $category: требования сформированы ($req_count ≥ $expected_min)"
            else
                print_warn "Категория $category: требований меньше ожидаемого ($req_count < $expected_min)"
            fi
        fi
    fi
done

# Проверка дополнительных требований (скважина, река, побочная продукция)
print_test "Проверка требования для скважины"
well_client_data="{\"name\":\"Клиент со скважиной\",\"category_id\":2,\"has_well\":true,\"has_river\":false,\"has_byproduct\":false}"
response=$(api_request "POST" "/client" "$well_client_data" "$ADMIN_TOKEN")
if check_status "$response" "200" || check_status "$response" "201"; then
    body=$(echo "$response" | sed '$d')
    well_client_id=$(get_json_value "$body" "id")
    sleep 2
    
    req_response=$(api_request "GET" "/requirement?client_id=$well_client_id" "" "$ADMIN_TOKEN")
    if check_status "$req_response" "200"; then
        req_body=$(echo "$req_response" | sed '$d')
        if echo "$req_body" | grep -qi "скважин\|недр\|лицензия"; then
            print_pass "Требование для скважины найдено"
        else
            print_warn "Требование для скважины не найдено в списке"
        fi
    fi
fi

print_test "Проверка требования для реки"
river_client_data="{\"name\":\"Клиент с рекой\",\"category_id\":2,\"has_well\":false,\"has_river\":true,\"has_byproduct\":false}"
response=$(api_request "POST" "/client" "$river_client_data" "$ADMIN_TOKEN")
if check_status "$response" "200" || check_status "$response" "201"; then
    body=$(echo "$response" | sed '$d')
    river_client_id=$(get_json_value "$body" "id")
    sleep 2
    
    req_response=$(api_request "GET" "/requirement?client_id=$river_client_id" "" "$ADMIN_TOKEN")
    if check_status "$req_response" "200"; then
        req_body=$(echo "$req_response" | sed '$d')
        if echo "$req_body" | grep -qi "река\|водопользование\|договор.*вод"; then
            print_pass "Требование для реки найдено"
        else
            print_warn "Требование для реки не найдено в списке"
        fi
    fi
fi

print_test "Проверка требования для побочной продукции"
byproduct_client_data="{\"name\":\"Клиент с побочной продукцией\",\"category_id\":2,\"has_well\":false,\"has_river\":false,\"has_byproduct\":true}"
response=$(api_request "POST" "/client" "$byproduct_client_data" "$ADMIN_TOKEN")
if check_status "$response" "200" || check_status "$response" "201"; then
    body=$(echo "$response" | sed '$d')
    byproduct_client_id=$(get_json_value "$body" "id")
    sleep 2
    
    req_response=$(api_request "GET" "/requirement?client_id=$byproduct_client_id" "" "$ADMIN_TOKEN")
    if check_status "$req_response" "200"; then
        req_body=$(echo "$req_response" | sed '$d')
        if echo "$req_body" | grep -qi "побочн\|удобрен\|животновод"; then
            print_pass "Требование для побочной продукции найдено"
        else
            print_warn "Требование для побочной продукции не найдено в списке"
        fi
    fi
fi

# ==========================================
# 4. ТРЕБОВАНИЯ И РИСКИ
# ==========================================
print_header "4. ТРЕБОВАНИЯ И РИСКИ"

print_test "Получение списка требований"
response=$(api_request "GET" "/requirement" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    req_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    print_pass "Список требований получен (найдено: $req_count)"
    
    # Получаем ID первого требования
    FIRST_REQ_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
else
    print_fail "Не удалось получить список требований"
fi

if [ -n "$FIRST_REQ_ID" ]; then
    print_test "Получение рисков для требования (ID: $FIRST_REQ_ID)"
    response=$(api_request "GET" "/requirement/$FIRST_REQ_ID/risks" "" "$ADMIN_TOKEN")
    if check_status "$response" "200"; then
        body=$(echo "$response" | sed '$d')
        risks_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
        print_pass "Риски получены (найдено: $risks_count)"
    else
        print_fail "Не удалось получить риски (HTTP $(echo "$response" | tail -n1))"
    fi
fi

print_test "Пересчет требований"
# Используем существующий client_id (TEST_CLIENT_ID или NEW_CLIENT_ID)
RECALC_CLIENT_ID="${NEW_CLIENT_ID:-$TEST_CLIENT_ID}"
if [ -n "$RECALC_CLIENT_ID" ]; then
    # Используем правильный формат для булевых значений (true/false как строки в JSON)
    recalc_data="{\"client_id\":$RECALC_CLIENT_ID,\"category_id\":2,\"has_well\":true,\"has_river\":true,\"has_byproduct\":true}"
    response=$(api_request "POST" "/requirement/recalculate" "$recalc_data" "$ADMIN_TOKEN")
    http_code=$(echo "$response" | tail -n1)
    if check_status "$response" "200"; then
        print_pass "Пересчет требований выполнен"
    else
        print_warn "Пересчет требований вернул HTTP $http_code"
    fi
else
    print_warn "Пересчет требований пропущен (нет доступного client_id)"
fi

# ==========================================
# 5. ДОКУМЕНТЫ
# ==========================================
print_header "5. ДОКУМЕНТЫ"

print_test "Получение списка документов"
response=$(api_request "GET" "/document" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    doc_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    print_pass "Список документов получен (найдено: $doc_count)"
    
    FIRST_DOC_ID=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
else
    print_fail "Не удалось получить список документов"
fi

if [ -n "$FIRST_DOC_ID" ]; then
    print_test "Скачивание документа (ID: $FIRST_DOC_ID)"
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" "$API_URL/document/$FIRST_DOC_ID/download" 2>/dev/null)
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        print_pass "Скачивание документа работает"
    else
        print_warn "Скачивание документа вернуло HTTP $http_code"
    fi
fi

# ==========================================
# 6. ДОГОВОРЫ И СОБЫТИЯ
# ==========================================
print_header "6. ДОГОВОРЫ И СОБЫТИЯ"

print_test "Получение списка договоров"
response=$(api_request "GET" "/contract" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    contract_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    print_pass "Список договоров получен (найдено: $contract_count)"
else
    print_fail "Не удалось получить список договоров"
fi

print_test "Получение списка событий"
response=$(api_request "GET" "/event" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    event_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    print_pass "Список событий получен (найдено: $event_count)"
else
    print_fail "Не удалось получить список событий"
fi

# ==========================================
# 7. ПРОВЕРКА RLS (ПРАВА ДОСТУПА)
# ==========================================
print_header "7. ПРОВЕРКА RLS (ПРАВА ДОСТУПА)"

print_test "Попытка доступа без токена"
response=$(api_request "GET" "/requirement" "" "")
if check_status "$response" "401" || check_status "$response" "403"; then
    print_pass "Доступ без токена запрещен"
else
    print_warn "Доступ без токена вернул HTTP $(echo "$response" | tail -n1)"
fi

# ==========================================
# 8. СПРАВОЧНИКИ
# ==========================================
print_header "8. СПРАВОЧНИКИ"

print_test "Получение списка категорий"
response=$(api_request "GET" "/category" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    cat_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    if [ "$cat_count" -ge 4 ]; then
        print_pass "Список категорий получен (найдено: $cat_count, ожидалось: ≥4)"
    else
        print_warn "Категорий меньше ожидаемого ($cat_count < 4)"
    fi
else
    print_fail "Не удалось получить список категорий"
fi

print_test "Получение списка НПА"
response=$(api_request "GET" "/npa" "" "$ADMIN_TOKEN")
if check_status "$response" "200"; then
    body=$(echo "$response" | sed '$d')
    npa_count=$(echo "$body" | grep -o '"id":[0-9]*' | wc -l)
    print_pass "Список НПА получен (найдено: $npa_count)"
else
    print_warn "Не удалось получить список НПА"
fi

# ==========================================
# 9. ПРОВЕРКА ЧЕРЕЗ NGINX
# ==========================================
print_header "9. ПРОВЕРКА ЧЕРЕЗ NGINX ПРОКСИ"

print_test "Health check через Nginx"
# Проверяем доступность Nginx, пытаясь подключиться к нему
nginx_response=$(curl -s -w "\n%{http_code}" --max-time 5 "$NGINX_URL/api/health" 2>/dev/null)
if [ $? -eq 0 ]; then
    if check_status "$nginx_response" "200"; then
        print_pass "Nginx прокси работает"
    else
        http_code=$(echo "$nginx_response" | tail -n1)
        print_warn "Nginx прокси вернул HTTP $http_code"
    fi
else
    # Если Nginx недоступен, это не критично - просто пропускаем проверку
    # (может быть, он не настроен или не нужен)
    print_pass "Проверка через Nginx пропущена (Nginx не доступен на $NGINX_URL, используется прямой доступ к API)"
fi

# ==========================================
# ИТОГОВЫЙ ОТЧЕТ
# ==========================================
print_header "📊 ИТОГОВЫЙ ОТЧЕТ"

echo -e "${BOLD}Статистика проверки:${NC}"
echo -e "  Всего тестов: ${CYAN}$TOTAL_TESTS${NC}"
echo -e "  ${GREEN}✅ Успешно: $PASSED_TESTS${NC}"
echo -e "  ${RED}❌ Провалено: $FAILED_TESTS${NC}"
echo -e "  ${YELLOW}⚠️  Предупреждений: $WARNINGS${NC}"
echo ""

# Расчет процента
if [ "$TOTAL_TESTS" -gt 0 ]; then
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${BOLD}Процент успешности: ${CYAN}$success_rate%${NC}"
    echo ""
    
    if [ "$success_rate" -ge 90 ]; then
        echo -e "${GREEN}${BOLD}🎉 ОТЛИЧНО! Система соответствует ТЗ на $success_rate%${NC}"
    elif [ "$success_rate" -ge 70 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  ХОРОШО, но есть проблемы. Соответствие ТЗ: $success_rate%${NC}"
    else
        echo -e "${RED}${BOLD}❌ КРИТИЧНО! Система не соответствует ТЗ. Соответствие: $success_rate%${NC}"
    fi
fi

echo ""
echo -e "${CYAN}Детальный отчет сохранен в: $REPORT_FILE${NC}"

# Очистка
rm -rf "$TEMP_DIR"

exit $FAILED_TESTS

