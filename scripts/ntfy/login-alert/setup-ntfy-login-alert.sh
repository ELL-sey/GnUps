#!/usr/bin/env bash
set -euo pipefail

# =======================================
# Цвета и функции печати
# =======================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[ OK ]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERR ]${NC} $1" >&2; }
print_header()  { echo -e "\n${CYAN}===> $1 <===${NC}\n"; }

# =======================================
# Константы
# =======================================
SCRIPT_URL="https://raw.githubusercontent.com/ELL-sey/GnUps/main/scripts/ntfy/login-alert/ntfy-login-alert.sh" 

CONFIG_DIR="/etc/ntfy"
CONFIG_FILE="$CONFIG_DIR/server.conf"
SCRIPT_PATH="/usr/local/bin/ntfy-login-alert.sh"

# =======================================
# Проверка прав
# =======================================
if [[ $EUID -ne 0 ]]; then
    print_error "Скрипт должен запускаться с правами root (sudo)"
    exit 1
fi

print_header "Настройка PAM уведомлений о входе в систему (ntfy)"

# =======================================
# 1. Установка основного скрипта
# =======================================
print_header "1. Установка основного скрипта"


print_info "Скачивание скрипта..."
if curl -sSL --fail "$SCRIPT_URL" -o "$SCRIPT_PATH" 2>/dev/null; then
    print_success "Скрипт успешно скачан."
else
    print_warning "Не удалось скачать скрипт по URL"
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        print_error "Локальный файл $SCRIPT_PATH тоже не найден. Установка прервана."
        exit 1
    fi
    print_info "Используем существующий локальный файл."
fi

chmod +x "$SCRIPT_PATH"
print_success "Скрипт установлен: $SCRIPT_PATH"

# =======================================
# 2. Сбор настроек NTFY
# =======================================
print_header "2. Настройка подключения к NTFY"
print_info "Нажмите Enter, чтобы использовать значение по умолчанию (в скобках)"

read -p "NTFY_URL (сервер, например ntfy.sh) [ntfy.sh]: " input || true
NTFY_URL="${input:-ntfy.sh}"

read -p "NTFY_TOPIC (название топика) [logins]: " input || true
NTFY_TOPIC="${input:-logins}"

read -p "NTFY_TOKEN (токен авторизации) []: " NTFY_TOKEN || true

read -p "NTFY_PRIORITY (high/default/low/min) [high]: " input || true
NTFY_PRIORITY="${input:-high}"

read -p "NTFY_TAGS (теги через запятую) [warning,pam,linux,login]: " input || true
NTFY_TAGS="${input:-warning,pam,linux,login}"

print_info "Определение основного IP хоста..."
IP_HOST=$(ip route get 8.8.8.8 2>/dev/null | awk -F'src ' '{print $2}' | awk '{print $1; exit}')
IP_HOST=${IP_HOST:-"unknown"}
print_success "IP хоста: $IP_HOST"

# =======================================
# 3. Создание конфигурационного файла
# =======================================
print_header "3. Создание конфигурационного файла"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" << EOF
# =======================================
# NTFY Login Alert Configuration
# =======================================
# Создано: $(date)

# Обязательные параметры
NTFY_URL="$NTFY_URL"
NTFY_TOPIC="$NTFY_TOPIC"

# Опциональные параметры
NTFY_TOKEN="$NTFY_TOKEN"
NTFY_PRIORITY="$NTFY_PRIORITY"
NTFY_TAGS="$NTFY_TAGS"

# Системные параметры
IP_HOST="$IP_HOST"
NTFY_TIMEOUT="5"
EOF

# PAM-скрипт выполняется от имени авторизующегося пользователя
chmod 644 "$CONFIG_FILE"
chown root:root "$CONFIG_FILE"

print_success "Конфигурационный файл создан: $CONFIG_FILE"

# =======================================
# 4. Интеграция с PAM
# =======================================
print_header "4. Интеграция с PAM"

PAM_FILE=""
if [[ -f "/etc/pam.d/sshd" ]]; then
    PAM_FILE="/etc/pam.d/sshd"
elif [[ -f "/etc/pam.d/common-session" ]]; then
    PAM_FILE="/etc/pam.d/common-session"
elif [[ -f "/etc/pam.d/system-auth" ]]; then
    PAM_FILE="/etc/pam.d/system-auth"
fi

if [[ -z "$PAM_FILE" ]]; then
    print_warning "Не удалось автоматически определить PAM файл"
    read -p "Введите путь к PAM файлу вручную (например /etc/pam.d/sshd): " PAM_FILE || true
fi

if [[ ! -f "$PAM_FILE" ]]; then
    print_error "Файл $PAM_FILE не существует"
    exit 1
fi

PAM_LINE="session optional pam_exec.so quiet $SCRIPT_PATH"

if grep -qF "$SCRIPT_PATH" "$PAM_FILE" 2>/dev/null; then
    print_warning "Строка уже присутствует в $PAM_FILE -> пропускаем..."
else
    echo "" >> "$PAM_FILE"
    echo "# NTFY Login Alerts" >> "$PAM_FILE"
    echo "$PAM_LINE" >> "$PAM_FILE"
    print_success "Строка успешно добавлена в $PAM_FILE"
fi

# =======================================
# 5. Тестирование
# =======================================
print_header "5. Тестирование"

read -p "Отправить тестовое уведомление прямо сейчас? (y/n) [y]: " TEST_SEND || true
TEST_SEND="${TEST_SEND:-y}"

if [[ "$TEST_SEND" =~ ^[Yy]$ ]]; then
    print_info "Отправка тестового уведомления..."
    
    # Эмулируем переменные PAM
    export PAM_USER="test_user"
    export PAM_TYPE="open_session"
    export PAM_RHOST="192.168.1.100"
    export PAM_SERVICE="test_script"
    export NTFY_CONFIG_FILE="$CONFIG_FILE" 
    
    if "$SCRIPT_PATH"; then
        print_success "Тестовое уведомление отправлено!"
        print_info "Проверьте ваше устройство с ntfy."
    else
        print_error "Ошибка при отправке. Проверьте логи: journalctl -t ntfy-login -n 10"
    fi
fi

# =======================================
# Итоговая информация
# =======================================
print_header "Установка завершена!"

echo "⚙️   Конфигурация: $CONFIG_FILE"
echo "</>  Скрипт:       $SCRIPT_PATH"
echo "📁   PAM файл:     $PAM_FILE"

echo -e "\n${YELLOW}💡 Полезные команды${NC}"
echo "   journalctl -t ntfy-login -f # просмотр логов"

echo -e "\n${YELLOW}⚠️  Важно:${NC}"
echo "   Для проверки выполните параллельный вход (например по SSH), не разрывая текущую сессию!"
echo "   Токен хранится в открытом виде в $CONFIG_FILE (ограничте его на сервере)"
echo "   По умолчанию alert настроен для $PAM_FILE"

exit 0