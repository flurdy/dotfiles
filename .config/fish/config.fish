
if begin
		begin
			test (count $fish_function_path) -lt 3 
			or test $fish_function_path[1] != "$HOME/.dotfiles/.config/fish/functions"
		end
	and begin
			test (count $fish_function_path) -lt 4 
			or test $fish_function_path[2] != "$HOME/.dotfiles/.config/fish/functions"
		end
	and begin
			test (count $fish_function_path) -lt 5 
			or test $fish_function_path[3] != "$HOME/.dotfiles/.config/fish/functions"
		end
	and begin
			test (count $fish_function_path) -lt 6
			or test $fish_function_path[4] != "$HOME/.dotfiles/.config/fish/functions"
		end
	end
	set -U fish_function_path $fish_function_path[1] $HOME/.dotfiles/.config/fish/functions $fish_function_path[(seq 2 (count $fish_function_path))]
end

set -xg JAVA8_HOME /Library/Java/JavaVirtualMachines/jdk1.8.0_60.jdk/Contents/Home
set -xg JAVA7_HOME /Library/Java/JavaVirtualMachines/jdk1.7.0_65.jdk/Contents/Home
set -xg JAVA6_HOME /System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home
set -xg JAVAMAC_HOME /Library/Java/Home
set -xg JAVA_HOME $JAVA7_HOME
set -xg JDK_HOME $JAVA_HOME

# set -xg M2_HOME "/usr/share/maven"

# set -xg JAVA_TOOL_OPTIONS '-Djava.awt.headless=true'

set -xg SBT_OPTS_COMMON "-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -Xmx4096m"
set -xg SBT_OPTS_JAVA8 "$SBT_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
set -xg SBT_OPTS_JAVA6 "$SBT_OPTS_COMMON -XX:PermSize=256m -XX:MaxPermSize=1024m"
set -xg SBT_OPTS $SBT_OPTS_JAVA8

set -xg MAVEN_OPTS_COMMON "-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx3076m -Djava.awt.headless=true"
set -xg MAVEN_OPTS_JAVA8 "$MAVEN_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
set -xg MAVEN_OPTS_JAVA6 "$MAVEN_OPTS_COMMON -XX:MaxPermSize=256m"
set -xg MAVEN_OPTS $MAVEN_OPTS_JAVA8

set -xg JAVA_OPTS_COMMON "-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx2048m"
set -xg JAVA_OPTS_JAVA8 "$JAVA_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
set -xg JAVA_OPTS_JAVA6 "$JAVA_OPTS_COMMON -XX:MaxPermSize=256m"
set -xg JAVA_OPTS $JAVA_OPTS_JAVA8

set -xg DOCKER_HOST_B2D tcp://192.168.59.103:2376
set -xg DOCKER_HOST_MACHINE tcp://192.168.99.100:2376
set -xg DOCKER_CERT_PATH_B2D $HOME/.boot2docker/certs/boot2docker-vm
set -xg DOCKER_CERT_PATH_MACHINE $HOME/.docker/machine/machines/dev
# set -xg DOCKER_CERT_PATH $DOCKER_CERT_PATH_B2D
# set -xg DOCKER_HOST $DOCKER_HOST_B2D
# set -xg DOCKER_TLS_VERIFY 1

set -xg AWS_DOCKER_VPC_ID  vpc
set -xg AWS_DOCKER_SUBNET_ID subnet
set -xg AWS_DOCKER_REGION us-east-1
set -xg AWS_DOCKER_ZONE a

set -xg GIT_MY_NAME Ola Nordmann 
set -xg GIT_MY_EMAIL ola@example.com

set -xg EDITOR 'vi'

set -Ux LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

set -xg PATH ~/bin $PATH 
set -xg PATH /usr/local/bin $PATH 
# set -xg PATH ~/Applications/google-cloud-sdk/bin $PATH 

