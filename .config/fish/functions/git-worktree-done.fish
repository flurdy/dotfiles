function git-worktree-done
    argparse --name=git-worktree-done \
        'h/help' \
        -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: git-worktree-done"
        echo ""
        echo "Remove the current worktree and delete its branch."
        echo "Must be run from inside a worktree (not the main working tree)."
        echo ""
        echo "Behavior:"
        echo "  - Warns if there are uncommitted changes"
        echo "  - Removes the worktree directory"
        echo "  - Deletes the branch (prompts to force-delete if unmerged)"
        echo "  - Returns you to the main working tree"
        return 0
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    set branch (git branch --show-current)
    if test -z "$branch"
        echo "Error: Could not determine current branch (detached HEAD?)"
        return 1
    end

    set current_toplevel (git rev-parse --show-toplevel)

    # Find the main worktree (first entry in porcelain output)
    set main_worktree (git worktree list --porcelain | head -1 | string replace 'worktree ' '')

    if test "$current_toplevel" = "$main_worktree"
        echo "Error: You are in the main working tree, not a worktree"
        return 1
    end

    # Check for uncommitted changes
    if not git diff --quiet; or not git diff --cached --quiet
        echo "Warning: You have uncommitted changes in this worktree"
        read -P "Continue anyway? [y/N] " confirm
        if not string match -qi 'y' $confirm
            echo "Aborted"
            return 1
        end
    end

    echo "Removing worktree: $current_toplevel"
    echo "Branch: $branch"

    # Navigate to the main worktree before removing
    cd $main_worktree
    or begin
        echo "Error: Could not navigate to main worktree: $main_worktree"
        return 1
    end

    git worktree remove $current_toplevel
    or begin
        echo "Error: Failed to remove worktree"
        echo "Try: git worktree remove --force $current_toplevel"
        return 1
    end

    echo "Removed worktree"

    # Try safe branch delete, prompt for force if unmerged
    git branch -d $branch 2>/dev/null
    if test $status -ne 0
        echo "Warning: Branch '$branch' has unmerged changes"
        read -P "Force delete branch? [y/N] " confirm
        if string match -qi 'y' $confirm
            git branch -D $branch
            or begin
                echo "Error: Failed to force delete branch '$branch'"
                return 1
            end
            echo "Force deleted branch: $branch"
        else
            echo "Branch '$branch' kept"
        end
    else
        echo "Deleted branch: $branch"
    end

    echo "Done. Now in: $main_worktree"
end
