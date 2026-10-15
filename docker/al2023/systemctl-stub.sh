#!/usr/bin/env bash
# Stand-in for systemctl in the Amazon Linux 2023 test container (systemd is not PID 1 there).
# It emulates only what provision.sh.tpl calls: `daemon-reload` and `enable --now <unit>...`.
# It reads the REAL unit files, so a wrong User=, EnvironmentFile= or ExecStart= still fails the test.
# Not emulated: sandboxing options (NoNewPrivileges, PrivateTmp, ProtectSystem), Restart=, ordering.
set -euo pipefail

LOG=/var/log/systemctl-stub.log
echo "systemctl $*" >> "$LOG"

unit_file() {
  local d
  for d in /etc/systemd/system /usr/lib/systemd/system; do
    if [ -f "$d/$1.service" ]; then echo "$d/$1.service"; return 0; fi
  done
  echo "systemctl-stub: unit $1.service not found" >&2
  return 1
}

unit_key() { sed -n "s/^$2=//p" "$1" | head -1; }

start_tomcat() {
  local f user envfile exec_start umask_value nofile
  f="$(unit_file tomcat)"
  user="$(unit_key "$f" User)"
  envfile="$(unit_key "$f" EnvironmentFile)"
  exec_start="$(unit_key "$f" ExecStart)"
  umask_value="$(unit_key "$f" UMask)"
  nofile="$(unit_key "$f" LimitNOFILE)"
  [ -r "$envfile" ] || { echo "systemctl-stub: EnvironmentFile $envfile missing" >&2; return 1; }
  [ -x "${exec_start%% *}" ] || { echo "systemctl-stub: ExecStart ${exec_start%% *} not executable" >&2; return 1; }
  id "$user" >/dev/null

  if pgrep -f org.apache.catalina.startup.Bootstrap >/dev/null; then return 0; fi

  local -a envs
  mapfile -t envs < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$envfile")
  # Clean environment like systemd's: only the EnvironmentFile and a default PATH.
  setsid nohup runuser -u "$user" -- env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin "${envs[@]}" \
    bash -c "umask ${umask_value:-0022}; ulimit -n ${nofile:-1024} 2>/dev/null || true; exec $exec_start" \
    >> /var/log/tomcat-stub.log 2>&1 < /dev/null &
  # Fail fast (systemd would restart it): a Tomcat that dies at once means a broken unit or environment.
  sleep 5
  if ! pgrep -f org.apache.catalina.startup.Bootstrap >/dev/null; then
    echo "systemctl-stub: tomcat exited right after start; last log lines:" >&2
    tail -n 30 /var/log/tomcat-stub.log >&2 || true
    return 1
  fi
}

start_nginx() {
  unit_file nginx >/dev/null
  if pgrep -x nginx >/dev/null; then return 0; fi
  nginx
}

case "${1:-}" in
  daemon-reload) ;;
  enable)
    [ "${2:-}" = "--now" ] || { echo "systemctl-stub: only 'enable --now' is supported" >&2; exit 1; }
    shift 2
    for unit in "$@"; do
      case "$unit" in
        tomcat) start_tomcat ;;
        nginx) start_nginx ;;
        *) echo "systemctl-stub: unsupported unit $unit" >&2; exit 1 ;;
      esac
    done
    ;;
  *) echo "systemctl-stub: unsupported command: $*" >&2; exit 1 ;;
esac
