function worktree-claude
   set branch $argv[1]
    git worktree add ../$branch -b $branch
    cd ../$branch
    # Optionally start Claude Code
    if test (count $argv) -gt 1
        claude -p $argv[2] --print &
    end
end
