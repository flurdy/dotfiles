dotfiles
=====

Template configuration files for users


Initial steps
----
* cd ~/
* git clone https://github.com/flurdy/dotfiles.git ~/.dotfiles
* mkdir -p .vimtmp .m2 .sbt/0.13 .config/fish
* ln -s .dotfiles/bin
* ln -s .dotfiles/.gitconfig
* ln -s .dotfiles/.hgrc
* echo "source ~/.dotfiles/.config/fish/config.fish" >> .config/fish/config.fish
* echo "source ~/.dotfiles/.bash_aliases" >> .bash_aliases
* # if on osx
* echo "source ~/.dotfiles/.bash_profile" >> .bash_profile
* # if on linux 
* echo "source ~/.dotfiles/.bashrc" >> .bashrc
* ln -s .dotfiles/.vimrc
* ln -s .dotfiles/.sbt/0.13/plugins .sbt/0.13/plugins
* ln -s .dotfiles/.sbt/repositories .sbt/repositories
* ln -s .dotfiles/.m2/settings.xml .m2/settings.xml
* cp .dotfiles/.ssh/config .ssh/config

You could also add another level of inderiection by having a .dotprivate folder for common but non public settings.

