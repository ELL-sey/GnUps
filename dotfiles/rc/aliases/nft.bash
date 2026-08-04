
# Основные
alias nft_check='nft -c -f /etc/nftables.conf'
alias nft_reload='nft -f /etc/nftables.conf'
alias nft_vim='vim /etc/nftables.conf'
alias nft_show='nft list ruleset'
alias nft_show_raw='nft -a list ruleset'  # с handle
alias nft_counters='nft list ruleset | grep -E "(counter|packets|bytes)"'
alias nft_chains='nft list chains'
alias nft_backup='nft list ruleset > ~/nftables_backup_$(date +%Y%m%d_%H%M%S).conf'


# Добавление/удаление IP в список
alias nft_add='nft add element inet filter dynamic_allow'
alias nft_del='nft delete element inet filter dynamic_allow'

# Сброс счетчиков
alias nft_reset_counters='nft reset counters'

# conntrack
alias nft_conntrack='conntrack -L'
