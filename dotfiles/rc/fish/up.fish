function up --description 'Подняться на N директорий вверх'
    set -l levels $argv[1]

    if test -z "$levels" || not string match -qr '^[0-9]+$' "$levels"
        set levels 1
    end

    set -l path ""
    for i in (seq 1 $levels)
        set path "$path../"
    end

    cd $path
end

# Автодополнение
complete -c up -f -k -a '(
    set -l dir (pwd)
    set -l i 1
    while test "$dir" != "/"
        set dir (dirname "$dir")
        printf "%s\t%s\n" $i (basename "$dir")
        set i (math $i + 1)
    end
)'