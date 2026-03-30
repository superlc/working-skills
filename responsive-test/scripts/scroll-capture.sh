#!/usr/bin/env bash
#
# scroll-capture.sh — 滚动截图采集
#
# 在已打开的 playwright-cli 会话中，对页面不同滚动位置截图。
# 适用于长页面需要验证折叠/展开、懒加载、sticky 元素等场景。
#
# 用法:
#   bash scroll-capture.sh <session> <output_dir> <label> [scroll_count]
#
# 参数:
#   session      — playwright-cli 会话名
#   output_dir   — 输出目录
#   label        — 截图前缀标签（如 desktop / mobile）
#   scroll_count — 滚动次数（默认 3）

set -euo pipefail

SESSION="${1:?Usage: scroll-capture.sh <session> <output_dir> <label> [scroll_count]}"
OUTPUT_DIR="${2:?output_dir required}"
LABEL="${3:?label required}"
SCROLL_COUNT="${4:-3}"

if command -v playwright-cli &>/dev/null; then
  CLI="playwright-cli"
else
  CLI="npx --yes @playwright/cli@latest"
fi

mkdir -p "$OUTPUT_DIR"

for i in $(seq 1 "$SCROLL_COUNT"); do
  # 每次向下滚动一个视口高度
  $CLI -s="${SESSION}" eval "window.scrollBy(0, window.innerHeight)" 2>/dev/null || true
  sleep 1
  $CLI -s="${SESSION}" screenshot --filename="${OUTPUT_DIR}/${LABEL}-scroll-${i}.png" 2>/dev/null || true
  echo "  📸 ${LABEL}-scroll-${i}.png captured"
done
