function setsbt
   set -xg SBT_OPTS_COMMON "-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -Xmx4096m"
   set -xg SBT_OPTS_JAVA8 "$SBT_OPTS_COMMON -XX:MaxMetaspaceSize=1024m"
   set -xg SBT_OPTS_JAVA6 "$SBT_OPTS_COMMON -XX:PermSize=256m -XX:MaxPermSize=1024m"
   set -xg SBT_OPTS $SBT_OPTS_JAVA8
end

