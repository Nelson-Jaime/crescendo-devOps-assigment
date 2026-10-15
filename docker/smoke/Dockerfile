# Local smoke test of the application layer: Nginx -> Tomcat 9 -> Magnolia CE.
# Uses the exact config files Terraform ships to the instance (infra/modules/compute/files/).
# Build from the repository root: docker build -f docker/smoke/Dockerfile .
ARG JAVA_VERSION=11
FROM tomcat:9.0-jre${JAVA_VERSION}-temurin

ARG MAGNOLIA_WAR_URL=https://nexus.magnolia-cms.com/repository/magnolia.public.releases/info/magnolia/bundle/magnolia-community-demo-webapp/6.2/magnolia-community-demo-webapp-6.2.war

RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx unzip curl ca-certificates procps \
 && rm -rf /var/lib/apt/lists/* \
 && (id nginx >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin nginx) \
 && useradd --system --home-dir /var/lib/tomcat --shell /usr/sbin/nologin tomcat

ENV CATALINA_BASE=/var/lib/tomcat

# Same layout as the EC2 instance: read-only CATALINA_HOME, writable CATALINA_BASE.
RUN install -d -o tomcat -g tomcat "$CATALINA_BASE" "$CATALINA_BASE/conf" "$CATALINA_BASE/logs" \
      "$CATALINA_BASE/temp" "$CATALINA_BASE/webapps" "$CATALINA_BASE/work" \
 && cp -f "$CATALINA_HOME"/conf/catalina.properties "$CATALINA_HOME"/conf/context.xml \
      "$CATALINA_HOME"/conf/logging.properties "$CATALINA_HOME"/conf/web.xml "$CATALINA_BASE/conf/"
COPY infra/modules/compute/files/server.xml /var/lib/tomcat/conf/server.xml

# Deploy the WAR as ROOT with checksum verification, like the provisioning script.
RUN curl -fsSL -o /tmp/magnolia.war "$MAGNOLIA_WAR_URL" \
 && curl -fsSL -o /tmp/magnolia.war.sha1 "$MAGNOLIA_WAR_URL.sha1" \
 && echo "$(cut -d' ' -f1 /tmp/magnolia.war.sha1)  /tmp/magnolia.war" | sha1sum -c - \
 && unzip -q /tmp/magnolia.war -d "$CATALINA_BASE/webapps/ROOT" \
 && rm /tmp/magnolia.war /tmp/magnolia.war.sha1 \
 && install -d /var/lib/magnolia /var/lib/magnolia/tmp/uploads /var/lib/magnolia/cache /var/log/magnolia
ARG INSTANCE_TYPE=public
COPY infra/modules/compute/files/magnolia-overrides.properties /tmp/magnolia-overrides.properties
RUN cat /tmp/magnolia-overrides.properties >> "$CATALINA_BASE/webapps/ROOT/WEB-INF/config/default/magnolia.properties" \
 && echo "magnolia.bootstrap.authorInstance=$([ "$INSTANCE_TYPE" = author ] && echo true || echo false)" >> "$CATALINA_BASE/webapps/ROOT/WEB-INF/config/default/magnolia.properties" \
 && chown -R tomcat:tomcat "$CATALINA_BASE" /var/lib/magnolia /var/log/magnolia

COPY infra/modules/compute/files/nginx.conf /etc/nginx/nginx.conf
COPY infra/modules/compute/files/nginx-admin-blocked.conf /etc/nginx/magnolia-admin.conf
RUN nginx -t

COPY docker/smoke/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
