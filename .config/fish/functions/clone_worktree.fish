# Fish Shell Function: clone_worktree
#
# Clone a git repository with worktree-friendly setup.
# By default, creates a regular clone. Use --bare for bare repo mode.
#
# Installation:
# Save this file to: ~/.config/fish/functions/clone_worktree.fish
# Fish will automatically load functions from this directory.
#
# Setup Instructions:
# 1. Create a bash wrapper in your bin folder (e.g., ~/bin/git-clone-worktree.sh):
#    #!/bin/bash
#    fish -c "clone_worktree $(printf '%q ' "$@")"
#
# 2. Make it executable:
#    chmod +x ~/bin/git-clone-worktree.sh
#
# 3. Add a git alias to .gitconfig:
#    [alias]
#        wtc = "!git-clone-worktree.sh"
#
# 4. Usage:
#    git wtc myorg/myrepo
#    git wtc git@github.com:user/repo.git --parent myprojects
#    git wtc user/repo --bare    # bare repo mode (for worktree-only workflows)
#
function clone_worktree
    # Configuration: Edit these defaults or set environment variables
    set code_root (set -q CLONE_WORKTREE_ROOT; and echo $CLONE_WORKTREE_ROOT; or echo ~/Code)
    set default_parent (set -q CLONE_WORKTREE_PARENT; and echo $CLONE_WORKTREE_PARENT; or echo "projects")
    set default_org (set -q CLONE_WORKTREE_ORG; and echo $CLONE_WORKTREE_ORG; or echo "")
    set default_server (set -q CLONE_WORKTREE_SERVER; and echo $CLONE_WORKTREE_SERVER; or echo "github.com")
    set default_flat (set -q CLONE_WORKTREE_FLAT; and echo $CLONE_WORKTREE_FLAT; or echo "false")
    set bare_name (set -q CLONE_WORKTREE_BARE_NAME; and echo $CLONE_WORKTREE_BARE_NAME; or echo ".bare")
    set default_no_suffix (set -q CLONE_WORKTREE_NO_SUFFIX; and echo $CLONE_WORKTREE_NO_SUFFIX; or echo "false")

    # Parse named arguments
    argparse --name=clone_worktree \
        'h/help' \
        'r/root=' \
        'p/parent=' \
        'o/org=' \
        'n/name=' \
        'b/bare' \
        'f/flat' \
        'no-flat' \
        'no-suffix' \
        -- $argv
    or return 1

    # Show help if requested
    if set -q _flag_help
        echo "Usage: clone_worktree [OPTIONS] <repo>"
        echo ""
        echo "Clone a git repository with worktree-friendly setup."
        echo "Default: regular clone. Use --bare for bare repo mode."
        echo ""
        echo "Arguments:"
        echo "  <repo>                Repository to clone. Can be:"
        echo "                        - Full URL: git@github.com:user/repo.git"
        echo "                        - HTTPS URL: https://github.com/user/repo.git"
        echo "                        - Shorthand: user/repo (uses default server)"
        echo "                        - Shorthand: repo (uses default org and server)"
        echo ""
        echo "Options:"
        echo "  -h, --help           Show this help message"
        echo "  -r, --root PATH      Override code root directory (default: ~/Code or \$CLONE_WORKTREE_ROOT)"
        echo "  -p, --parent FOLDER  Parent folder under code root (default: 'projects' or \$CLONE_WORKTREE_PARENT)"
        echo "  -o, --org ORG        Override default organization/user for shorthand 'repo' format"
        echo "  -n, --name NAME      Custom folder/project name (default: extracted from repo URL)"
        echo "  -b, --bare           Use bare repo mode (for worktree-only workflows)"
        echo ""
        echo "Bare mode options (only with --bare):"
        echo "  -f, --flat           Place bare repo and worktree directly in parent (no project folder)"
        echo "  --no-flat            Force nested mode (overrides CLONE_WORKTREE_FLAT env var)"
        echo "  --no-suffix          Don't append branch name to worktree folder"
        echo ""
        echo "Environment Variables:"
        echo "  CLONE_WORKTREE_ROOT              Override default code root directory"
        echo "  CLONE_WORKTREE_PARENT            Override default parent folder"
        echo "  CLONE_WORKTREE_ORG               Default Git organization/user for shorthand notation"
        echo "  CLONE_WORKTREE_SERVER             Default Git server (default: github.com)"
        echo "  CLONE_WORKTREE_FLAT              Use flat mode by default in bare mode (true/false, default: false)"
        echo "  CLONE_WORKTREE_BARE_NAME         Name for bare repo folder (default: .bare)"
        echo "  CLONE_WORKTREE_NO_SUFFIX         Don't append branch name in bare mode (true/false, default: false)"
        echo ""
        echo "Examples:"
        echo "  clone_worktree git@github.com:user/repo.git"
        echo "  clone_worktree user/repo"
        echo "  clone_worktree repo --org myorg"
        echo "  clone_worktree repo --parent myprojects"
        echo "  clone_worktree myorg/myrepo --root ~/Dev"
        echo "  clone_worktree user/very-long-repository-name --name short"
        echo "  clone_worktree user/repo --bare"
        echo "  clone_worktree user/repo --bare --flat"
        echo "  clone_worktree user/repo --bare --no-suffix"
        return 0
    end

    # Check if repo argument is provided
    if test (count $argv) -lt 1
        echo "Error: Repository argument is required"
        echo "Run 'clone_worktree --help' for usage information"
        return 1
    end

    set repo_input $argv[1]

    # Override code root if --root flag is provided
    if set -q _flag_root
        set code_root $_flag_root
    end

    # Override default org if --org flag is provided
    if set -q _flag_org
        set default_org $_flag_org
    end

    # Override parent folder if --parent flag is provided
    set parent_folder $default_parent
    if set -q _flag_parent
        set parent_folder $_flag_parent
    else
        # Check if we're already in a code root subdirectory
        set current_dir (pwd)
        if string match -q "$code_root/*" $current_dir
            # Use the entire path under code root as parent folder
            set parent_folder (string replace "$code_root/" "" $current_dir)
            echo "Detected current location in $code_root/$parent_folder"
        end
    end

    # Expand shorthand notation to full Git URL
    set git_url $repo_input

    # Check if input looks like a full URL (contains :// or starts with git@)
    if not string match -qr '^(https?://|git@|ssh://|[a-z]+://)' $repo_input
        # It's shorthand notation - expand it
        if string match -q '*/*' $repo_input
            # Format: user/repo
            set -l parts (string split '/' $repo_input)
            set -l user_part $parts[1]
            set -l repo_part $parts[2]
            set git_url "git@$default_server:$user_part/$repo_part.git"
        else if test -n "$default_org"
            # Format: repo (use default org)
            set git_url "git@$default_server:$default_org/$repo_input.git"
        else
            echo "Error: Shorthand 'repo' format requires CLONE_WORKTREE_ORG to be set"
            echo "Either set the environment variable or use 'user/repo' format"
            return 1
        end
        echo "Expanded to: $git_url"
    end

    # Extract project name from URL (remove .git extension)
    set project_name (string replace -r '.*/(.+?)(\.git)?$' '$1' $git_url)

    if test -z "$project_name"
        echo "Error: Could not extract project name from URL"
        return 1
    end

    # Override project name if --name flag is provided
    if set -q _flag_name
        set project_name $_flag_name
    end

    set base_path $code_root/$parent_folder

    # --- Branch: bare mode vs regular clone ---
    if set -q _flag_bare
        # === BARE REPO MODE ===
        # Determine flat mode
        set use_flat false
        if test "$default_flat" = "true"
            set use_flat true
        end
        if set -q _flag_flat
            set use_flat true
        end
        if set -q _flag_no_flat
            set use_flat false
        end

        # Determine branch suffix
        set use_branch_suffix true
        if test "$default_no_suffix" = "true"
            set use_branch_suffix false
        end
        if set -q _flag_no_suffix
            set use_branch_suffix false
        end

        # Set up paths based on flat mode
        if test "$use_flat" = "true"
            set git_path $base_path/$bare_name-$project_name
            set project_path $base_path
        else
            set project_path $base_path/$project_name
            set git_path $project_path/$bare_name
        end

        echo "Setting up bare worktree for: $project_name"
        echo "Location: $project_path"

        # Create project directory if not in flat mode
        if test "$use_flat" != "true"
            mkdir -p $project_path
            or begin
                echo "Error: Failed to create directory $project_path"
                return 1
            end
        end

        # Clone bare repository
        if test "$use_flat" = "true"
            git clone --bare $git_url $git_path
            or begin
                echo "Error: Failed to clone repository"
                return 1
            end
            cd $git_path
        else
            cd $project_path
            git clone --bare $git_url $bare_name
            or begin
                echo "Error: Failed to clone repository"
                return 1
            end
            cd $bare_name
        end

        # Determine default branch
        set default_branch (git symbolic-ref --short HEAD 2>/dev/null)
        if test -z "$default_branch"
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
        if test "$use_branch_suffix" = "true"
            set worktree_name "$project_name-$default_branch"
        else
            set worktree_name "$project_name"
        end

        git worktree add ../$worktree_name $default_branch
        or begin
            echo "Error: Failed to create worktree"
            return 1
        end

        set final_path (cd ../$worktree_name; and pwd)
        cd $final_path
        echo "Successfully set up bare worktree at: $final_path"
    else
        # === REGULAR CLONE MODE (default) ===
        set clone_target $base_path/$project_name

        if test -d $clone_target
            echo "Error: Directory already exists: $clone_target"
            return 1
        end

        mkdir -p $base_path
        or begin
            echo "Error: Failed to create directory $base_path"
            return 1
        end

        echo "Cloning $project_name..."
        echo "Location: $clone_target"

        git clone $git_url $clone_target
        or begin
            echo "Error: Failed to clone repository"
            return 1
        end

        cd $clone_target

        set default_branch (git symbolic-ref --short HEAD 2>/dev/null)
        if test -z "$default_branch"
            set default_branch "main"
        end

        echo "Successfully cloned to: $clone_target"
        echo "Branch: $default_branch"
        echo "Use 'git-worktree-new <branch>' to create worktrees"
    end
end
