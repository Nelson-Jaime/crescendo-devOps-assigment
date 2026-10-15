#!/usr/bin/env bash
# Builds and runs the Nginx -> Tomcat -> Magnolia smoke test and writes evidence to docs/evidence/.
# Usage: [INSTANCE_TYPE=public|author] [JAVA_VERSION=11|17] [MAGNOLIA_WAR_URL=...] docker/smoke/test.sh [host-port]   (default 8081). Requires Docker.
# On failure it also writes docs/evidence/smoke-diagnostics.txt (logs, direct Tomcat probes).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${1:-8081}"
NAME="magnolia-smoke"
JAVA_VERSION="${JAVA_VERSION:-11}"
INSTANCE_TYPE="${INSTANCE_TYPE:-public}"
IMAGE="magnolia-smoke:java$JAVA_VERSION-$INSTANCE_TYPE"
BUILD_ARGS=(--build-arg "JAVA_VERSION=$JAVA_VERSION" --build-arg "INSTANCE_TYPE=$INSTANCE_TYPE")
if [ -n "${MAGNOLIA_WAR_URL:-}" ]; then BUILD_ARGS+=(--build-arg "MAGNOLIA_WAR_URL=$MAGNOLIA_WAR_URL"); fi
BASE="http://localhost:$PORT"
OUT="$ROOT/docs/evidence/smoke-test.txt"
DIAG="$ROOT/docs/evidence/smoke-diagnostics.txt"
FAILED=0

mkdir -p "$ROOT/docs/evidence"
: > "$OUT"
log() { echo "$*" | tee -a "$OUT"; }
check() { # check "<description>" <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then log "PASS  $desc"; else log "FAIL  $desc"; FAILED=1; fi
}

diagnostics() {
  {
    echo "# Diagnostics $(date -u +%FT%TZ)"
    echo "## java";      docker exec "$NAME" java -version 2>&1 || true
    echo "## processes"; docker exec "$NAME" ps aux 2>&1 | head -20 || true
    echo "## direct Tomcat probes (bypassing Nginx)"
    for p in / /.magnolia/admincentral /travel/ /.rest/status; do
      printf '%s -> ' "$p"
      docker exec "$NAME" curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "http://127.0.0.1:8080$p" 2>&1 || true
    done
    echo "## webapp layout"
    docker exec "$NAME" sh -c 'ls /var/lib/tomcat/webapps; ls /var/lib/tomcat/webapps/ROOT | head -20' 2>&1 || true
    echo "## magnolia.properties (overrides and instance type)"
    docker exec "$NAME" sh -c 'f=/var/lib/tomcat/webapps/ROOT/WEB-INF/config/default/magnolia.properties; grep -n -E "authorInstance|magnolia.repositories.home|magnolia.logs.dir" "$f"' 2>&1 || true
    echo "## log files"
    docker exec "$NAME" sh -c 'ls -la /var/lib/tomcat/logs /var/log/magnolia' 2>&1 || true
    echo "## SEVERE / ERROR / Exception lines (first 80)"
    docker exec "$NAME" sh -c 'grep -h -E "SEVERE|ERROR|Exception" /var/lib/tomcat/logs/*.log /var/log/magnolia/*.log 2>/dev/null | head -80' 2>&1 || true
    echo "## localhost log (full: contains the first Magnolia startup exception)"
    docker exec "$NAME" sh -c 'cat /var/lib/tomcat/logs/localhost.*.log' 2>&1 | cut -c1-400 | head -150 || true
    echo "## Magnolia log files"
    docker exec "$NAME" sh -c 'for f in /var/log/magnolia/*.log; do echo "--- $f"; head -80 "$f"; done' 2>&1 | cut -c1-400 || true
    echo "## container log (last 150 lines)"
    docker logs --tail 150 "$NAME" 2>&1 || true
  } > "$DIAG"
  log "Diagnostics written to docs/evidence/smoke-diagnostics.txt"
}

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

