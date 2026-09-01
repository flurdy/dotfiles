function pl --description 'Pi launcher: pick a context (main/worktree/handoff/new) and start pi'
    set -l bin "$HOME/.pi/bin"
    if not test -x "$bin/pl-gather"; and test -x "$HOME/.dotfiles/.pi/bin/pl-gather"
        set bin "$HOME/.dotfiles/.pi/bin"
    end
    set -l dry 0
    set -l default_model 'openai-codex/gpt-5.6-sol'
    set -l default_thinking high
    set -l config_path "$HOME/.pi/agent/pl-launcher.json"
    set -l model ''
    set -l thinking ''
    set -l name ''

    # Keep launcher defaults independent from Pi's persisted defaults: the
    # model-tier router may temporarily change those while a session is active.
    if test -f "$config_path"
        if not command -sq jq
            echo "pl: ignoring $config_path because jq is unavailable" >&2
        else
            set -l config_json (command jq -ce . "$config_path" 2>/dev/null)
            if test $status -ne 0
                echo "pl: ignoring invalid JSON in $config_path" >&2
            else
                set -l config_model (printf '%s\n' "$config_json" | command jq -r 'if (.defaultModel | type) == "string" then .defaultModel else empty end')
                if test -n "$config_model"
                    if string match -rq -- '[[:space:]]' "$config_model"
                        echo "pl: ignoring invalid defaultModel in $config_path" >&2
                    else
                        set default_model "$config_model"
                    end
                end

                set -l config_thinking (printf '%s\n' "$config_json" | command jq -r 'if (.defaultThinking | type) == "string" then .defaultThinking else empty end')
                if test -n "$config_thinking"
                    switch "$config_thinking"
                        case off minimal low medium high xhigh max
                            set default_thinking "$config_thinking"
                        case '*'
                            echo "pl: ignoring invalid defaultThinking in $config_path" >&2
                    end
                end
            end
        end
    end

    for a in $argv
        switch $a
            case --dry-run -n
                set dry 1
            case '--model=*'
                set model (string replace -- '--model=' '' $a)
            case '--thinking=*'
                set thinking (string replace -- '--thinking=' '' $a)
            case '--name=*'
                set name (string replace -- '--name=' '' $a)
            case --list
                command $bin/pl-gather --list
                return 0
            case --help -h
                echo 'pl [--model=ID] [--thinking=LEVEL] [--name=NAME] [--dry-run|-n] [--list]'
                echo '  pick a context via fzf, then launch pi there.'
                echo "  fresh-session defaults: $default_model with $default_thinking thinking"
                echo "  configure defaults in $config_path"
                echo '  ctrl-p=toggle implement/plan  enter=default session  ctrl-n=new  ctrl-r=resume-pick  ctrl-w=worktree'
                return 0
            case --plan --implement
                echo "pl: choose the initial session mode with ctrl-p inside the launcher" >&2
                return 2
            case '*'
                echo "pl: unknown option: $a" >&2
                return 2
        end
    end

    set -l desc (command $bin/pl-gather)
    if test $status -ne 0
        # A plain non-Git directory has no contexts to pick. Preserve the direct
        # launch fallback, but only after gather has had a chance to find handoffs
        # owned by this directory or one of its workspace members.
        if command git rev-parse --git-dir >/dev/null 2>&1
            return 1
        end
        echo "pl: not a git repo — launching pi here" >&2
        test -n "$model"; or set model $default_model
        test -n "$thinking"; or set thinking $default_thinking
        set -l pargs
        set pargs $pargs --model $model
        set pargs $pargs --thinking $thinking
        test -n "$name"; and set pargs $pargs --name $name
        if test $dry -eq 1
            echo "pi $pargs   # from "(pwd)
            return 0
        end
        command pi $pargs
        return
    end
    set -l parts (string split \t -- $desc[1])
    test (count $parts) -ge 4; or return 1
    set -l type $parts[1]
    set -l path $parts[2]
    set -l branch $parts[3]
    set -l session $parts[4]
    set -l note ''
    test (count $parts) -ge 5; and set note $parts[5]
    set -l root ''
    test (count $parts) -ge 6; and set root $parts[6]
    set -l session_mode ''
    test (count $parts) -ge 7; and set session_mode $parts[7]

    # A handoff owned by a member of this multi-repo workspace: move into the
    # owning repo up front, so the worktree lookup, cl-mkworktree, and the
    # pruned-worktree fallback all act on that repo and not the workspace root.
    if test -n "$root" -a -d "$root"
        cd $root; or return 1
    end

    if test "$type" = new
        read -P 'New worktree branch: ' branch
        test -n "$branch"; or return 1
        set path (command $bin/pl-mkworktree $branch)
        or return 1
        set session new
    end

    # ctrl-w: start the selected row in a brand-new worktree. For a handoff row the
    # note still seeds the fresh session; the recorded pick-up dir is ignored in
    # favour of a clean checkout.
    if test "$session" = worktree
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
        test -n "$branch"; or return 1
        set path (command $bin/pl-mkworktree $branch)
        or return 1
        set session new
    end

    # A handoff's pick-up worktree may have been pruned. The note itself lives in
    # the handoffs dir, so fall back to the main repo dir and still seed it.
    if test "$type" = handoff -a ! -d "$path"
        set -l main (command git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | string replace -r '/\.git$' '')
        if test -n "$main" -a -d "$main"
            echo "pl: ⚠ handoff worktree gone ($path) — resuming in $main" >&2
            set path $main
            set branch ''
        else
            echo "pl: ⚠ handoff worktree gone: $path" >&2
            return 1
        end
    end

    if test "$session" = new
        test -n "$model"; or set model $default_model
        test -n "$thinking"; or set thinking $default_thinking
    end

    set -l pargs
    test -n "$model"; and set pargs $pargs --model $model
    test -n "$thinking"; and set pargs $pargs --thinking $thinking
    test -n "$name"; and set pargs $pargs --name $name
    switch $session_mode
        case plan
            set pargs $pargs --plan
        case implement
            set pargs $pargs --implement
    end
    switch $session
        case continue
            set pargs $pargs --continue
        case resume
            set pargs $pargs --resume
    end

    set -l seed
    if test -n "$note" -a "$session" != resume
        set seed "Resume from the handoff note at $note. Read that file, summarise where we left off and the open threads, then wait for my go-ahead before doing anything."
    end

    if test $dry -eq 1
        echo "cd $path"
        test -n "$seed"; and echo "pi $pargs <load $note>"; or echo "pi $pargs"
        return 0
    end

    cd $path; or return 1

    if test -n "$seed"
        set -l curbranch (command git -C $path rev-parse --abbrev-ref HEAD 2>/dev/null)
        if test -n "$branch" -a "$branch" != "$curbranch"
            echo "pl: ⚠ handoff branch '$branch' ≠ current '$curbranch' in $path" >&2
        end
        echo "pl: ↳ loading handoff $note" >&2
        echo "pl:   (if it doesn't auto-load, read $note)" >&2
        command pi $pargs $seed
    else
        command pi $pargs
    end
end
