if test -d /home/linuxbrew/.linuxbrew/opt/sdkman-cli/libexec
   set -g __sdkman_custom_dir /home/linuxbrew/.linuxbrew/opt/sdkman-cli/libexec
else if test -d $HOME/.sdkman/bin
   set -g __sdkman_custom_dir $HOME/.sdkman
end
