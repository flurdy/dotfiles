function git-worktree-new
    argparse --name=git-worktree-new \
        'h/help' \
        'c/claude' \
        'p/print' \
        -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: git-worktree-new [OPTIONS] <branch> [claude-prompt]"
        echo ""
        echo "Create a new git worktree as a sibling directory."
        echo "Directory name: <reponame>-<branchname>"
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  -c, --claude  Launch interactive Claude Code in the new worktree"
        echo "  -p, --print   Launch Claude Code in print mode (requires prompt argument)"
        echo ""
        echo "Examples:"
        echo "  git-worktree-new feature-auth"
        echo "  git-worktree-new fix-bug --claude"
        echo "  git-worktree-new fix-bug --print 'Fix the auth bug in login.ts'"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Error: Branch name is required"
        echo "Usage: git-worktree-new <branch> [claude-prompt]"
        return 1
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    set branch $argv[1]
    set claude_prompt ""
    if test (count $argv) -gt 1
        set claude_prompt $argv[2..-1]
    end

    # Get canonical repo name from remote (works from any worktree)
    set remote_url (git remote get-url origin 2>/dev/null)
    if test -n "$remote_url"
        set repo_name (string replace -r '.*/(.+?)(\.git)?$' '$1' $remote_url)
    else
        # Fallback: use the toplevel directory name
        set repo_name (basename (git rev-parse --show-toplevel))
    end

    # Place worktree as sibling to the repo root
    set repo_toplevel (git rev-parse --show-toplevel)
    set parent_dir (dirname $repo_toplevel)
    set worktree_dir "$repo_name-$branch"
    set worktree_path "$parent_dir/$worktree_dir"

    if test -d $worktree_path
        echo "Error: Directory already exists: $worktree_path"
        return 1
    end

    # Create worktree (use -b only for new branches)
    if git show-ref --verify --quiet refs/heads/$branch
        git worktree add $worktree_path $branch
    else
        git worktree add $worktree_path -b $branch
    end
    or begin
        echo "Error: Failed to create worktree"
        return 1
    end

    echo "Created worktree: $worktree_path"
    echo "Branch: $branch"

    cd $worktree_path

    # Handle Claude Code launch
    if set -q _flag_print
        if test -z "$claude_prompt"
            echo "Error: --print requires a prompt argument"
            return 1
        end
        echo "Launching Claude Code in print mode..."
        claude -p "$claude_prompt" --print &
    else if set -q _flag_claude
        echo "Launching Claude Code..."
        claude
    end
end
