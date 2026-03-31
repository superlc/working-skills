---
name: responsive-test
description: "针对指定页面地址和测试用例，使用 playwright-cli 在桌面 Desktop 1440x900、平板 Tablet 768x1024、手机 Mobile 375x812 三端视口下自动截图、采集 accessibility snapshot，然后分析截图判断响应式处理是否正确，输出结构化测试报告。支持用户指定截图前的前置操作（如点击、填写表单、滚动等），以测试特定交互状态下的响应式表现。当用户需要测试网页的响应式布局、多端适配、不同设备下的页面表现时，应触发此 Skill。触发关键词包括：响应式测试、多端测试、移动端适配、responsive test、mobile test、iPad 适配、自适应布局验证等。"
---

# Responsive Test — 多端响应式测试 Skill

对指定页面在 Desktop / Tablet / Mobile 三端自动截图 + 快照采集 + 布局量化指标，基于截图、量化数据和快照综合分析响应式适配是否正确，输出结构化测试报告。支持用户指定截图前的前置操作，测试特定交互状态下的响应式表现。

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
| `pre_actions` | ❌ | 截图前需要执行的前置操作列表（如"点击登录按钮 → 填写用户名密码 → 提交"） |
| `breakpoint_test` | ❌ | 是否启用中间断点测试（默认否，启用后增加 5 个中间断点截图） |

**确认流程：**

1. 如用户未提供 `test_cases`，要求补充
2. **主动询问是否需要前置操作**：在确认完 `url` 和 `test_cases` 后，必须向用户确认："截图前是否需要执行操作？比如点击某个按钮、切换标签页、填写表单、登录、滚动到特定区域等。如果页面直接加载即为测试目标状态，可以跳过。"
3. 仅确认缺失信息，不多问

**前置操作的描述格式**：

用户可以用自然语言描述操作，AI 会将其翻译为 playwright-cli 命令。支持的操作类型：

| 操作类型 | 用户描述示例 | 对应 playwright-cli 命令 |
|---------|-------------|------------------------|
| 点击 | "点击登录按钮"、"点击导航栏的'产品'菜单" | `click "<ref>"` |
| 填写 | "在用户名输入框填写 admin" | `fill "<ref>" "admin"` |
| 按键 | "按回车键"、"按 Escape 关闭弹窗" | `press Enter` / `press Escape` |
| 滚动 | "向下滚动 500px"、"滚动到页面底部" | `eval "window.scrollBy(0, 500)"` |
| 悬停 | "鼠标悬停在用户头像上" | `hover "<ref>"` |
| 选择 | "在下拉框中选择'中文'" | `selectOption "<ref>" "中文"` |
| 等待 | "等待 2 秒" | `sleep 2`（由 AI 控制） |
| 自定义JS | "执行 localStorage.setItem('theme', 'dark')" | `eval "localStorage.setItem('theme', 'dark')"` |

**操作中的元素引用（ref）解析**：

用户通常用文字描述元素（如"登录按钮"），AI 需要通过以下步骤解析为 playwright-cli 可识别的 ref：

1. 先打开页面并采集 snapshot
2. 在 snapshot 中查找匹配的元素 ref
3. 使用该 ref 执行操作

> **重要**：前置操作中的元素引用在不同设备端可能不同（如 Desktop 的导航菜单 ref 与 Mobile 的汉堡菜单 ref 不同）。AI 需要在每个端打开页面后分别获取 snapshot，针对每个端独立解析 ref。

### Phase 2：截图采集

根据是否有前置操作，分为两种采集模式：

#### 模式 A：无前置操作（直接采集）

使用 `scripts/responsive-capture.sh` 一次性完成三端采集：

```bash
bash <skill_dir>/scripts/responsive-capture.sh "<url>" "<output_dir>"
```

其中 `<skill_dir>` 为本 Skill 的绝对路径，`<output_dir>` 默认为项目根目录下的 `./responsive-test-output`。

脚本会自动完成以下操作：
1. 分别在 desktop (1440×900) / tablet (768×1024) / mobile (375×812) 视口下启动 Chromium
2. 导航到目标 URL 并等待加载
3. **采集布局量化指标**（`{label}-metrics.json`）— 水平溢出、元素尺寸、字号等客观数据
4. 截取首屏截图（`{label}-screenshot.png`）
5. **自动判断是否需要滚动截图**：根据量化指标中的 `screensNeeded`，自动采集后续屏幕截图（`{label}-scroll-{n}.png`）
6. 采集 accessibility snapshot（`{label}-snapshot.yml`）
7. 采集 console 警告日志（`{label}-console.log`）
8. 关闭会话

