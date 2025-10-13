if test -d /opt/linuxbrew
#   set -xg HOMEBREWHOME /opt/linuxbrew
   /opt/linuxbrew/.linuxbrew/bin/brew shellenv | source
else if test -d /home/linuxbrew
#   set -xg HOMEBREWHOME /home/linuxbrew
   /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
else if test -d /url/local/bin/brew
   /usr/local/bin/brew shellenv | source
end

#if set -q HOMEBREWHOME
#   contains $HOMEBREWHOME/bin $fish_user_paths; or set -Ua fish_user_paths $HOMEBREWHOME/bin
#end
