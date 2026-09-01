function cl --description 'Claude launcher delegated to canonical ai-tools implementation'
    set -l root "$AI_TOOLS_HOME"
    if test -z "$root"
        if set -q XDG_DATA_HOME
            set root "$XDG_DATA_HOME/ai-tools"
        else
            set root "$HOME/.local/share/ai-tools"
        end
    end
    if not test -d "$root"; and test -d "$HOME/Code/flurdy/ai-tools"
        set root "$HOME/Code/flurdy/ai-tools"
    end
    set -l implementation "$root/claude/launcher/cl.fish"
    if not test -r "$implementation"
        echo "cl: canonical ai-tools launcher is unavailable at $implementation; set AI_TOOLS_HOME" >&2
        return 127
    end
    command fish -c 'source $argv[1]; cl $argv[2..-1]' -- "$implementation" $argv
end