**采集日志**保存在 `{output_dir}/capture.log`，如有采集失败可查看详细错误信息。

**启用中间断点测试**（用户要求或 AI 判断有必要时）：

```bash
bash <skill_dir>/scripts/responsive-capture.sh "<url>" "<output_dir>" "" \
  "bp-500|500|900|1|false,bp-600|600|900|1|false,bp-900|900|900|1|false,bp-1100|1100|900|1|false,bp-1280|1280|900|1|false"
```

如脚本执行失败，回退到手动逐端执行：

```bash
# playwright-cli 命令（优先全局，否则 npx）
CLI="npx --yes @playwright/cli@latest"

# Desktop
$CLI -s=rt-desktop --config=desktop-config.json open "<url>"
sleep 3
$CLI -s=rt-desktop screenshot --filename="<output_dir>/desktop-screenshot.png"
$CLI -s=rt-desktop snapshot --filename="<output_dir>/desktop-snapshot.yml"
$CLI -s=rt-desktop eval "$(cat <skill_dir>/scripts/layout-metrics.js)" > "<output_dir>/desktop-metrics.json"
$CLI -s=rt-desktop close

# Tablet
$CLI -s=rt-tablet --config=tablet-config.json open "<url>"
sleep 3
$CLI -s=rt-tablet screenshot --filename="<output_dir>/tablet-screenshot.png"
$CLI -s=rt-tablet snapshot --filename="<output_dir>/tablet-snapshot.yml"
$CLI -s=rt-tablet eval "$(cat <skill_dir>/scripts/layout-metrics.js)" > "<output_dir>/tablet-metrics.json"
$CLI -s=rt-tablet close

# Mobile
$CLI -s=rt-mobile --config=mobile-config.json open "<url>"
sleep 3
$CLI -s=rt-mobile screenshot --filename="<output_dir>/mobile-screenshot.png"
$CLI -s=rt-mobile snapshot --filename="<output_dir>/mobile-snapshot.yml"
$CLI -s=rt-mobile eval "$(cat <skill_dir>/scripts/layout-metrics.js)" > "<output_dir>/mobile-metrics.json"
$CLI -s=rt-mobile close
```

配置文件格式参见 `references/device-profiles.md`。

#### 模式 B：有前置操作（交互式采集）

当用户指定了截图前的前置操作时，**必须逐端手动执行**，不能使用一键脚本。每个端的流程如下：

**步骤 1：打开页面并获取初始 snapshot**

```bash
CLI="npx --yes @playwright/cli@latest"

# 以 Desktop 为例，Tablet / Mobile 换对应的配置和 session 名
$CLI -s=rt-desktop --config=desktop-config.json open "<url>"
sleep 3

# 获取初始 snapshot，用于解析用户描述的元素
$CLI -s=rt-desktop snapshot --filename="<output_dir>/desktop-pre-snapshot.yml"
```

**步骤 2：读取 snapshot 并解析元素 ref**

使用 `read_file` 读取 `desktop-pre-snapshot.yml`，在其中查找用户描述的目标元素。例如用户说"点击登录按钮"，在 snapshot 中找到类似 `- button "登录" [ref=s3e4]` 的条目，提取 `ref=s3e4`。

> **查找技巧**：
> - 按文本内容搜索：用户说"点击'产品'菜单"，搜索 snapshot 中包含 `产品` 的节点
> - 按角色搜索：用户说"点击提交按钮"，搜索 `button` 类型中包含 `提交` 的节点
> - 按位置推断：用户说"点击第二个 Tab"，找到 `tablist` 下的第二个 `tab` 节点
> - 如果找不到精确匹配，使用最接近的元素，并在报告中注明

**步骤 3：按顺序执行前置操作**

将用户的自然语言操作逐条翻译为 playwright-cli 命令并执行：

```bash
# 示例：用户说"点击登录按钮 → 填写用户名 admin → 填写密码 123456 → 点击提交"
$CLI -s=rt-desktop click "s3e4"            # 点击登录按钮
sleep 1
$CLI -s=rt-desktop fill "s5e6" "admin"     # 填写用户名
$CLI -s=rt-desktop fill "s7e8" "123456"    # 填写密码
$CLI -s=rt-desktop click "s9e0"            # 点击提交
sleep 2                                     # 等待页面响应
```

**操作间等待策略**：
- 普通点击/填写后：`sleep 1`
- 触发页面跳转/请求的操作后：`sleep 2`
- 涉及动画的操作后：`sleep 1`
- 用户显式要求等待时：按用户指定时间

**步骤 4：操作完成后截图 + 采集**

