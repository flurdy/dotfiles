function watchrelease --description 'Launch Claude running /watch-release on a watch-safe model (default sonnet)'
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
                echo 'watchrelease [interval] [stop_hour] [--model=ID] [--dry-run|-n]'
                echo '  start claude on a fixed model running /watch-release in the current repo.'
                echo '  --model applies to this session only; your saved default is untouched.'
                echo '  attended loop — keep the tab visible; it prompts to push/defer/cancel.'
                return 0
            case '*'
                set wargs $wargs $a
        end
    end

    if not command git rev-parse --git-dir >/dev/null 2>&1
        echo 'watchrelease: not a git repo — /release-manager needs the repo context' >&2
        return 1
    end

    set -l prompt (string join ' ' /watch-release $wargs | string trim)
    if test $dry -eq 1
        echo "claude --model $model '$prompt'   # from "(pwd)
        return 0
    end
    command claude --model $model $prompt
end
