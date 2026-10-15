#!/bin/bash
# Runs Tomcat (as the tomcat user) and Nginx in one container, like the single EC2 instance.
set -euo pipefail

export CATALINA_OPTS="${CATALINA_OPTS:--Xms1024m -Xmx1024m -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/urandom}"

runuser -u tomcat -- env \
  JAVA_HOME="$JAVA_HOME" CATALINA_HOME="$CATALINA_HOME" CATALINA_BASE="$CATALINA_BASE" CATALINA_OPTS="$CATALINA_OPTS" \
  "$CATALINA_HOME/bin/catalina.sh" run &
nginx -g 'daemon off;' &

# Exit (and let Docker report it) as soon as either process dies.
wait -n
exit $?
