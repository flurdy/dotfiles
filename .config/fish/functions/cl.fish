function cl --description 'Claude launcher: pick a context (main/worktree/handoff/new) and start claude'
    set -l bin "$HOME/.claude/bin"
    set -l dry 0
    set -l chrome 0
    set -l model ''

    for a in $argv
        switch $a
            case --dry-run -n
                set dry 1
            case --chrome -C
                set chrome 1
            case '--model=*'
                set model (string replace -- '--model=' '' $a)
            case --list
                command $bin/cl-gather --list
                return 0
            case --help -h
                echo 'cl [--chrome|-C] [--model=ID] [--dry-run|-n] [--list]'
                echo '  pick a context via fzf, then launch claude there.'
                echo '  enter=default session  ctrl-n=new  ctrl-r=resume-pick  ctrl-f=fork'
                return 0
        end
    end

    set -l desc (command $bin/cl-gather)
    or return 1
    set -l parts (string split \t -- $desc[1])
    test (count $parts) -ge 4; or return 1
    set -l type $parts[1]
    set -l path $parts[2]
    set -l branch $parts[3]
    set -l session $parts[4]
    set -l note ''
    test (count $parts) -ge 5; and set note $parts[5]

    # new worktree: create it, then launch a fresh session
    if test "$type" = new
        read -P 'New worktree branch name: ' branch
        test -z "$branch"; and return 1
        set path (command $bin/cl-mkworktree $branch)
        or return 1
        set session new
    end

    # assemble claude args
    set -l cargs
    test $chrome -eq 1; and set cargs $cargs --chrome
    test -n "$model"; and set cargs $cargs --model $model
    switch $session
        case continue
            set cargs $cargs --continue
        case resume
            set cargs $cargs --resume
        case fork
            set cargs $cargs --continue --fork-session
    end

    # handoff: seed an initial prompt so the fresh session loads that exact note.
    # (A handoff is a markdown file, not a resumable conversation — see cl-gather.)
    set -l seed
    if test "$session" = handoff -a -n "$note"
        set seed "Resume from the handoff note at $note. Read that file, summarise where we left off and the open threads, then wait for my go-ahead before doing anything."
    end

    if test $dry -eq 1
        echo "cd $path"
        test -n "$seed"; and echo "claude $cargs <load $note>"; or echo "claude $cargs"
        return 0
    end

    cd $path; or return 1

    # ensure we're where the handoff expects; warn (don't block) on branch drift
    if test -n "$seed"
        set -l curbranch (command git -C $path rev-parse --abbrev-ref HEAD 2>/dev/null)
        if test -n "$branch" -a "$branch" != "$curbranch"
            echo "cl: ⚠ handoff branch '$branch' ≠ current '$curbranch' in $path" >&2
        end
        echo "cl: ↳ loading handoff $note" >&2
        echo "cl:   (if it doesn't auto-load, run: /handoffs  — or read $note)" >&2
    end

    if test -n "$seed"
        command claude $cargs $seed
    else
        command claude $cargs
    end
end
