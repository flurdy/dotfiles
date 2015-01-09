
set -xg JAVA_HOME /Library/Java/JavaVirtualMachines/jdk1.8.0_11.jdk/Contents/Home
# JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_65.jdk/Contents/Home
# JAVA_HOME=/System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home
# JAVA_HOME=/Library/Java/Home
set -xg JDK_HOME $JAVA_HOME
# M2_HOME="/usr/share/maven"

set -xg SBT_OPTS "-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:PermSize=256m -XX:MaxPermSize=1024m -Xmx4096m -XX:MaxMetaspaceSize=1024m"

set -xg JAVA_TOOL_OPTIONS '-Djava.awt.headless=true'

set -xg MAVEN_OPTS '-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx2048m -XX:MaxPermSize=256m -XX:MaxMetaspaceSize=1024m -Djava.awt.headless=true'
set -xg JAVA_OPTS '-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx2048m -XX:MaxPermSize=256m -XX:MaxMetaspaceSize=1024m'

set -xg DOCKER_HOST tcp://192.168.59.103:2376
set -xg DOCKER_CERT_PATH /Users/myuser/.boot2docker/certs/boot2docker-vm
set -xg DOCKER_TLS_VERIFY 1

set -xg EDITOR 'vi'

set -Ux LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

set -xg PATH ~/bin $PATH 
set -xg PATH ~/Applications/google-cloud-sdk/bin $PATH 
