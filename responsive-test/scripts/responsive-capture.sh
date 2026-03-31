#!/usr/bin/env bash
#
# responsive-capture.sh — 多端响应式截图采集（增强版）
#
# 使用 playwright-cli 在 desktop / tablet / mobile 三种视口下
# 对目标 URL 截图 + 采集 accessibility snapshot + 采集布局量化指标。
# 支持可选的前置操作脚本和中间断点扩展设备。
#
# 用法:
#   bash responsive-capture.sh <url> [output_dir] [pre_actions_script] [extra_devices]
#
# 参数:
#   url                — 目标页面地址（必填）
#   output_dir         — 截图输出目录（可选，默认 ./responsive-test-output）
#   pre_actions_script — 前置操作脚本路径（可选）
#   extra_devices      — 额外设备配置（可选，逗号分隔的 "label|width|height|scale|isMobile"）
#
# 输出（每端）:
#   {output_dir}/{label}-screenshot.png    — 首屏截图
#   {output_dir}/{label}-snapshot.yml      — accessibility snapshot
#   {output_dir}/{label}-console.log       — 控制台警告日志
#   {output_dir}/{label}-metrics.json      — 布局量化指标
#   {output_dir}/{label}-scroll-{n}.png    — 滚动截图（若页面超过 1 屏）
#   {output_dir}/{label}-pre-snapshot.yml  — 前置操作前快照（仅有前置操作时）
#   {output_dir}/{label}-error.png         — 错误状态截图（仅操作失败时）
#
# 日志:
#   {output_dir}/capture.log               — 采集过程完整日志（含错误信息）
#
# 依赖: npx @playwright/cli@latest

set -euo pipefail

URL="${1:?Usage: responsive-capture.sh <url> [output_dir] [pre_actions_script] [extra_devices]}"
OUTPUT_DIR="${2:-./responsive-test-output}"
PRE_ACTIONS_SCRIPT="${3:-}"
EXTRA_DEVICES="${4:-}"

# 获取脚本所在目录（用于定位 layout-metrics.js）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_JS="${SCRIPT_DIR}/layout-metrics.js"

mkdir -p "$OUTPUT_DIR"

# 日志文件 — 所有 stderr 重定向到此文件而不是 /dev/null
LOG_FILE="${OUTPUT_DIR}/capture.log"
echo "=== Responsive Capture Log ===" > "$LOG_FILE"
echo "URL: ${URL}" >> "$LOG_FILE"
echo "Time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOG_FILE"
echo "==============================" >> "$LOG_FILE"

# playwright-cli 命令（优先全局，fallback 到 npx）
if command -v playwright-cli &>/dev/null; then
  CLI="playwright-cli"
else
  CLI="npx --yes @playwright/cli@latest"
fi

echo "CLI: ${CLI}" >> "$LOG_FILE"

# === 标准三端设备配置 ===
# 格式: "label|width|height|deviceScaleFactor|isMobile"
DEVICES=(
  "desktop|1440|900|1|false"
  "tablet|768|1024|2|true"
  "mobile|375|812|3|true"
)

# 追加额外设备（用于中间断点测试）
if [[ -n "$EXTRA_DEVICES" ]]; then
  IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_DEVICES"
  DEVICES+=("${EXTRA_ARRAY[@]}")
fi

# 滚动截图函数
scroll_capture() {
  local session="$1"
  local out_dir="$2"
  local label="$3"
  local scroll_count="$4"

  for i in $(seq 1 "$scroll_count"); do
    $CLI -s="${session}" eval "window.scrollBy(0, window.innerHeight)" 2>>"$LOG_FILE" || true
    sleep 1
    $CLI -s="${session}" screenshot --filename="${out_dir}/${label}-scroll-${i}.png" 2>>"$LOG_FILE" || true
    echo "  📸 ${label}-scroll-${i}.png captured"
  done

  # 滚动回顶部（恢复状态）
  $CLI -s="${session}" eval "window.scrollTo(0, 0)" 2>>"$LOG_FILE" || true
  sleep 0.5
}

# 布局指标采集函数
capture_metrics() {
  local session="$1"
  local out_dir="$2"
  local label="$3"

  if [[ -f "$METRICS_JS" ]]; then
    echo "  📊 Collecting layout metrics..." | tee -a "$LOG_FILE"
    $CLI -s="${session}" eval "$(cat "$METRICS_JS")" > "${out_dir}/${label}-metrics.json" 2>>"$LOG_FILE" || {
      echo "  ⚠️  Metrics collection failed for ${label}" | tee -a "$LOG_FILE"
      echo '{"error": "metrics collection failed"}' > "${out_dir}/${label}-metrics.json"
    }
  else
    echo "  ⚠️  layout-metrics.js not found at ${METRICS_JS}" | tee -a "$LOG_FILE"
  fi
}

# 验证截图文件是否有效
validate_screenshot() {
  local filepath="$1"
  local label="$2"

  if [[ ! -f "$filepath" ]]; then
    echo "  ❌ ${label}: Screenshot file not created!" | tee -a "$LOG_FILE"
    return 1
  fi

  local filesize
  filesize=$(wc -c < "$filepath" 2>/dev/null || echo "0")
  if [[ "$filesize" -lt 1000 ]]; then
    echo "  ❌ ${label}: Screenshot file too small (${filesize} bytes), likely invalid" | tee -a "$LOG_FILE"
    return 1
  fi

  echo "  ✅ ${label}: Screenshot valid (${filesize} bytes)" >> "$LOG_FILE"
  return 0
}

