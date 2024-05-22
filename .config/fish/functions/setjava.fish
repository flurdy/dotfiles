function setjava
   set -xg JAVA_OPTS_COMMON "-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx2048m"
   set -xg JAVA17_OPTS "$JAVA_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
   set -xg JAVA11_OPTS "$JAVA_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
   set -xg JAVA8_OPTS "$JAVA_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
   set -xg JAVA6_OPTS "$JAVA_OPTS_COMMON -XX:MaxPermSize=256m"
	set -xg JAVA_OPTS $JAVA8_OPTS
	set -xg MAC_JAVA8_HOME /Library/Java/JavaVirtualMachines/jdk1.8.0_$JAVA8_VERSION.jdk/Contents/Home
	set -xg MAC_JAVA7_HOME /Library/Java/JavaVirtualMachines/jdk1.7.0_$JAVA7_VERSION.jdk/Contents/Home
	set -xg MAC_JAVA6_HOME /Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home
# set -xg MAC_JAVA_HOME /Library/Java/Home
	set -xg LINUX_JAVA17_HOME /usr/lib/jvm/java-8-openjdk-amd64
	set -xg LINUX_JAVA11_HOME /usr/lib/jvm/java-8-openjdk-amd64
	set -xg LINUX_JAVA8_HOME /usr/lib/jvm/java-8-openjdk-amd64
	set -xg LINUX_JAVA7_HOME /usr/lib/jvm/java-7-oracle
	set -xg LINUX_JAVA6_HOME /usr/lib/jvm/java-6-oracle
	set -xg JAVA17_HOME $LINUX_JAVA17_HOME
	set -xg JAVA11_HOME $LINUX_JAVA11_HOME
	set -xg JAVA8_HOME $LINUX_JAVA8_HOME
	set -xg JAVA7_HOME $MAC_JAVA7_HOME
	set -xg JAVA6_HOME $MAC_JAVA6_HOME
	set -xg JAVA_HOME $JAVA8_HOME
	set -xg JDK_HOME $JAVA_HOME
end
