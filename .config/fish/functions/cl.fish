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
                echo '  enter=default session  ctrl-n=new  ctrl-r=resume-pick  ctrl-f=fork  ctrl-w=worktree'
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

    # new worktree. A typed name goes through cl-mkworktree (which also copies the
    # settings.local.json permission allowlist into the worktree). A blank name falls
    # back to a bare `claude -w`: Claude creates + randomly names the worktree itself,
    # and the SessionStart hook symlinks node_modules from main.
    set -l bare_w 0
    if test "$type" = new
        read -P 'New worktree branch name (blank = random): ' branch
        if test -z "$branch"
            set bare_w 1
        else
            set path (command $bin/cl-mkworktree $branch)
            or return 1
        end
        set session new
    end

    # ctrl-w: start the selected row in a brand-new worktree. For a handoff row the
    # note still seeds the fresh session; the recorded pick-up dir (main, a pruned
    # worktree, or a live one) is ignored in favour of a clean checkout.
    if test "$session" = worktree
        # smart default branch: reuse the row's branch when it's free to attach
        # (not main/master and not checked out in any worktree), else derive a
        # fresh name from the handoff note filename.
        set -l default_branch
        if test -n "$branch" -a "$branch" != main -a "$branch" != master -a "$branch" != '(detached)'
            if not git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"
                set default_branch $branch
            end
        end
        if test -z "$default_branch" -a -n "$note"
            set default_branch (string replace -r '^\d{4}-\d{2}-\d{2}-' '' (basename $note .md))
        end
        if test -n "$default_branch"
            read -P "New worktree branch [$default_branch]: " branch
            test -z "$branch"; and set branch $default_branch
        else
            read -P 'New worktree branch: ' branch
        end
        if test -z "$branch"
            echo 'cl: branch name required' >&2
            return 1
        end
        set path (command $bin/cl-mkworktree $branch)
        or return 1
        set session new
    end

    # assemble claude args
    set -l cargs
    test $chrome -eq 1; and set cargs $cargs --chrome
    test -n "$model"; and set cargs $cargs --model $model
    test $bare_w -eq 1; and set cargs $cargs -w
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
    # note is only ever set for handoff rows, so seed whenever it's present —
    # covers both the default handoff launch and a ctrl-w fresh-worktree launch.
    set -l seed
    if test -n "$note"
        set seed "Resume from the handoff note at $note. Read that file, summarise where we left off and the open threads, then wait for my go-ahead before doing anything."
    end

    # A handoff's pick-up worktree may have been pruned (work finished, or no
    # changes so it was auto-removed). The note itself lives in the handoffs dir,
    # not the worktree, so fall back to the main repo dir and still seed it
    # rather than failing on a dead path.
    if test "$type" = handoff -a ! -d "$path"
        set -l main (command git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | string replace -r '/\.git$' '')
        if test -n "$main" -a -d "$main"
            echo "cl: ⚠ handoff worktree gone ($path) — resuming in $main" >&2
            set path $main
            set branch ''
        else
            echo "cl: ⚠ handoff worktree gone: $path" >&2
            return 1
        end
    end

    if test $dry -eq 1
        if test $bare_w -eq 1
            echo "claude $cargs   # from "(pwd)"; claude -w creates the worktree"
        else
            echo "cd $path"
            test -n "$seed"; and echo "claude $cargs <load $note>"; or echo "claude $cargs"
        end
        return 0
    end

    # bare `claude -w` makes its own worktree, so stay in the current repo dir
    test $bare_w -eq 0; and begin
        cd $path; or return 1
    end

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
