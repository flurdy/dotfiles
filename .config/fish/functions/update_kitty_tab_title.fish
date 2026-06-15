function update_kitty_tab_title --description 'Reset kitty tab title to the current shell location' --on-event fish_prompt
    status is-interactive; or return
    set -q KITTY_WINDOW_ID; or return

    set -l title (prompt_pwd)
    if test -z "$title"
        set title (pwd)
    end

    if type -q kitten
        kitten @ set-tab-title "" >/dev/null 2>&1; or kitten @ --to unix:@kitty set-tab-title "" >/dev/null 2>&1
    end

    printf "\e]30;%s\a" "$title" >/dev/tty 2>/dev/null
    printf "\e]2;%s\a" "$title" >/dev/tty 2>/dev/null
end
