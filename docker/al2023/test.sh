#!/usr/bin/env bash
# Runs the real EC2 user_data script (rendered from provision.sh.tpl) inside an Amazon Linux 2023 container.
# What it covers that the Debian smoke test cannot: the dnf package names, the Tomcat download and checksum,
# useradd, paths and permissions, the systemd unit (via a stub that reads the real unit file), the Nginx
# configuration with AL2023's nginx package, and a second run of the script (idempotency).
# Usage: [INSTANCE_TYPE=public|author] [JVM_HEAP_MB=1536] [KEEP=1] docker/al2023/test.sh [host-port]   (default 8082). Requires Docker and python3.
# Writes docs/evidence/al2023-provision-test.txt (and al2023-diagnostics.txt on failure).
# shellcheck disable=SC2016,SC2329,SC2317  # single quotes are intended: the commands expand inside the container; cleanup runs via trap
set -euo pipefail
# The "[o]rg" pattern keeps pgrep -f from matching the bash -c process that runs the check itself.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${1:-8082}"
NAME="magnolia-al2023"
IMAGE="magnolia-al2023:test"
OUT="$ROOT/docs/evidence/al2023-provision-test.txt"
DIAG="$ROOT/docs/evidence/al2023-diagnostics.txt"
FULL="$ROOT/docs/evidence/al2023-provision.log"   # complete script output (git-ignored: *.log)
CTX="$(mktemp -d)"
FAILED=0

mkdir -p "$ROOT/docs/evidence"
: > "$OUT"
log() { echo "$*" | tee -a "$OUT"; }
in_ct() { docker exec "$NAME" bash -c "$1"; }
check() { # check "<description>" "<shell command run inside the container>"
  if in_ct "$2" >/dev/null 2>&1; then log "PASS  $1"; else log "FAIL  $1"; FAILED=1; fi
}

diagnostics() {
  {
    echo "# Diagnostics $(date -u +%FT%TZ)"
    echo "## processes";        docker exec "$NAME" ps aux 2>&1 | head -30 || true
    echo "## /var/log/provision.log (tail)"; docker exec "$NAME" tail -n 80 /var/log/provision.log 2>&1 || true
    echo "## systemctl stub calls";          docker exec "$NAME" cat /var/log/systemctl-stub.log 2>&1 || true
    echo "## tomcat stub output (tail)";     docker exec "$NAME" tail -n 80 /var/log/tomcat-stub.log 2>&1 || true
    echo "## /etc/tomcat.env";               docker exec "$NAME" cat /etc/tomcat.env 2>&1 || true
    echo "## nginx error log";               docker exec "$NAME" tail -n 40 /var/log/nginx/error.log 2>&1 || true
    echo "## Tomcat file permissions"
    docker exec "$NAME" sh -c 'namei -l /opt/tomcat/bin/catalina.sh; ls -l /opt/tomcat/bin/*.sh | head -5; id tomcat; runuser -u tomcat -- test -x /opt/tomcat/bin/catalina.sh && echo "tomcat can execute catalina.sh" || echo "tomcat can NOT execute catalina.sh"; mount | grep -E " /opt| / " | head -3' 2>&1 || true
    echo "## direct Tomcat probes"
    for p in / /.rest/status; do
      printf '%s -> ' "$p"; docker exec "$NAME" curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:8080$p" 2>&1 || true
    done
    echo "## SEVERE / ERROR lines (first 60)"
    docker exec "$NAME" sh -c 'grep -h -E "SEVERE|ERROR|Exception" /var/lib/tomcat/logs/*.log /var/log/magnolia/*.log 2>/dev/null | head -60' 2>&1 || true
  } > "$DIAG"
  log "Diagnostics written to docs/evidence/al2023-diagnostics.txt"
}

