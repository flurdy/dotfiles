dotfiles
=====

My dotfiles


Initial steps
----
* cd ~/
* git clone https://github.com/flurdy/dotfiles.git ~/.dotfiles


Bash shell
----
* echo "source ~/.dotfiles/.bash_aliases" >> ~/.bash_aliases

* # if on osx
* echo "source ~/.dotfiles/.bash_profile" >> ~/.bash_profile
* echo "export PATH=~/.dotfiles/bin:$PATH >> ~/.bash_profile

* # if on linux 
* echo "source ~/.dotfiles/.bashrc" >> ~/.bashrc
* echo "export PATH=~/.dotfiles/bin:$PATH" >> ~/.bashrc


Fish shell
----
* mkdir -p ~/.config/fish/functions ~/.config/fish/completions
* echo "source ~/.dotfiles/.config/fish/config.fish" >> ~/.config/fish/config.fish
* echo "set -xg PATH ~/.dotfiles/bin $PATH >> ~/.config/fish/config.fish


Git
----
* echo "[include]" > ~/.gitconfignew
* echo "   path = ~/.dotfiles/.gitconfig" >> ~/.gitconfignew
* cat ~/.gitconfig >> ~/.gitconfignew
* mv ~/.gitconfignew ~/.gitconfig


Mercurial
----
* ln -s ~/.dotfiles/.hgrc ~/.hgrc


VIM
----
* mkdir -p ~/.vimtmp
* ln -s ~/.dotfiles/.vimrc ~/.vimrc


MAVEN
----
* mkdir -p ~/.m2
* ln -s ~/.dotfiles/.m2/settings.xml ~/.m2/settings.xml


SBT
----
* mkdir -p ~/.sbt/0.13
* ln -s ~/.dotfiles/.sbt/0.13/global.sbt ~/.sbt/0.13/global.sbt
* ln -s ~/.dotfiles/.sbt/0.13/plugins ~/.sbt/0.13/plugins
* ln -s ~/.dotfiles/.sbt/repositories ~/.sbt/repositories


SSH
----
* mkdir -p ~/.ssh
* chmod 700 ~/.ssh
* touch ~/.ssh/authorized_keys
* chmod 600 ~/.ssh/authorized_keys
* cp ~/.dotfiles/.ssh/config ~/.ssh/config


Private Dotfiles
----
You could also add another level of indirection by having a ~/.dotprivate folder for common but non public settings.
Such as public keys, api keys, usernames, etc.
The .dotprivate then usually source on to .dotfiles for simplicity.



