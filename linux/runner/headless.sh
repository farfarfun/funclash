#!/usr/bin/env bash
set -euo pipefail

binary="$1"
shift
for dependency in xvfb-run Xvfb xauth dbus-run-session setsid; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Missing $dependency. Install xvfb, xauth, dbus and util-linux (Fedora: xorg-x11-server-Xvfb, xorg-x11-xauth, dbus-daemon, util-linux)." >&2
    exit 69
  fi
done
export FUNCLASH_HEADLESS=1
export GDK_BACKEND=x11
export LIBGL_ALWAYS_SOFTWARE=1
unset WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
session_dir="$(mktemp -d)"
cleanup() {
  rm -f "$session_dir/app.pid"
  rmdir "$session_dir"
}
stop() {
  local app_pid
  if read -r app_pid < "$session_dir/app.pid"; then
    kill -TERM "$app_pid" 2>/dev/null || true
  else
    kill -TERM -- "-$session_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap stop INT TERM
# Keep the display alive until Flutter has saved state and stopped its Core.
setsid xvfb-run --auto-servernum --server-args='-screen 0 1280x800x24 -nolisten tcp' \
  dbus-run-session -- bash -c 'pid_file="$1"; shift; echo "$$" > "$pid_file"; exec "$@"' \
  bash "$session_dir/app.pid" "$binary" -- "$@" &
session_pid=$!
status=0
wait "$session_pid" || status=$?
if kill -0 "$session_pid" 2>/dev/null; then
  wait "$session_pid" && status=0 || status=$?
fi
exit "$status"
