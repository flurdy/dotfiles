function claude-symlink --description 'Convert a worktree .claude dir into a symlink mirroring the main worktree'
    argparse --name=claude-symlink 'h/help' 'f/force' 'n/dry-run' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: claude-symlink [-f|--force] [-n|--dry-run]"
        echo ""
        echo "Inside a git worktree, replace .claude/ with a symlink resolving to"
        echo "the same target as the main worktree's .claude symlink."
        echo ""
        echo "Useful when 'claude -w' or 'git worktree add' produced a worktree"
        echo "with a fresh local .claude/ instead of inheriting the shared one."
        echo ""
        echo "Without --force, refuses to remove a .claude/ dir that contains"
        echo "anything other than settings.local.json. Always shows a diff and"
        echo "asks before deleting an existing settings.local.json."
        echo ""
        echo "Options:"
        echo "  -h, --help     Show this help"
        echo "  -f, --force    Allow replacement even with unexpected files in .claude/"
        echo "  -n, --dry-run  Show what would happen without making changes"
        return 0
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: not in a git repository" >&2
        return 1
    end

    set -l wt (git rev-parse --show-toplevel)
    set -l main (git worktree list --porcelain | head -1 | string replace 'worktree ' '')

    if test "$wt" = "$main"
        echo "Error: this is the main worktree, nothing to mirror" >&2
        return 1
    end

    if test ! -L "$main/.claude"
        echo "Error: $main/.claude is not a symlink — nothing to mirror" >&2
        return 1
    end

    set -l target (realpath "$main/.claude")
    if test ! -d "$target"
        echo "Error: main .claude target does not exist: $target" >&2
        return 1
    end

    if test -L "$wt/.claude"
        echo "Already a symlink: $wt/.claude -> "(readlink "$wt/.claude")
        return 0
    end

    set -l rel (realpath --relative-to=$wt $target)

    if test -d "$wt/.claude"
        set -l unexpected
        for f in (ls -A "$wt/.claude")
            test "$f" != "settings.local.json"; and set -a unexpected $f
        end
        if test (count $unexpected) -gt 0; and not set -q _flag_force
            echo "Error: $wt/.claude contains unexpected files:" >&2
            for f in $unexpected
                echo "  $f" >&2
            end
            echo "Re-run with --force to replace anyway." >&2
            return 1
        end

        if test -f "$wt/.claude/settings.local.json"
            echo "Diff $target/settings.local.json -> $wt/.claude/settings.local.json:"
            diff "$target/settings.local.json" "$wt/.claude/settings.local.json"
            echo ""
            echo "$wt/.claude/settings.local.json will be REMOVED."
            echo "Merge any wanted lines into $target/settings.local.json first."
            if set -q _flag_dry_run
                echo "(dry-run: skipping prompt)"
            else
                read -P "Continue? [y/N] " confirm
                if not string match -qi 'y' -- $confirm
                    echo "Aborted"
                    return 1
                end
            end
        end

        if set -q _flag_dry_run
            echo "(dry-run) would: rm -rf $wt/.claude"
        else
            rm -rf "$wt/.claude"
        end
    end

    if set -q _flag_dry_run
        echo "(dry-run) would: ln -s $rel $wt/.claude"
        echo "(dry-run) would resolve to: $target"
        return 0
    end

    ln -s $rel "$wt/.claude"
    echo "Created: $wt/.claude -> $rel"
    echo "Resolves to: $target"
end
