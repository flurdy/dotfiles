function watchprs --description 'Launch Claude running /watch-prs on a watch-safe model (default sonnet)'
    set -l model sonnet
    set -l dry 0
    set -l wargs

    for a in $argv
        switch $a
            case '--model=*'
                set model (string replace -- '--model=' '' $a)
            case --dry-run -n
                set dry 1
            case --help -h
                echo 'watchprs [interval] [stop_hour] [--model=ID] [--dry-run|-n]'
                echo '  start claude on a fixed model running /watch-prs in the current repo.'
                echo '  --model applies to this session only; your saved default is untouched.'
                echo '  default model: sonnet — adaptive watch ticks render blank on Fable-class models.'
                return 0
            case '*'
                set wargs $wargs $a
        end
    end

    if not command git rev-parse --git-dir >/dev/null 2>&1
        echo 'watchprs: not a git repo — /pr-status needs an origin remote to detect the org' >&2
        return 1
    end

    set -l prompt (string join ' ' /watch-prs $wargs | string trim)
    if test $dry -eq 1
        echo "claude --model $model '$prompt'   # from "(pwd)
        return 0
    end
    command claude --model $model $prompt
end
