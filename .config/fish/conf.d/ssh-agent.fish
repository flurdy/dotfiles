# Manage a manual ssh-agent only for INTERACTIVE shells.
#
# GDM launches the GNOME session through a non-interactive login shell
# (`fish -l -c "exec gnome-session"`). Running ssh-add there blocks on the key
# passphrase with no tty/askpass and deadlocks the whole login (blank screen,
# frozen cursor). Guarding on `status is-interactive` keeps this off that path.
#
# We also use session-global (`-gx`) vars, NOT universal (`-Ux`): a universal
# exported SSH_AUTH_SOCK persists to fish_variables and shadows the agent
# gnome-keyring provides at /run/user/1000/keyring/ssh in every future session.
if status is-interactive
    # ssh-add -l exit codes: 0 = has keys, 1 = agent up/no keys, 2 = no agent reachable
    if set -q SSH_AUTH_SOCK
        ssh-add -l >/dev/null 2>&1
        test $status -ne 2; and return          # an agent is already reachable (e.g. gnome-keyring)
        set -e SSH_AUTH_SOCK SSH_AGENT_PID
    end

    echo "Starting standalone ssh-agent..."
    eval (ssh-agent -c)
    set -gx SSH_AUTH_SOCK $SSH_AUTH_SOCK
    set -gx SSH_AGENT_PID $SSH_AGENT_PID

    for key in $SSH_KEY_PATHS                     # id_blc, id_rsa (from 001-ssh-keys.fish)
        test -f $key; and ssh-add $key
    end
end