```bash
# 采集布局量化指标
$CLI -s=rt-desktop eval "$(cat <skill_dir>/scripts/layout-metrics.js)" > "<output_dir>/desktop-metrics.json"

# 截图（操作后的目标状态）
$CLI -s=rt-desktop screenshot --filename="<output_dir>/desktop-screenshot.png"

# 采集操作后的 snapshot
$CLI -s=rt-desktop snapshot --filename="<output_dir>/desktop-snapshot.yml"

# 采集 console 日志
$CLI -s=rt-desktop console warning > "<output_dir>/desktop-console.log" 2>/dev/null || true

# 根据 metrics 中的 screensNeeded 决定是否采集滚动截图
# 如 screensNeeded > 1，执行滚动截图：
bash <skill_dir>/scripts/scroll-capture.sh rt-desktop "<output_dir>" desktop <scroll_count>

# 关闭会话
$CLI -s=rt-desktop close
```

**步骤 5：对每个端重复步骤 1-4**

> **关键注意事项**：
> - 每个端必须独立获取 snapshot 并重新解析 ref，因为同一元素在不同视口下的 ref 可能不同
> - 某些操作在不同端的实现方式可能不同（如 Desktop 直接点击导航菜单项 vs Mobile 需要先点击汉堡菜单再点击菜单项），AI 需要根据每端的 snapshot 智能适配操作序列
> - 如果某个端上找不到操作目标元素（如仅在 Mobile 端出现的底部菜单），跳过该操作并在报告中记录

**步骤 6：操作失败的处理**

如果某个操作执行失败（如元素未找到、点击无响应）：

1. 截取当前页面状态截图作为错误证据：`$CLI -s=<session> screenshot --filename="<output_dir>/<label>-error.png"`
2. 记录失败的操作和错误信息
3. 尝试继续执行后续操作（除非后续操作依赖于失败的操作）
4. 在最终报告中标注此端的前置操作失败，并附上错误截图

### Phase 3：分析截图

逐端分析截图，结合用户提供的测试用例和**布局量化指标**判断响应式处理是否正确。

> **⚠️ 核心原则：视觉分析是第一优先级，不可跳过，不可替代。**
>
> 截图是最终用户看到的真实画面，是判定响应式是否合格的唯一权威依据。
> DOM 快照（snapshot）只能反映语义结构，**不能反映 CSS 布局、元素尺寸、溢出裁剪、重叠遮挡等视觉问题**。
> 即使 DOM 快照显示所有元素都存在且结构完整，**视觉上出现任何布局异常都必须判定为不通过**。

**分析步骤（严格按顺序执行）：**

#### 步骤 1：布局量化指标分析（新增，首先执行）

使用 `read_file` 读取每端的 `{label}-metrics.json`，提取客观布局数据：

| 指标 | 说明 | 判定阈值 |
|------|------|---------|
| `horizontalOverflow.detected` | 是否有水平溢出 | `true` → 🔴 P0 问题 |
| `horizontalOverflow.elements` | 溢出元素列表 | 列出具体溢出的元素和溢出量 |
| `touchTargets.smallCount` | 触控目标过小的元素数量 | > 0 → 🟠 P1 问题（Mobile/Tablet 端）|
| `typography.minFontSize` | 页面最小字号 | < 12px → 🟠 P1 问题 |
| `typography.suspectedVerticalText` | 疑似被挤成竖排的文字 | 列表不为空 → 🔴 P0 问题 |
| `layout.mainArea.widthPercent` | 主内容区宽度占比 | Mobile < 80% → ⚠️ 可能有侧边栏未收起 |
| `layout.navElements` | 导航/侧边栏宽度占比 | Mobile > 30% → 🔴 P0 侧边栏未适配 |
| `page.screensNeeded` | 页面总共需要几屏 | > 1 → 需要分析滚动截图 |

> **量化指标与视觉分析互相印证**：量化指标提供客观数据，视觉分析提供直觉判断。两者有矛盾时，以截图视觉分析为准（量化指标可能因 DOM 结构复杂而误判），但需在报告中说明矛盾原因。

#### 步骤 2：视觉分析（必须执行，不可跳过）

使用 `read_file` 读取每端的截图（`.png` 文件），**逐项描述**截图中实际看到的内容。

**⚠️ 每端截图必须完成以下「视觉审视清单」，逐项用具体事实回答，禁止使用"布局良好"、"适配正常"等笼统评价：**

