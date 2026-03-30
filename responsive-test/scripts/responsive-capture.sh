#!/usr/bin/env bash
#
# responsive-capture.sh — 多端响应式截图采集
#
# 使用 playwright-cli 在 desktop / tablet / mobile 三种视口下
# 对目标 URL 截图 + 采集 accessibility snapshot。
#
# 用法:
#   bash responsive-capture.sh <url> [output_dir]
#
# 参数:
#   url        — 目标页面地址（必填）
#   output_dir — 截图输出目录（可选，默认 ./responsive-test-output）
#
# 输出:
#   {output_dir}/desktop-screenshot.png
#   {output_dir}/desktop-snapshot.yml
#   {output_dir}/tablet-screenshot.png
#   {output_dir}/tablet-snapshot.yml
#   {output_dir}/mobile-screenshot.png
#   {output_dir}/mobile-snapshot.yml
#
# 依赖: npx @playwright/cli@latest

set -euo pipefail

URL="${1:?Usage: responsive-capture.sh <url> [output_dir]}"
OUTPUT_DIR="${2:-./responsive-test-output}"

mkdir -p "$OUTPUT_DIR"

# playwright-cli 命令（优先全局，fallback 到 npx）
if command -v playwright-cli &>/dev/null; then
  CLI="playwright-cli"
else
  CLI="npx --yes @playwright/cli@latest"
fi

# === 设备配置 ===
# 格式: "label|width|height|userAgent_suffix|deviceScaleFactor|isMobile"
DEVICES=(
  "desktop|1440|900|desktop|1|false"
  "tablet|768|1024|iPad|2|false"
  "mobile|375|812|iPhone|3|true"
)

for device_spec in "${DEVICES[@]}"; do
  IFS='|' read -r label width height ua_suffix scale is_mobile <<< "$device_spec"

  echo "═══════════════════════════════════════════"
  echo "  📱 Testing: ${label} (${width}×${height})"
  echo "═══════════════════════════════════════════"

  SESSION="responsive-${label}"

  # 构建配置文件
  CONFIG_FILE="${OUTPUT_DIR}/${label}-config.json"
  cat > "$CONFIG_FILE" <<EOF
{
  "browser": {
    "browserName": "chromium",
    "contextOptions": {
      "viewport": { "width": ${width}, "height": ${height} },
      "deviceScaleFactor": ${scale},
      "isMobile": ${is_mobile}
    }
  },
  "outputDir": "${OUTPUT_DIR}",
  "outputMode": "file"
}
EOF

  # 打开浏览器并导航
  $CLI -s="${SESSION}" --config="${CONFIG_FILE}" open "${URL}" 2>/dev/null || true

  # 等待页面加载
  sleep 3

  # 截图
  $CLI -s="${SESSION}" screenshot --filename="${OUTPUT_DIR}/${label}-screenshot.png" 2>/dev/null || true

  # 采集快照
  $CLI -s="${SESSION}" snapshot --filename="${OUTPUT_DIR}/${label}-snapshot.yml" 2>/dev/null || true

  # 采集 console 日志（捕获布局相关的警告/错误）
  $CLI -s="${SESSION}" console warning > "${OUTPUT_DIR}/${label}-console.log" 2>/dev/null || true

  # 关闭会话
  $CLI -s="${SESSION}" close 2>/dev/null || true

  # 清理配置文件
  rm -f "$CONFIG_FILE"

  echo "  ✅ ${label}: screenshot + snapshot saved"
  echo ""
done

echo "═══════════════════════════════════════════"
echo "  📂 All outputs saved to: ${OUTPUT_DIR}"
echo "═══════════════════════════════════════════"
ls -la "${OUTPUT_DIR}"/*.png 2>/dev/null || echo "  (no screenshots captured)"
