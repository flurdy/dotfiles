
function parse_git_branch_and_add_brackets {
  git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\ \[\1\]/'
}

PS1="\[\e]2;\\W : \h \a\e\]\[\e[36;1m\]\u\[\e[32m\]@\[\e[31;1m\]\h \[\e[32m\]\W\$(parse_git_branch_and_add_brackets)\$\[\\e[0m\] "


MAVEN_OPTS='-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx2048m -XX:MaxPermSize=512m'

ANT_OPTS="-Xmx1512m -XX:MaxPermSize=1512m -XX:MaxPermSize=756m -XX:ReservedCodeCacheSize=64m -XX:+UseCompressedOops -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled"

# JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_11.jdk
JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_65.jdk
JDK_HOME=$JAVA_HOME

SBT_OPTS="-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:PermSize=256m -XX:MaxPermSize=1024m -XX:MaxMetaspaceSize=512m"

JAVA_TOOL_OPTIONS='-Djava.awt.headless=true'

# M2_HOME="/usr/share/maven" 
# HOMEBREW_GITHUB_API_TOKEN=123467890abcd

PATH=/usr/local/git/bin:~/bin:/usr/local/bin:$PATH

# source ~/bin/mvncolor.sh
source ~/.bash_aliases

# EDITOR='subl -w'
EDITOR='vi'

export DOCKER_HOST=tcp://192.168.59.103:2376
export DOCKER_CERT_PATH="$HOME/.boot2docker/certs/boot2docker-vm"
export DOCKER_TLS_VERIFY=1