log "# Magnolia smoke test $(date -u +%FT%TZ)"
log "Building image with Java $JAVA_VERSION, Magnolia $INSTANCE_TYPE instance (downloads Magnolia CE WAR and verifies its checksum)..."
docker build -q "${BUILD_ARGS[@]}" -f "$ROOT/docker/smoke/Dockerfile" -t "$IMAGE" "$ROOT" >/dev/null
docker run -d --name "$NAME" -p "$PORT:80" "$IMAGE" >/dev/null

log "Waiting for Magnolia (first start installs the modules and demo content, can take several minutes)..."
code() { curl -s -o /dev/null -w '%{http_code}' "$BASE$1" || true; }
st=000; i=0; started=0; after_start=0
for i in $(seq 1 60); do
  st="$(code /.rest/status)"
  if [ "$st" = 200 ]; then break; fi   # Magnolia REST status answers 200 on author and public instances
  if ! docker ps -q -f "name=$NAME" | grep -q .; then log "FAIL  container exited"; diagnostics; exit 1; fi
  if docker logs "$NAME" 2>&1 | grep -q 'Server startup in'; then started=1; fi
  if [ "$started" = 1 ]; then after_start=$((after_start + 1)); fi
  if [ $((i % 6)) = 0 ]; then log "  ...waiting $((i * 10))s (/.rest/status HTTP $st, Tomcat started: $started)"; fi
  if [ "$after_start" -ge 60 ]; then log "Tomcat started but Magnolia is still not answering after 10 minutes: stopping"; break; fi
  sleep 10
done
log "Magnolia REST status: HTTP $st after about $((i * 10))s (instance type: $INSTANCE_TYPE)"

check "GET /.rest/status returns 200 through Nginx (ALB health check path)" bash -c "[ '$st' = 200 ]"
check "GET /nginx-health returns 200" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' $BASE/nginx-health)\" = 200 ]"
check "GET /.magnolia/ is blocked (403) by default" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' $BASE/.magnolia/)\" = 403 ]"

# What does a visitor get?
site=""
for p in / /travel/; do
  c="$(code "$p")"
  log "INFO  GET $p -> HTTP $c"
  if [ "$c" = 200 ] && [ -z "$site" ]; then site="$p"; fi
done
log "INFO  Response headers for /: $(curl -s -o /dev/null -D - "$BASE/" | tr -d '\r' | grep -i -E '^(HTTP|location|www-authenticate)' | tr '\n' ' ')"
if [ -n "$site" ]; then
  title="$(curl -s "$BASE$site" | grep -o '<title>[^<]*</title>' | head -1 || true)"
  log "INFO  Demo site at $site, title: ${title:-<none>}"
fi
if [ "$INSTANCE_TYPE" = public ]; then
  check "anonymous visitors get a public page (200) through Nginx" bash -c "[ -n '$site' ]"
else
  check "author instance asks anonymous visitors to log in (401), as designed" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' $BASE/)\" = 401 ]"
fi

# Proxy header handling: CloudFront reports https, the app must build https URLs.
for p in / /travel; do
  l="$(curl -s -o /dev/null -D - -H 'CloudFront-Forwarded-Proto: https' -H 'Host: demo.example.com' "$BASE$p" | tr -d '\r' | awk 'tolower($1)=="location:"{print $2}')"
  log "INFO  $p with CloudFront-Forwarded-Proto=https, Host=demo.example.com -> Location: ${l:-<none>}"
  if [[ "$l" == http://* ]]; then check "redirects must not downgrade to http ($p)" false; fi
done

files="$(docker exec "$NAME" sh -c 'find /var/lib/magnolia -type f 2>/dev/null | wc -l')"
log "INFO  Files under /var/lib/magnolia (repository location override): $files"
check "repository written outside the webapp (/var/lib/magnolia)" bash -c "[ '$files' -gt 0 ]"

if [ "$FAILED" != 0 ]; then diagnostics; fi
log ""
if [ "$FAILED" = 0 ]; then log "RESULT: all checks passed. Run 'docker run --rm -p $PORT:80 $IMAGE' to browse $BASE."; else log "RESULT: failures above; see docs/evidence/smoke-diagnostics.txt"; fi
exit "$FAILED"
