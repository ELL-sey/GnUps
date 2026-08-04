#!/usr/bin/env bash
# PAM-скрипт для отправки уведомлений в ntfy

set -eo pipefail

# Явно задаем PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# =======================================
# Конфигурация
# =======================================
CONFIG_FILE="${NTFY_CONFIG_FILE:-/etc/ntfy/server.conf}"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
# дефолты для  переменных
PRIORITY="${NTFY_PRIORITY:-high}"
TIMEOUT="${NTFY_TIMEOUT:-5}"
TAGS="${NTFY_TAGS:-warning,pam,linux,login}"
IP_HOST="${NTFY_IP_HOST:-unknown}"
PAM_USER="${PAM_USER:-unknown}"
PAM_RHOST="${PAM_RHOST:-локально}"
PAM_SERVICE="${PAM_SERVICE:-unknown}"
PAM_TYPE="${PAM_TYPE:-open_session}"

# Получаем имя хоста
HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Загружаем конфигурацию
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Обязательные переменные
if [ -z "${NTFY_URL:-}" ] || [ -z "${NTFY_TOPIC:-}" ]; then
    logger -t "ntfy-login" "Ошибка: NTFY_URL или NTFY_TOPIC не заданы в конфиге"
    exit 0 
fi

# Проверка, что это открытие сессии
if [ "$PAM_TYPE" != "open_session" ]; then
    exit 0
fi

# Проверка наличия curl
if ! command -v curl >/dev/null 2>&1; then
    logger -t "ntfy-login" "Ошибка: curl не установлен"
    exit 0
fi

# Фильтруем спам от su (можно отключить)
if [ "$PAM_SERVICE" = "su" ]; then
    PRIORITY="default"
    # exit 0
fi

# =======================================
# Сообщение
# =======================================
MSG="### Вход в систему

👤 **Пользователь:** \`$PAM_USER\`
💻 **IP usr:** \`$PAM_RHOST\`
🤖 **Хост:** \`$HOSTNAME\`
🌐 **IP host:** \`$IP_HOST\`
⚙️ **Сервис:** \`$PAM_SERVICE\`
🕒 **Время:** \`$DATE\`"

# =======================================
# SEND
# =======================================
# Аргументы для curl
CURL_ARGS=(
    -s --max-time "$TIMEOUT"
    -H "Title: Вход в $HOSTNAME"
    -H "Priority: $PRIORITY"
    -H "Tags: $TAGS"
    -H "Markdown: yes"
    -d "$MSG"
)

if [ -n "${NTFY_TOKEN:-}" ]; then
    CURL_ARGS+=(-H "Authorization: Bearer $NTFY_TOKEN")
fi

# Отправляем. 
HTTP_CODE=$(curl -o /dev/null -w "%{http_code}" "${CURL_ARGS[@]}" "https://$NTFY_URL/$NTFY_TOPIC" 2>/dev/null) || HTTP_CODE="000"

if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    logger -t "ntfy-login" "ОК (HTTP $HTTP_CODE) для $PAM_USER ($PAM_SERVICE)"
else
    logger -t "ntfy-login" "ERROR (HTTP $HTTP_CODE) для $PAM_USER ($PAM_SERVICE)"
fi

exit 0