# === 主循环：逐设备采集 ===
FAILED_DEVICES=()

for device_spec in "${DEVICES[@]}"; do
  IFS='|' read -r label width height scale is_mobile <<< "$device_spec"

  echo "═══════════════════════════════════════════"
  echo "  📱 Testing: ${label} (${width}×${height})"
  echo "═══════════════════════════════════════════"
  echo "" >> "$LOG_FILE"
  echo "--- ${label} (${width}×${height}) ---" >> "$LOG_FILE"

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

  # 打开浏览器并导航（错误日志记录到文件）
  echo "  Opening ${URL}..." >> "$LOG_FILE"
  if ! $CLI -s="${SESSION}" --config="${CONFIG_FILE}" open "${URL}" 2>>"$LOG_FILE"; then
    echo "  ❌ Failed to open browser for ${label}" | tee -a "$LOG_FILE"
    FAILED_DEVICES+=("$label")
    rm -f "$CONFIG_FILE"
    continue
  fi

  # 等待页面加载
  sleep 3

  # 如果有前置操作脚本，先采集初始 snapshot 再执行操作
  if [[ -n "$PRE_ACTIONS_SCRIPT" && -f "$PRE_ACTIONS_SCRIPT" ]]; then
    echo "  📋 Capturing pre-action snapshot..."
    $CLI -s="${SESSION}" snapshot --filename="${OUTPUT_DIR}/${label}-pre-snapshot.yml" 2>>"$LOG_FILE" || true

    echo "  🔧 Executing pre-actions for ${label}..." | tee -a "$LOG_FILE"
    if ! bash "$PRE_ACTIONS_SCRIPT" "$CLI" "${SESSION}" "${label}" "${OUTPUT_DIR}" 2>>"$LOG_FILE"; then
      echo "  ⚠️  Pre-actions failed for ${label}, capturing error state..." | tee -a "$LOG_FILE"
      $CLI -s="${SESSION}" screenshot --filename="${OUTPUT_DIR}/${label}-error.png" 2>>"$LOG_FILE" || true
    fi

    # 等待操作完成后页面稳定
    sleep 2
  fi

  # === 核心采集 ===

  # 1. 采集布局量化指标（在截图前，获取页面高度以决定是否需要滚动截图）
  capture_metrics "${SESSION}" "${OUTPUT_DIR}" "${label}"

  # 2. 首屏截图
  echo "  📸 Capturing screenshot..."
  $CLI -s="${SESSION}" screenshot --filename="${OUTPUT_DIR}/${label}-screenshot.png" 2>>"$LOG_FILE" || true

  # 验证首屏截图
  validate_screenshot "${OUTPUT_DIR}/${label}-screenshot.png" "${label}" || FAILED_DEVICES+=("$label")

  # 3. 根据布局指标判断是否需要滚动截图
  SCROLL_COUNT=0
  if [[ -f "${OUTPUT_DIR}/${label}-metrics.json" ]]; then
    SCREENS_NEEDED=$(grep -o '"screensNeeded":[[:space:]]*[0-9]*' "${OUTPUT_DIR}/${label}-metrics.json" 2>/dev/null | grep -o '[0-9]*$' || echo "1")
    if [[ "$SCREENS_NEEDED" -gt 1 ]]; then
      # 最多额外滚动 4 屏（首屏已截，总共最多 5 屏）
      SCROLL_COUNT=$(( SCREENS_NEEDED > 5 ? 4 : SCREENS_NEEDED - 1 ))
      echo "  📜 Page needs ${SCREENS_NEEDED} screens, capturing ${SCROLL_COUNT} scroll screenshots..."
      scroll_capture "${SESSION}" "${OUTPUT_DIR}" "${label}" "${SCROLL_COUNT}"
    else
      echo "  ℹ️  Page fits in 1 screen, skipping scroll capture"
    fi
  fi

  # 4. 采集 accessibility snapshot
  echo "  🔍 Capturing accessibility snapshot..."
  $CLI -s="${SESSION}" snapshot --filename="${OUTPUT_DIR}/${label}-snapshot.yml" 2>>"$LOG_FILE" || true

  # 5. 采集 console 日志
  $CLI -s="${SESSION}" console warning > "${OUTPUT_DIR}/${label}-console.log" 2>>"$LOG_FILE" || true

  # 关闭会话
  $CLI -s="${SESSION}" close 2>>"$LOG_FILE" || true

  # 清理配置文件
  rm -f "$CONFIG_FILE"

  echo "  ✅ ${label}: capture complete (screenshots: $((SCROLL_COUNT + 1)), metrics: ✓)"
  echo ""
done

# === 采集结果汇总 ===
echo "═══════════════════════════════════════════"
echo "  📂 All outputs saved to: ${OUTPUT_DIR}"
echo "═══════════════════════════════════════════"
echo ""

# 列出采集产物
echo "Screenshots:"
ls -la "${OUTPUT_DIR}"/*.png 2>/dev/null || echo "  (no screenshots captured)"
echo ""
echo "Metrics:"
ls -la "${OUTPUT_DIR}"/*-metrics.json 2>/dev/null || echo "  (no metrics collected)"
echo ""

# 报告失败的设备
if [[ ${#FAILED_DEVICES[@]} -gt 0 ]]; then
  echo "⚠️  Failed devices: ${FAILED_DEVICES[*]}"
  echo "   Check ${LOG_FILE} for details."
  echo ""
fi

echo "📋 Full log: ${LOG_FILE}"
