#!/bin/bash
# Provisions Nginx + Tomcat 9 + Magnolia CE on Amazon Linux 2023.
# Rendered by Terraform (templatefile) and executed once by cloud-init as root.
# Note: literal "$${" and "%%{" below are Terraform escapes for shell/curl syntax.
set -euo pipefail
exec > >(tee -a /var/log/provision.log) 2>&1
echo "[provision] start $(date -u +%FT%TZ)"

TOMCAT_VERSION="${tomcat_version}"
MAGNOLIA_WAR_URL="${magnolia_war_url}"
CATALINA_HOME=/opt/tomcat
CATALINA_BASE=/var/lib/tomcat
MAGNOLIA_HOME=/var/lib/magnolia

retry() {
  local n=0
  until "$@"; do
    n=$((n + 1))
    if [ "$n" -ge 5 ]; then return 1; fi
    sleep $((n * 5))
  done
}

echo "[provision] installing packages"
retry dnf install -y nginx unzip ${java_package}

echo "[provision] creating service user"
id tomcat >/dev/null 2>&1 || useradd --system --home-dir "$CATALINA_BASE" --shell /sbin/nologin tomcat

echo "[provision] installing Tomcat $TOMCAT_VERSION (checksum verified)"
if [ ! -d "/opt/apache-tomcat-$TOMCAT_VERSION" ]; then
  TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
  retry curl -fsSL -o /tmp/tomcat.tgz "$TOMCAT_URL"
  retry curl -fsSL -o /tmp/tomcat.tgz.sha512 "$TOMCAT_URL.sha512"
  (cd /tmp && echo "$(cut -d' ' -f1 tomcat.tgz.sha512)  tomcat.tgz" | sha512sum -c -)
  tar -xzf /tmp/tomcat.tgz -C /opt
fi
ln -sfn "/opt/apache-tomcat-$TOMCAT_VERSION" "$CATALINA_HOME"
# The Apache tarball ships bin/ and conf/ as root-only (750) and bin/*.sh without the execute bit; the unprivileged
# tomcat user (and systemd) would fail with "Permission denied". Keep the install root-owned and read-only for others.
chmod -R go+rX "/opt/apache-tomcat-$TOMCAT_VERSION"
chmod 0755 "$CATALINA_HOME"/bin/*.sh

echo "[provision] preparing CATALINA_BASE"
install -d -o tomcat -g tomcat "$CATALINA_BASE" "$CATALINA_BASE/conf" "$CATALINA_BASE/logs" \
  "$CATALINA_BASE/temp" "$CATALINA_BASE/webapps" "$CATALINA_BASE/work"
cp -f "$CATALINA_HOME"/conf/catalina.properties "$CATALINA_HOME"/conf/context.xml \
  "$CATALINA_HOME"/conf/logging.properties "$CATALINA_HOME"/conf/web.xml "$CATALINA_BASE/conf/"
cat > "$CATALINA_BASE/conf/server.xml" <<'SERVER_XML'
${server_xml}
SERVER_XML

echo "[provision] deploying Magnolia as ROOT"
if [ ! -d "$CATALINA_BASE/webapps/ROOT/WEB-INF" ]; then
  retry curl -fsSL -o /tmp/magnolia.war "$MAGNOLIA_WAR_URL"
  retry curl -fsSL -o /tmp/magnolia.war.sha1 "$MAGNOLIA_WAR_URL.sha1"
  echo "$(cut -d' ' -f1 /tmp/magnolia.war.sha1)  /tmp/magnolia.war" | sha1sum -c -
  rm -rf "$CATALINA_BASE/webapps/ROOT"
  unzip -q /tmp/magnolia.war -d "$CATALINA_BASE/webapps/ROOT"
fi
# Magnolia creates only the last path element itself, so every directory named in magnolia-overrides.properties must exist.
install -d "$MAGNOLIA_HOME" "$MAGNOLIA_HOME/tmp/uploads" "$MAGNOLIA_HOME/cache" /var/log/magnolia
MAGNOLIA_PROPS="$CATALINA_BASE/webapps/ROOT/WEB-INF/config/default/magnolia.properties"
if ! grep -q "managed by Terraform" "$MAGNOLIA_PROPS"; then
  cat >> "$MAGNOLIA_PROPS" <<'MAGNOLIA_PROPS_EOF'
${magnolia_properties}
MAGNOLIA_PROPS_EOF
  echo "magnolia.bootstrap.authorInstance=${author_instance}" >> "$MAGNOLIA_PROPS"
fi

echo "[provision] writing Tomcat environment and systemd unit"
JAVA_HOME_DETECTED="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
cat > /etc/tomcat.env <<ENV_EOF
JAVA_HOME=$JAVA_HOME_DETECTED
CATALINA_HOME=$CATALINA_HOME
CATALINA_BASE=$CATALINA_BASE
CATALINA_OPTS=-Xms${heap_mb}m -Xmx${heap_mb}m -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/urandom
ENV_EOF
cat > /etc/systemd/system/tomcat.service <<'UNIT_EOF'
${tomcat_unit}
UNIT_EOF

echo "[provision] configuring Nginx"
cat > /etc/nginx/nginx.conf <<'NGINX_CONF_EOF'
${nginx_conf}
NGINX_CONF_EOF
cat > /etc/nginx/magnolia-admin.conf <<'NGINX_ADMIN_EOF'
${nginx_admin_conf}
NGINX_ADMIN_EOF
nginx -t

chown -R tomcat:tomcat "$CATALINA_BASE" "$MAGNOLIA_HOME" /var/log/magnolia
systemctl daemon-reload
systemctl enable --now tomcat nginx

echo "[provision] waiting for Magnolia to answer through Nginx (first start bootstraps the repository)"
wait_start=$SECONDS
for _ in $(seq 1 120); do
  code="$(curl -s -o /dev/null -w '%%{http_code}' http://127.0.0.1/.rest/status || true)"
  case "$code" in
    2*|3*)
      echo "[provision] Magnolia answering with HTTP $code after $((SECONDS - wait_start))s"
      exit 0
      ;;
  esac
  sleep 10
done
echo "[provision] ERROR: Magnolia not healthy after 20 minutes; see journalctl -u tomcat" >&2
exit 1
