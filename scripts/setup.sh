#!/usr/bin/env bash
set -euo pipefail

# 支持的环境，status 不带环境参数时按此顺序逐个报告。
ENVIRONMENTS=(dev prod)

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

usage() {
  printf '%s\n' '用法: scripts/setup.sh {start|run|stop|restart} {dev|prod} [参数...]'
  printf '%s\n' '      scripts/setup.sh status [dev|prod] [参数...]   # 省略环境时报告所有环境'
  printf '%s\n' ''
  printf '%s\n' 'start 后台运行，run 前台运行。prod 只会执行已安装的正式 funclash 包。'
}

# 解析某个环境下应当执行的 launcher 命令，结果写入全局数组 launcher_cmd。
# prod 必须指向已安装的正式包：npm link 产生的软链会被 realpath 还原到源码树并被拒绝。
launcher_cmd=()
resolve_launcher() {
  local environment=$1
  if [[ "$environment" != "prod" ]]; then
    launcher_cmd=(node "$root_dir/launcher/bin/funclash.js")
    return 0
  fi

  local prod_launcher
  prod_launcher=$(command -v funclash || true)
  if [[ -z "$prod_launcher" ]]; then
    printf '%s\n' '错误: prod 环境要求已安装 funclash 正式包（cd launcher && npm pack && npm install -g ./funclash-*.tgz）。' >&2
    return 1
  fi
  prod_launcher=$(node -e 'process.stdout.write(require("fs").realpathSync(process.argv[1]))' "$prod_launcher")
  if [[ "$prod_launcher" == "$root_dir"/* ]]; then
    printf '%s\n' '错误: prod 环境不能使用源码树中的 funclash（npm link 的软链不算正式安装）。' >&2
    return 1
  fi
  launcher_cmd=("$prod_launcher")
  return 0
}

# 把一条生命周期操作派发给对应环境的 launcher。
# $1=环境 $2=动作，其余参数透传；exec_mode=1 时用 exec 顶替当前进程（单环境路径）。
dispatch() {
  local environment=$1 action=$2
  shift 2
  resolve_launcher "$environment" || return 1
  export FUNCLASH_RUN_DIR="$root_dir/.run/$environment"

  local -a argv
  case "$action" in
    start) argv=(start --daemon "$@") ;;
    run) argv=(start "$@") ;;
    *) argv=("$action" "$@") ;;
  esac

  if [[ "${exec_mode:-0}" == 1 ]]; then
    exec "${launcher_cmd[@]}" "${argv[@]}"
  fi
  "${launcher_cmd[@]}" "${argv[@]}"
}

command=${1:-}
case "$command" in
  start | run | stop | restart | status) shift ;;
  *)
    usage >&2
    exit 2
    ;;
esac

environment=${1:-}

# status 必须非交互：省略环境时报告所有已配置环境，而不是报错退出。
if [[ "$command" == status && -z "$environment" ]]; then
  exit_code=0
  for environment in "${ENVIRONMENTS[@]}"; do
    printf '== %s ==\n' "$environment"
    dispatch "$environment" status "$@" || exit_code=1
  done
  exit "$exit_code"
fi

if [[ "$environment" != "dev" && "$environment" != "prod" ]]; then
  printf '%s\n' "错误: 缺少或非法的环境参数 '${environment}'，必须是 dev 或 prod。" >&2
  usage >&2
  exit 2
fi
shift

exec_mode=1
dispatch "$environment" "$command" "$@"
