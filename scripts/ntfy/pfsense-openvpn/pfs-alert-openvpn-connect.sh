#!/bin/sh

# =======================================
# Конфигурация
# =======================================
NTFY_TOPIC="pfs_openvpn"
NTFY_SERVER="https://ntfy.domain.ru"
NTFY_TOKEN="tk_5...t"

TIMEOUT=5
MYDATE=$(/bin/date +'%Y/%m/%d %H:%M:%S')
HOSTNAME=pfsense


# =======================================
# Формирование сообщения
# =======================================
if [ "$script_type" = "client-connect" ]; then
  TITLE="🟢 VPN: Подключение $common_name"
  PRIORITY="low"
  TAGS="vpn,login,success"

  MSG="### Конект

👤 **Пользователь:** \`$common_name\`
💻 **Внешний IP:** \`$trusted_ip\`
🌐 **Внутренний IP:** \`$ifconfig_pool_remote_ip\`
🤖 **Хост:** \`$HOSTNAME\`
🕒 **Время:** \`$MYDATE\`"

elif [ "$script_type" = "client-disconnect" ]; then
  TITLE="🔴 VPN: Отключение $common_name"
  PRIORITY="min"
  TAGS="vpn,logout,disconnect"

  MSG="### Дисконект

👤 **Пользователь:** \`$common_name\`
💻 **Внешний IP:** \`$trusted_ip\`
🌐 **Внутренний IP:** \`$ifconfig_pool_remote_ip\`
🤖 **Хост:** \`$HOSTNAME\`
🕒 **Время:** \`$MYDATE\`"

else
  exit 0
fi

# =======================================
# ОТПРАВКА В ФОНЕ
# =======================================
(
  if [ -n "${NTFY_TOKEN:-}" ]; then
    HTTP_CODE=$( /usr/local/bin/curl -s -o /dev/null -w "%{http_code}" \
      -m $TIMEOUT --max-time $TIMEOUT \
      -X POST \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      -H "Markdown: yes" \
      -H "Authorization: Bearer $NTFY_TOKEN" \
      -d "$MSG" \
      "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null ) || HTTP_CODE="000"
  else
    HTTP_CODE=$( /usr/local/bin/curl -s -o /dev/null -w "%{http_code}" \
      -m $TIMEOUT --max-time $TIMEOUT \
      -X POST \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      -H "Markdown: yes" \
      -d "$MSG" \
      "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null ) || HTTP_CODE="000"
  fi

  case "$HTTP_CODE" in
    2[0-9][0-9])
      logger -t "openvpn-ntfy" "ОК (HTTP $HTTP_CODE) для $common_name ($script_type)"
      ;;
    *)
      logger -t "openvpn-ntfy" "ERROR (HTTP $HTTP_CODE) для $common_name ($script_type)"
      ;;
  esac
) &

exit 0