#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' '用法: scripts/setup.sh {start|run|stop|restart|status} [dev|prod] [参数...]'
}

command=${1:-}
if [[ -z "$command" ]]; then
  usage >&2
  exit 2
fi
shift

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

case "${1:-}" in
  dev|prod) shift ;;
esac

case "$command" in
  start) exec node launcher/bin/funclash.js start --daemon "$@" ;;
  run) exec node launcher/bin/funclash.js start "$@" ;;
  stop|restart|status) exec node launcher/bin/funclash.js "$command" "$@" ;;
  *) usage >&2; exit 2 ;;
esac