| # | 审视项 | 必须具体回答的问题 |
|---|-------|------------------|
| V1 | 导航/侧边栏状态 | 导航栏是展开还是收起？占屏幕宽度的大约百分比？在当前视口下这种展示方式是否合理？ |
| V2 | 主内容区可用宽度 | 主内容区占屏幕宽度的大约百分比？内容是否被挤压？ |
| V3 | 标题/文字排列 | 标题文字是正常横排还是被挤成竖排？是否有文字被截断、溢出或不可读？ |
| V4 | 元素重叠/遮挡 | 是否有按钮、卡片、浮层等元素互相重叠遮挡？ |
| V5 | 内容可见性 | 页面核心内容（如列表、表格、表单）是否完整可见？是否有内容被挤出屏幕可视区域？ |
| V6 | 交互元素可用性 | 按钮、输入框、筛选器等交互元素是否可见且尺寸合理？是否有元素小到无法点击？ |
| V7 | 整体布局结构 | 整体是单列/双栏/多栏布局？这种布局在当前视口宽度下是否合适？ |

> **规则：如果视觉审视发现任何 V1-V7 中的严重问题（如布局崩坏、内容不可见、元素大面积重叠），直接判定该端不通过，无需继续后续步骤来"挽救"结论。**

#### 步骤 3：滚动截图逐屏分析（如有滚动截图）

当页面超过 1 屏时，使用 `read_file` 逐一读取 `{label}-scroll-{n}.png`，**每屏都必须完成 V1-V7 审视清单**。

> **⚠️ 关键：** 滚动截图的分析与首屏截图同等重要。响应式问题可能出现在页面任何位置：
> - 折叠区域的表格在窄屏下溢出
> - 页面中部的多栏布局未在小视口下变为单列
> - 底部 footer 的链接在 Mobile 端过小无法点击
> - sticky 元素在滚动后遮挡内容

#### 步骤 4：DOM 快照辅助分析

使用 `read_file` 读取每端的 snapshot（`.yml` 文件），分析 DOM 结构和元素层级。

> **注意：DOM 快照仅作为辅助验证手段，用于：**
> - 确认视觉上不可见的元素是否在 DOM 中存在（判断是"CSS 隐藏"还是"未渲染"）
> - 验证语义结构是否正确（如无障碍标签、层级关系）
> - 比较三端 DOM 差异（判断是否有响应式条件渲染）
>
> **DOM 快照不能用于推翻视觉分析的结论。** 如果视觉上布局已崩坏，即使 DOM 结构完整也必须判定不通过。

#### 步骤 5：控制台日志检查

检查 console 日志中是否有布局相关的警告或错误。

> **注意：控制台无报错不等于视觉无问题。** CSS 布局异常不会产生 JS 控制台错误。

#### 步骤 6：对照检查清单

按 `references/checklist.md` 中的检查项逐一验证。

> **注意：** checklist 中每项标注了检测方式（📸 截图可检 / 📊 指标可检 / 👁️ 人工复查 / ❓ 当前不可自动化）。AI 只需完成标注为 📸 和 📊 的项目，标注为 👁️ 和 ❓ 的项目应在报告中列出但标注为"需人工复查"。

#### 步骤 7：对照测试用例

按用户提供的具体测试用例判断是否通过。

#### 步骤 8：验证前置操作结果（如有前置操作）

确认操作是否在各端成功执行，操作后的页面状态是否符合预期。

> **⚠️ 操作"成功执行"≠ "操作结果合理"**。必须区分：
> - **执行状态**：命令是否成功执行（未报错）
> - **结果状态**：操作后的页面在当前视口下是否呈现出合理的布局
>
> 例如：在 Mobile 端成功点击了侧边栏的导航链接，但导航后的页面侧边栏仍然以桌面形态展开、挤压了主内容区 → 操作执行成功，但结果状态异常，应判定不通过。

**分析维度（每端都要检查）：**

- **布局完整性**：是否有水平溢出、元素重叠、内容裁剪、布局崩坏
- **文字可读性**：文字大小是否合理、是否溢出容器、是否被挤成竖排、行宽是否过长
- **交互可用性**：可点击元素尺寸是否足够（mobile ≥ 44px）、导航是否可用、核心功能是否可操作
- **图片适配**：图片是否变形、是否溢出、是否清晰
- **导航适配**：导航在不同端的展示方式是否合理（桌面展开、平板可折叠、手机应为汉堡菜单/底部标签栏）
- **跨端一致性**：核心功能在三端是否都可操作完成
- **交互状态一致性**（如有前置操作）：操作后的目标状态在三端是否一致呈现，不同端下操作路径差异是否合理

**⚠️ 逐端独立分析原则：**

每端的分析必须完全独立，不受其他端分析结果的影响。即使 Desktop 和 Tablet 都通过了，Mobile 端仍必须严格按上述步骤独立审视。严禁产生"前两端通过 → 第三端也应该通过"的惯性判断。