cleanup() {
  rm -rf "$CTX"
  if [ -z "${KEEP:-}" ]; then docker rm -f "$NAME" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT
docker rm -f "$NAME" >/dev/null 2>&1 || true

log "# Amazon Linux 2023 provisioning test $(date -u +%FT%TZ)"
python3 "$ROOT/docker/al2023/render.py" "$CTX/provision.sh"
bash -n "$CTX/provision.sh"
log "Rendered provision.sh.tpl ($(wc -c < "$CTX/provision.sh" | tr -d ' ') bytes, instance type ${INSTANCE_TYPE:-default}); bash syntax OK"
cp "$ROOT/docker/al2023/Dockerfile" "$ROOT/docker/al2023/systemctl-stub.sh" "$CTX/"
docker build -q -t "$IMAGE" "$CTX" >/dev/null
docker run -d --init --name "$NAME" -p "$PORT:80" "$IMAGE" sleep infinity >/dev/null
log "Container up: $(in_ct '. /etc/os-release && echo "$PRETTY_NAME"') ($(in_ct 'uname -m'))"

# --- First run: exactly what cloud-init would do on first boot ---
log "Running provision.sh (dnf install, Tomcat download, Magnolia first start: several minutes)..."
start=$(date +%s)
set +e
docker exec "$NAME" bash /root/provision.sh 2>&1 | tee "$FULL" | grep --line-buffered '^\[provision\]'
rc=${PIPESTATUS[0]}
set -e
elapsed=$(( $(date +%s) - start ))
log "provision.sh exit code: $rc after ${elapsed}s (full output: docs/evidence/al2023-provision.log)"
if [ "$rc" != 0 ]; then
  log "FAIL  provision.sh did not complete"
  diagnostics
  log "RESULT: failed; see docs/evidence/al2023-diagnostics.txt"
  exit 1
fi
log "PASS  provision.sh completed and Magnolia answered through Nginx"

# --- What the instance looks like afterwards ---
log "INFO  $(in_ct 'java -version 2>&1 | head -2 | tr "\n" " "')"
log "INFO  $(in_ct 'nginx -v 2>&1')"
log "INFO  Tomcat: $(in_ct 'readlink /opt/tomcat')"
check "Java is Amazon Corretto 11"                    'java -version 2>&1 | grep -q "Corretto-11"'
check "/opt/tomcat points at Tomcat 9.x"              'readlink /opt/tomcat | grep -q "apache-tomcat-9\."'
check "JAVA_HOME in /etc/tomcat.env has bin/java"     '. <(grep ^JAVA_HOME= /etc/tomcat.env); test -x "$JAVA_HOME/bin/java"'
check "Tomcat runs as the unprivileged user tomcat"   '[ "$(ps -o user= -p "$(pgrep -f "[o]rg.apache.catalina.startup.Bootstrap" | head -1)" | tr -d " ")" = tomcat ]'
check "Nginx workers run as nginx"                    'pgrep -u nginx -x nginx'
check "Tomcat answers on 127.0.0.1:8080"              'curl -s -o /dev/null --max-time 10 http://127.0.0.1:8080/.rest/status'
check "Tomcat is NOT reachable on the instance IP (loopback only)" \
  'ip=$(getent hosts "$(cat /etc/hostname)" | awk "{print \$1; exit}"); [ -n "$ip" ] && ! curl -s -o /dev/null --max-time 5 "http://$ip:8080/"'
check "GET /.rest/status returns 200 through Nginx (ALB health check path)" \
  '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/.rest/status)" = 200 ]'
check "GET /nginx-health returns 200"                 '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/nginx-health)" = 200 ]'
check "GET /.magnolia/ is blocked (403) by default"   '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/.magnolia/)" = 403 ]'
if [ "${INSTANCE_TYPE:-public}" = public ]; then
  check "anonymous visitors get the demo site (GET /travel/ is 200)" '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/travel/)" = 200 ]'
else
  check "author instance asks anonymous visitors to log in (401)"    '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/)" = 401 ]'
fi
check "redirects keep https when CloudFront-Forwarded-Proto=https" \
  '! curl -s -o /dev/null -D - -H "CloudFront-Forwarded-Proto: https" -H "Host: demo.example.com" http://127.0.0.1/ | tr -d "\r" | grep -i "^location: http://"'
check "Magnolia repository lives under /var/lib/magnolia, owned by tomcat" \
  '[ "$(find /var/lib/magnolia -type f | wc -l)" -gt 0 ] && [ -z "$(find /var/lib/magnolia ! -user tomcat | head -1)" ]'
check "Magnolia overrides appended exactly once"      '[ "$(grep -c "managed by Terraform" /var/lib/tomcat/webapps/ROOT/WEB-INF/config/default/magnolia.properties)" = 1 ]'
check "provision log written to /var/log/provision.log" 'grep -q "\[provision\] start" /var/log/provision.log'

# --- Second run: user_data must be safe to run again (re-run by hand, or a stop/start with a changed script) ---
log "Running provision.sh a second time (idempotency)..."
set +e
docker exec "$NAME" bash /root/provision.sh > "$CTX/second.out" 2>&1
rc2=$?
set -e
if [ "$rc2" = 0 ]; then log "PASS  second run exits 0"; else log "FAIL  second run exit code $rc2"; tail -n 20 "$CTX/second.out" | tee -a "$OUT"; FAILED=1; fi
check "second run did not append the overrides again" '[ "$(grep -c "managed by Terraform" /var/lib/tomcat/webapps/ROOT/WEB-INF/config/default/magnolia.properties)" = 1 ]'
check "second run did not start a second Tomcat"      '[ "$(pgrep -fc "[o]rg.apache.catalina.startup.Bootstrap")" = 1 ]'

if [ "$FAILED" != 0 ]; then diagnostics; fi
log ""
if [ "$FAILED" = 0 ]; then
  log "RESULT: all checks passed. Re-run with KEEP=1 to leave the container up and browse http://localhost:$PORT."
else
  log "RESULT: failures above; see docs/evidence/al2023-diagnostics.txt"
fi
exit "$FAILED"
