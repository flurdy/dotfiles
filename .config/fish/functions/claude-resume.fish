function claude-resume --description 'Resume a Claude Code session by ID, recreating its cwd if pruned'
    if test (count $argv) -ne 1
        echo "usage: claude-resume <session-id>" >&2
        return 2
    end

    set -l id $argv[1]
    set -l jsonl (find ~/.claude/projects -type f -name "$id.jsonl" 2>/dev/null | head -1)

    if test -z "$jsonl"
        echo "claude-resume: no transcript found for $id" >&2
        return 1
    end

    # The parent dir name is the slugified canonical cwd (/ → -).
    # Pick the cwd from the transcript whose slug matches, since transcripts
    # can contain multiple cwd values from sub-tool invocations.
    set -l project_dir (basename (dirname $jsonl))
    set -l cwd (jq -r 'select(.cwd) | .cwd' $jsonl | sort -u | while read -l c
        if test (string replace -a / - $c) = $project_dir
            echo $c
            break
        end
    end)

    if test -z "$cwd"
        echo "claude-resume: could not resolve cwd for $id from $jsonl" >&2
        return 1
    end

    if not test -d $cwd
        echo "claude-resume: cwd $cwd is missing, recreating empty dir" >&2
        mkdir -p $cwd
        or return 1
    end

    cd $cwd
    or return 1
    claude --resume $id
end
