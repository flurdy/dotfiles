dotfiles
=====

Template configuration files for users


Initial steps
----
* cd ~/
* git clone https://github.com/flurdy/dotfiles.git ~/.dotfiles
* mkdir -p .vmtmp .m2 .sbt/0.13
* ln -s .dotfiles/bin
* ln -s .dotfiles/.gitconfig
* ln -s .dotfiles/.hgrc
* ln -s .dotfiles/.bash_aliases
* # if on osx:   ln -s .dotfiles/.bash_profile
* # if on linux: ln -s .dotfiles/.bashrc 
* ln -s .dotfiles/.vimrc
* ln -s .dotfiles/.sbt/0.13/plugins .sbt/0.13/plugins
* ln -s .dotfiles/.sbt/repositories .sbt/repositories
* ln -s .dotfiles/.m2/settings.xml .m2/settings.xml
* cp .dotfiles/.ssh/config .ssh/config



