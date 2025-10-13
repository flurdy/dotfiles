function cursor
    # List of possible locations for the Cursor executable
    set -l possible_paths \
        /usr/bin/cursor \
        /usr/local/bin/cursor \
        /opt/cursor/cursor \
        $HOME/.local/bin/cursor

    # Find the first executable Cursor
    set -l cursor_bin
    for path in $possible_paths
        if test -x $path
            set cursor_bin $path
            break
        end
    end

    # Fall back to PATH if not found yet
    if not set -q cursor_bin
        if type -q cursor
            set cursor_bin (command -v cursor)
        end
    end

    # Error out if still not found
    if not set -q cursor_bin
        echo "Error: Cursor not found in known locations or PATH." >&2
        return 1
    end

    # Launch Cursor quietly in the background
    if test (count $argv) -eq 0
        nohup $cursor_bin > /dev/null 2>&1 & disown
    else
        nohup $cursor_bin $argv > /dev/null 2>&1 & disown
    end
end
