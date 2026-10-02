#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' '用法: scripts/setup.sh {start|run|stop|restart|status} {dev|prod} [参数...]'
}

command=${1:-}
if [[ -z "$command" ]]; then
  usage >&2
  exit 2
fi
shift

environment=${1:-}
if [[ "$environment" != "dev" && "$environment" != "prod" ]]; then
  usage >&2
  exit 2
fi
shift

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"
export FUNCLASH_RUN_DIR="$root_dir/.run/$environment"

if [[ "$environment" == "prod" ]]; then
  prod_launcher=$(command -v funclash || true)
  if [[ -z "$prod_launcher" ]]; then
    printf '%s\n' '错误: prod 环境要求已安装 funclash 正式包。' >&2
    exit 1
  fi
  prod_launcher=$(node -e 'process.stdout.write(require("fs").realpathSync(process.argv[1]))' "$prod_launcher")
  if [[ "$prod_launcher" == "$root_dir"/* ]]; then
    printf '%s\n' '错误: prod 环境不能使用当前源码树中的 funclash。' >&2
    exit 1
  fi
  launcher=("$prod_launcher")
else
  launcher=(node "$root_dir/launcher/bin/funclash.js")
fi

case "$command" in
  start) exec "${launcher[@]}" start --daemon "$@" ;;
  run) exec "${launcher[@]}" start "$@" ;;
  stop|restart|status) exec "${launcher[@]}" "$command" "$@" ;;
  *) usage >&2; exit 2 ;;
esac
