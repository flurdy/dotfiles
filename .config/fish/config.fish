##### Fish config by flurdy
##
## Not complete as part of hierichal configs similar to:
##   
## ~/.config/fish                           #  Machine specific conf
##  --> ~/.dotprivate/.config/fish          # User specific conf
##    --> ~/.dotfiles/.config/fish          # Common conf 
##
## In addition ~/config/fish/conf.d links to ~/.dotfiles/.config/fish/conf.d
## for App specific conf
##

#contains -- $HOME/.dotfiles/.config/fish/functions fish_function_path
#   or set -U fish_function_path $HOME/.dotfiles/.config/fish/functions $fish_function_path

#set -U fish_function_path $HOME/.dotfiles/.config/fish/functions (string match -v $HOME/.dotfiles/.config/fish/functions $fish_function_path)

# set -U fish_user_paths /snap/bin (string match -v /snap/bin $fish_user_paths)

if not set -q ARCH
	set -xg ARCH MAC
end
if not set -q JAVA8_VERSION 
   set -xg JAVA8_VERSION 112
end
if not set -q JAVA7_VERSION 
   set -xg JAVA7_VERSION 65 
end
if not set -q JAVA_VERSION 
   set -xg JAVA_VERSION 8
end

#setjava
#setsbt
#setmvn
# gojava8

set -xg EDITOR 'vi'

if not set --q WORKSPACE
   set -xg WORKSPACE $HOME/Code
end
if not set --q PAIR_PROJECT_WORKSPACE
   set -xg PAIR_PROJECT_WORKSPACE $WORKSPACE
end

if not set -q GIT_MY_NAME
   set -xg GIT_MY_NAME Ola Nordmann
end
if not set -q GIT_MY_EMAIL
   set -xg GIT_MY_EMAIL ola@example.com
end

contains -- /usr/local/bin PATH
   or set -xg PATH /usr/local/bin $PATH
contains -- $HOME/bin PATH
   or set -xg PATH $HOME/bin $PATH

# set -xg DOCKER_HOST_MAC
# set -xg DOCKER_HOST DOCKER_HOST_MAC
# set -xg DOCKER_CERT_PATH_MACHINE
# set -xg DOCKER_TLS_VERIFY 1
# set -xg DOCKER_ID_USER 1

if not set -q AWS_DOCKER_REGION
   set -xg AWS_DOCKER_REGION us-east-1
end
if not set -q AWS_DOCKER_ZONE
   set -xg AWS_DOCKER_ZONE a
end
if not set -q AWS_DOCKER_INSTANCE_TYPE
   set -xg AWS_DOCKER_INSTANCE_TYPE t2.micro
end

# set -xg KUBECONFIG $HOME/.kube/config:$HOME/.kube/client1.conf
set -e KUBECONFIG
set -xg FLUX_FORWARD_NAMESPACE flux

set -g theme_display_k8s_context yes
set -g fish_prompt_pwd_dir_length 3
set -g theme_display_hostname yes
set -g theme_display_git_untracked yes

