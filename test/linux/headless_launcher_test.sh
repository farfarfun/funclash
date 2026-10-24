#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir "$fixture/bin"
cat > "$fixture/main.cc" <<'CPP'
#include "headless.h"
#include <cstdio>
int main(int argc, char** argv) {
  int status = launch_headless(argc, argv);
  if (status >= 0) return status;
  std::puts("GUI entry");
  return 0;
}
CPP
g++ -std=c++14 -Wall -Werror -I"$root/linux/runner" \
  "$fixture/main.cc" "$root/linux/runner/headless.cc" -o "$fixture/FunClash"
cp "$root/linux/runner/headless.sh" "$fixture/funclash-headless"
cat > "$fixture/bin/xvfb-run" <<'SH'
#!/bin/bash
[[ "$FUNCLASH_HEADLESS" == 1 && "$GDK_BACKEND" == x11 && "$LIBGL_ALWAYS_SOFTWARE" == 1 ]]
[[ ! -v WAYLAND_DISPLAY && ! -v DBUS_SESSION_BUS_ADDRESS ]]
[[ "$1" == --auto-servernum && "$2" == *'-nolisten tcp'* ]]
shift 2
exec "$@"
SH
cat > "$fixture/bin/dbus-run-session" <<'SH'
#!/bin/bash
[[ "$1" == -- ]]
shift
exec "$@"
SH
for name in Xvfb xauth; do
  cp "$fixture/bin/dbus-run-session" "$fixture/bin/$name"
done
chmod +x "$fixture/bin/"*
[[ "$(env -u DISPLAY -u WAYLAND_DISPLAY PATH="$fixture/bin:$PATH" "$fixture/FunClash" --headless --data-dir 'a directory')" == 'GUI entry' ]]
[[ "$(DISPLAY=:99 "$fixture/FunClash")" == 'GUI entry' ]]
[[ "$(env -u DISPLAY -u WAYLAND_DISPLAY "$fixture/FunClash" --help)" == *'--panel-url'* ]]
rm "$fixture/bin/xauth"
# A private PATH makes the missing dependency check independent of the host.
ln -s /bin/bash "$fixture/bin/bash"
if env -u DISPLAY -u WAYLAND_DISPLAY PATH="$fixture/bin" "$fixture/FunClash" >"$fixture/error" 2>&1; then
  echo 'Missing xauth unexpectedly succeeded' >&2
  exit 1
fi
grep -q 'Missing xauth' "$fixture/error"
echo 'Headless dispatch, environment and dependency checks passed'
