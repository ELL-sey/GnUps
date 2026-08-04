function mkcd
    if not set -q argv[1]
        echo "Использование: mkcd <путь_к_каталогу>"
        return 1
    end
    mkdir -p "$argv[1]" && cd "$argv[1]"
end

function lc
    fd -i -H -p -tf 'config$ | .*\.(conf|config|ovpn|env|cfg)$' --color=always $argv
end

# Подставление sudo
function add_sudo
    set -l current (commandline)
    if test -z "$current"
        # последнюю команду из массива
        set -l last $history[1]
        commandline -r "sudo $last"
    else
        commandline -r "sudo $current"
    end
    commandline -f repaint
end
bind \es add_sudo # Alt+S



# Подставление watch
function add_watch
    set -l current (commandline)
    if test -z "$current"
        set -l last $history[1]
        commandline -r "watch -dc \"$last\""
    else
        commandline -r "watch -dc  \"$current\""
    end
    commandline -f repaint
end
bind \ew add_watch # Alt+W


# Быстрый поиск по cheat через fzf
function cheat-fzf
    # Получаем список
    set -l selected (cheat -l | awk '{print $1}' | fzf --preview 'cheat {}' --preview-window=down:60% --height=40% --border --prompt="Поиск > " --bind 'ctrl-f:execute(cheat -s {q})')

    if test -n "$selected"
        cheat $selected
    end
end
bind \cf cheat-fzf # Ctrl+F
