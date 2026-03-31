# 设备配置参考

## 标准三端视口

| 端 | 标签 | 宽度 | 高度 | DPR | isMobile | 代表设备 |
|----|------|------|------|-----|----------|---------|
| Desktop | `desktop` | 1440 | 900 | 1 | false | MacBook Pro 15" |
| Tablet | `tablet` | 768 | 1024 | 2 | false | iPad (portrait) |
| Mobile | `mobile` | 375 | 812 | 3 | true | iPhone 13/14/15 |

## 扩展设备预设

当测试需要覆盖更多设备时，使用以下扩展配置：

| 端 | 标签 | 宽度 | 高度 | DPR | isMobile | 代表设备 |
|----|------|------|------|-----|----------|---------|
| Desktop Wide | `desktop-wide` | 1920 | 1080 | 1 | false | 外接显示器 |
| Desktop Narrow | `desktop-narrow` | 1280 | 720 | 1 | false | 小笔记本 |
| Tablet Landscape | `tablet-landscape` | 1024 | 768 | 2 | false | iPad (landscape) |
| Tablet Small | `tablet-small` | 601 | 962 | 2.625 | true | Nexus 7 |
| Mobile Large | `mobile-large` | 414 | 896 | 3 | true | iPhone 11 Pro Max |
| Mobile Small | `mobile-small` | 320 | 568 | 2 | true | iPhone SE (1st gen) |

## PLAYWRIGHT_MCP_DEVICE 预设名

playwright-cli 原生支持的设备预设名（通过环境变量 `PLAYWRIGHT_MCP_DEVICE` 设置），常用的包括：

- `iPhone 15`
- `iPhone 15 Pro Max`
- `iPhone SE`
- `iPad (gen 7)`
- `iPad Pro 11`
- `Pixel 7`
- `Galaxy S9+`

使用方式：
```bash
PLAYWRIGHT_MCP_DEVICE="iPhone 15" playwright-cli open https://example.com
```

## playwright-cli 配置文件格式

```json
{
  "browser": {
    "browserName": "chromium",
    "contextOptions": {
      "viewport": { "width": 375, "height": 812 },
      "deviceScaleFactor": 3,
      "isMobile": true,
      "userAgent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)..."
    }
  },
  "outputDir": "./output",
  "outputMode": "file"
}
```

## 常见响应式断点

| 断点 | 范围 | 典型场景 |
|------|------|---------|
| xs | < 576px | 手机竖屏 |
| sm | 576–767px | 手机横屏 / 大屏手机 |
| md | 768–991px | 平板竖屏 |
| lg | 992–1199px | 平板横屏 / 小桌面 |
| xl | 1200–1439px | 标准桌面 |
| xxl | ≥ 1440px | 大桌面 |
