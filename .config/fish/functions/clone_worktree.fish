function clone_worktree
    # Configuration: Edit these defaults or set environment variables
    set code_root (set -q CLONE_WORKTREE_CODE_ROOT; and echo $CLONE_WORKTREE_CODE_ROOT; or echo ~/Code)
    set default_parent (set -q CLONE_WORKTREE_DEFAULT; and echo $CLONE_WORKTREE_DEFAULT; or echo "projects")
    
    # Check if URL argument is provided
    if test (count $argv) -lt 1
        echo "Usage: clone_worktree <git-url> [parent-folder]"
        echo "Example: clone_worktree git@github.com:user/repo.git"
        echo "Example: clone_worktree git@github.com:user/repo.git myprojects"
        return 1
    end

    set git_url $argv[1]
    set parent_folder $default_parent
    
    # Check if we're already in a code root subdirectory
    set current_dir (pwd)
    if string match -q "$code_root/*" $current_dir
        # Use the entire path under code root as parent folder
        set parent_folder (string replace "$code_root/" "" $current_dir)
        echo "Detected current location in $code_root/$parent_folder"
    end
    
    # Use custom parent folder if provided (overrides detection)
    if test (count $argv) -ge 2
        set parent_folder $argv[2]
    end

    # Extract project name from URL (remove .git extension)
    set project_name (string replace -r '.*/(.+?)(\.git)?$' '$1' $git_url)
    
    if test -z "$project_name"
        echo "Error: Could not extract project name from URL"
        return 1
    end

    # Set up paths
    set base_path $code_root/$parent_folder
    set project_path $base_path/$project_name
    set git_path $project_path/.git
    
    echo "Setting up worktree for: $project_name"
    echo "Location: $project_path"
    
    # Create project directory
    mkdir -p $project_path
    or begin
        echo "Error: Failed to create directory $project_path"
        return 1
    end
    
    # Clone bare repository
    cd $project_path
    git clone --bare $git_url .git
    or begin
        echo "Error: Failed to clone repository"
        return 1
    end
    
    # Determine default branch (main or master)
    cd $git_path
    set default_branch (git symbolic-ref --short HEAD 2>/dev/null)
    
    if test -z "$default_branch"
        # Fallback: check for main or master
        if git show-ref --verify --quiet refs/heads/main
            set default_branch "main"
        else if git show-ref --verify --quiet refs/heads/master
            set default_branch "master"
        else
            echo "Error: Could not determine default branch"
            return 1
        end
    end
    
    echo "Using default branch: $default_branch"
    
    # Create main worktree
    set worktree_name "$project_name-$default_branch"
    git worktree add ../$worktree_name $default_branch
    or begin
        echo "Error: Failed to create worktree"
        return 1
    end
    
    # Navigate to the worktree
    cd ../$worktree_name
    
    echo "✓ Successfully set up worktree at: $PWD"
end
