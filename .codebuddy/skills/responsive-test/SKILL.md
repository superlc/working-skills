---
name: responsive-test
description: "针对指定页面地址和测试用例，使用 playwright-cli 在桌面 Desktop 1440x900、平板 Tablet 768x1024、手机 Mobile 375x812 三端视口下自动截图、采集 accessibility snapshot，然后分析截图判断响应式处理是否正确，输出结构化测试报告。当用户需要测试网页的响应式布局、多端适配、不同设备下的页面表现时，应触发此 Skill。触发关键词包括：响应式测试、多端测试、移动端适配、responsive test、mobile test、iPad 适配、自适应布局验证等。"
---

# Responsive Test — 多端响应式测试 Skill

对指定页面在 Desktop / Tablet / Mobile 三端自动截图 + 快照采集，基于截图和快照分析响应式适配是否正确，输出结构化测试报告。

---

## 依赖

- `playwright-cli`（通过 `npx --yes @playwright/cli@latest` 调用，无需全局安装）

---

## 工作流

### Phase 1：确认输入

从用户输入中提取以下信息：

| 参数 | 必填 | 说明 |
|------|------|------|
| `url` | ✅ | 目标页面地址（支持 localhost） |
| `test_cases` | ✅ | 测试用例描述（如"导航栏在手机端应折叠为汉堡菜单"） |
| `devices` | ❌ | 自定义设备列表，默认使用标准三端（Desktop 1440×900 / Tablet 768×1024 / Mobile 375×812） |

如用户未提供 `test_cases`，要求补充。仅确认缺失信息，不多问。

### Phase 2：截图采集

使用 `scripts/responsive-capture.sh` 一次性完成三端采集：

```bash
bash <skill_dir>/scripts/responsive-capture.sh "<url>" "<output_dir>"
```

其中 `<skill_dir>` 为本 Skill 的绝对路径，`<output_dir>` 默认为项目根目录下的 `./responsive-test-output`。

脚本会自动完成以下操作：
1. 分别在 desktop (1440×900) / tablet (768×1024) / mobile (375×812) 视口下启动 Chromium
2. 导航到目标 URL 并等待加载
3. 截取全页面截图（`{label}-screenshot.png`）
4. 采集 accessibility snapshot（`{label}-snapshot.yml`）
5. 采集 console 警告日志（`{label}-console.log`）
6. 关闭会话

如脚本执行失败，回退到手动逐端执行：

```bash
# playwright-cli 命令（优先全局，否则 npx）
CLI="npx --yes @playwright/cli@latest"

# Desktop
$CLI -s=rt-desktop --config=desktop-config.json open "<url>"
sleep 3
$CLI -s=rt-desktop screenshot --filename="<output_dir>/desktop-screenshot.png"
$CLI -s=rt-desktop snapshot --filename="<output_dir>/desktop-snapshot.yml"
$CLI -s=rt-desktop close

# Tablet
$CLI -s=rt-tablet --config=tablet-config.json open "<url>"
sleep 3
$CLI -s=rt-tablet screenshot --filename="<output_dir>/tablet-screenshot.png"
$CLI -s=rt-tablet snapshot --filename="<output_dir>/tablet-snapshot.yml"
$CLI -s=rt-tablet close

# Mobile
$CLI -s=rt-mobile --config=mobile-config.json open "<url>"
sleep 3
$CLI -s=rt-mobile screenshot --filename="<output_dir>/mobile-screenshot.png"
$CLI -s=rt-mobile snapshot --filename="<output_dir>/mobile-snapshot.yml"
$CLI -s=rt-mobile close
```

配置文件格式参见 `references/device-profiles.md`。

#### 页面需要交互才能到达测试状态时

某些测试用例需要先执行交互（如点击导航、切换 Tab、滚动到特定区域）才能到达目标状态。此时在截图前使用 playwright-cli 的交互命令：

```bash
# 先打开页面
$CLI -s=rt-desktop open "<url>"
sleep 3

# 执行交互（根据测试用例需求）
$CLI -s=rt-desktop click "<ref>"        # 点击元素
$CLI -s=rt-desktop fill "<ref>" "text"  # 填充表单
$CLI -s=rt-desktop press Enter          # 按键
$CLI -s=rt-desktop eval "window.scrollTo(0, 500)"  # 滚动

# 等待交互完成后再截图
sleep 1
$CLI -s=rt-desktop screenshot --filename="<output_dir>/desktop-screenshot.png"
```

要获取页面元素引用（ref），先执行 `$CLI -s=<session> snapshot` 查看 snapshot 文件中的 ref 标记。

#### 长页面滚动截图

使用 `scripts/scroll-capture.sh` 采集多屏截图：

```bash
bash <skill_dir>/scripts/scroll-capture.sh <session> <output_dir> <label> [scroll_count]
```

### Phase 3：分析截图

逐端分析截图，结合用户提供的测试用例判断响应式处理是否正确。

**分析步骤：**

1. **读取截图**：使用 `read_file` 读取每端的截图（`.png` 文件），视觉分析页面布局
2. **读取快照**：使用 `read_file` 读取每端的 snapshot（`.yml` 文件），分析 DOM 结构和元素层级
3. **读取日志**：检查 console 日志中是否有布局相关的警告或错误
4. **对照检查清单**：按 `references/checklist.md` 中的检查项逐一验证
5. **对照测试用例**：按用户提供的具体测试用例判断是否通过

**分析维度（每端都要检查）：**

- **布局完整性**：是否有水平溢出、元素重叠、内容裁剪
- **文字可读性**：文字大小是否合理、是否溢出容器、行宽是否过长
- **交互可用性**：可点击元素尺寸是否足够（mobile ≥ 44px）、导航是否可用
- **图片适配**：图片是否变形、是否溢出、是否清晰
- **导航适配**：导航在不同端的展示方式是否合理（桌面展开、平板折叠、手机汉堡菜单）
- **跨端一致性**：核心功能在三端是否都可操作完成

### Phase 4：输出报告

使用 `references/report-template.md` 作为模板，生成结构化 Markdown 报告。

报告保存到 `<output_dir>/report.md`。

**报告必须包含：**
1. 测试环境信息（URL、时间、设备配置）
2. 每端截图的分析结论
3. 每端发现的问题列表（标注严重程度 P0/P1/P2）
4. 每端的通过/不通过判定
5. 总结和修复建议

---

## 关键规则

1. **必须三端都测**。即使用户只提到"手机端"，也要跑完三端以确保跨端对比
2. **截图是第一证据**。所有结论必须基于截图分析，不能凭假设判定
3. **测试用例是判定标准**。用户提供的测试用例是通过/不通过的核心依据
4. **问题分级要准确**。P0 = 功能不可用，P1 = 体验严重受损，P2 = 视觉瑕疵
5. **清理会话**。测试完成后确保所有 playwright-cli 会话已关闭（`playwright-cli close-all`）
6. **输出目录统一**。所有产物（截图、快照、日志、报告）输出到同一目录

---

## 文件结构

```
responsive-test/
├── SKILL.md                          # 本文件
├── scripts/
│   ├── responsive-capture.sh         # 多端截图采集（一键三端）
│   └── scroll-capture.sh             # 滚动截图采集（长页面）
├── references/
│   ├── device-profiles.md            # 设备配置参考 + 断点表
│   ├── checklist.md                  # 响应式测试检查清单
│   └── report-template.md            # 测试报告 Markdown 模板
└── assets/
    └── (empty)
```