### Phase 4：输出报告

使用 `references/report-template.md` 作为模板，生成结构化 Markdown 报告。

报告保存到 `<output_dir>/report.md`。

**报告必须包含：**
1. 测试环境信息（URL、时间、设备配置）
2. 前置操作记录（如有，包含操作列表、各端执行情况、适配说明）
3. **布局量化指标摘要**（每端的关键指标数据）
4. 每端截图的分析结论（包括首屏和滚动截图）
5. 每端发现的问题列表（标注严重程度 P0/P1/P2）
6. 每端的通过/不通过判定
7. 总结和修复建议

**⚠️ 报告生成后强制自检：**

生成报告后，必须完成以下自检清单。如有不合格项，**立即补充修正后再输出**：

| 自检项 | 要求 |
|-------|------|
| V1-V7 表格完整性 | 每端（包括 Desktop、Tablet、Mobile）都必须有完整的 V1-V7 视觉审视清单表格，不可省略任何端 |
| 禁止笼统评价 | V1-V7 每项的「观察结果」列不得包含"布局良好"、"适配正常"、"内容完整可读"等笼统词句，必须有具体事实描述 |
| 量化数据引用 | 每端至少引用 1 项 metrics.json 中的客观数据（如水平溢出量、主内容区宽度占比） |
| 滚动截图分析 | 如有滚动截图，每屏都必须在报告中有分析记录 |
| 操作结果区分 | 如有前置操作，必须区分"执行状态"和"结果状态" |

---

## 关键规则

1. **🔴 视觉分析是最高优先级**。截图是用户真实看到的画面，**是判定通过/不通过的唯一权威依据**。视觉上出现布局崩坏、内容不可见、元素重叠等问题，无论 DOM 快照或控制台日志如何，都必须判定不通过。Phase 3 的视觉审视清单（V1-V7）不可跳过，不可用笼统评价替代具体描述
2. **🔴 禁止 DOM 推翻视觉**。DOM 快照显示"元素存在"不能反驳截图中"元素不可见/不可用"的事实。DOM 结构完整 ≠ 视觉布局正常。DOM 快照不反映 CSS 布局、尺寸、溢出、遮挡
3. **🔴 逐端独立分析**。每端必须完全独立审视，严禁"前两端通过 → 第三端也通过"的惯性判断。即使 Desktop 和 Tablet 都通过，Mobile 仍须严格完成全部视觉审视步骤
4. **🔴 V1-V7 表格不可省略**。三端中每一端都必须输出完整的 V1-V7 视觉审视清单表格，不得以任何理由（如"Desktop 通常没问题"）跳过
5. **🔴 量化指标与视觉互相印证**。布局量化指标提供客观数据，与截图视觉分析互相印证。两者有矛盾时以截图为准，但需在报告中说明
6. **必须三端都测**。即使用户只提到"手机端"，也要跑完三端以确保跨端对比
7. **截图是第一证据**。所有结论必须基于截图分析，不能凭假设判定
8. **测试用例是判定标准**。用户提供的测试用例是通过/不通过的核心依据
9. **问题分级要准确**。P0 = 功能不可用 / 布局崩坏，P1 = 体验严重受损，P2 = 视觉瑕疵
10. **清理会话**。测试完成后确保所有 playwright-cli 会话已关闭（`playwright-cli close-all`）
11. **输出目录统一**。所有产物（截图、快照、日志、指标、报告）输出到同一目录
12. **主动询问前置操作**。Phase 1 确认输入时，必须主动询问用户截图前是否需要执行操作，不能跳过
13. **逐端独立解析 ref**。有前置操作时，每个端必须独立获取 snapshot 并解析元素 ref，不可跨端复用
14. **操作失败不中断**。单个操作失败时截取错误截图并继续，在报告中如实记录
15. **滚动截图同等重要**。长页面的滚动截图必须逐屏分析，不可只分析首屏就下结论

---

## 文件结构

```
responsive-test/
├── SKILL.md                          # 本文件
├── scripts/
│   ├── responsive-capture.sh         # 多端截图采集（一键三端 + 自动滚动截图 + 量化指标）
│   ├── scroll-capture.sh             # 滚动截图采集（独立使用）
│   └── layout-metrics.js             # 布局量化指标采集脚本
├── references/
│   ├── device-profiles.md            # 设备配置参考 + 断点表 + isMobile 说明
│   ├── checklist.md                  # 响应式测试检查清单（含检测方式标注）
│   └── report-template.md            # 测试报告 Markdown 模板
└── assets/
    └── (empty)
```
