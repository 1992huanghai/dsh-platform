#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DSH_HOME="${DSH_HOME:-$ROOT/.dsh-home}"

mkdir -p "$DSH_HOME/skills"
cp "$ROOT/config/settings.yaml" "$DSH_HOME/settings.yaml"

for skill_dir in "$ROOT/skills"/*; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  rm -rf "$DSH_HOME/skills/$name"
  cp -R "$skill_dir" "$DSH_HOME/skills/$name"
done

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

if [ -z "${SILICONFLOW_API_KEY:-}" ]; then
  echo "未检测到 SILICONFLOW_API_KEY。请复制 config/env.example 为 .env 并填写 Key。" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "未找到 node。官方 dsh 需要 Node.js 22 或 24+（不要用 23）。" >&2
  exit 1
fi

node_major="$(node -p "process.versions.node.split('.')[0]")"
if [ "$node_major" = "23" ] || [ "$node_major" -lt 22 ]; then
  echo "当前 Node.js 是 $(node -v)。官方 dsh 需要 22 或 24+，且排除 23。" >&2
  exit 1
fi

cd "$ROOT"

if [ "$#" -gt 0 ]; then
  exec npx --yes @deepseek-ai/dsh "$@"
fi

exec npx --yes @deepseek-ai/dsh web
