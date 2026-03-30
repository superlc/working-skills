# Custom Skills

本仓库用于集中管理和维护自定义 **Skills**（技能包）。每个 Skill 是一个独立的领域扩展模块，提供特定场景下的专家知识、标准化工作流（SOP）和可执行脚本，供 AI 编程助手在对话中按需加载和调用。

## 项目意图

- **统一管理**：将分散的 Skill 集中到一个仓库，方便版本控制和团队协作
- **标准化结构**：每个 Skill 遵循统一的目录规范（`SKILL.md` + `scripts/` + `references/` + `assets/`），降低维护成本
- **按需扩展**：根据实际工作场景持续新增 Skill，逐步构建完整的自动化测试与开发工具链

## 目录结构

```
custom-skills/
├── README.md                                  # 项目说明文档（本文件）
└── responsive-test/                           # 🖥️ 多端响应式测试 Skill
    ├── SKILL.md                               # Skill 定义文件（描述、工作流、规则）
    ├── scripts/
    │   ├── responsive-capture.sh              # 多端截图采集脚本（一键三端）
    │   └── scroll-capture.sh                  # 长页面滚动截图采集脚本
    ├── references/
    │   ├── device-profiles.md                 # 设备配置参考 & 断点表
    │   ├── checklist.md                       # 响应式测试检查清单
    │   └── report-template.md                 # 测试报告 Markdown 模板
    └── assets/                                # 静态资源目录（预留）
```

## 已有 Skills

| Skill | 说明 | 触发关键词 |
|-------|------|-----------|
| **responsive-test** | 针对指定页面在 Desktop（1440×900）/ Tablet（768×1024）/ Mobile（375×812）三端自动截图 + 快照采集，分析响应式适配是否正确，输出结构化测试报告 | 响应式测试、多端测试、移动端适配、responsive test、mobile test、iPad 适配、自适应布局验证 |

## 如何新增 Skill

1. 在项目根目录下创建以 Skill 名称命名的文件夹
2. 在该文件夹下创建 `SKILL.md`，按照 frontmatter 格式定义 `name` 和 `description`
3. 根据需要添加 `scripts/`、`references/`、`assets/` 子目录
4. 在本 README 的 **已有 Skills** 表格中补充新条目
