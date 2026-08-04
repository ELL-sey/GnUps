
alias ping='ping -a -f  -i 0.4 '
alias p='ping -a -f  -i 0.2 '
alias pc='ping -a'
alias gp='gping'
alias p8='gping 8.8.8.8'
alias ipc='ipcalc -b'


alias lldp_start='sudo systemctl  start  lldpd'
alias lldp_show='watch "sudo lldpcli show neighbors details"'