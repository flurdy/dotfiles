function setmvn
   set -xg MAVEN_OPTS_COMMON "-XX:+CMSClassUnloadingEnabled -XX:+UseCompressedOops -Xms128m -Xmx3076m -     Djava.awt.headless=true"
   set -xg MAVEN_OPTS_JAVA8 "$MAVEN_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
   set -xg MAVEN_OPTS_JAVA6 "$MAVEN_OPTS_COMMON -XX:MaxPermSize=256m"
   set -xg MAVEN_OPTS $MAVEN_OPTS_JAVA8
end

