/**
 * layout-metrics.js — 量化布局指标采集脚本
 *
 * 通过 playwright-cli eval 注入页面，采集关键布局指标用于辅助响应式分析。
 * 输出 JSON 格式的指标数据，与截图视觉分析互相印证。
 *
 * 用法（在已打开的 playwright-cli 会话中）:
 *   CLI -s=<session> eval "$(cat <skill_dir>/scripts/layout-metrics.js)"
 *
 * 或直接内联:
 *   CLI -s=<session> eval "<此脚本内容>"
 */
(() => {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const bodyScrollW = document.body.scrollWidth;
  const docScrollW = document.documentElement.scrollWidth;
  const bodyScrollH = document.body.scrollHeight;

  // 1. 水平溢出检测
  const hasHorizontalOverflow = bodyScrollW > vw || docScrollW > vw;
  const overflowAmount = Math.max(bodyScrollW, docScrollW) - vw;

  // 2. 查找溢出的元素（Top 5）
  const overflowingElements = [];
  if (hasHorizontalOverflow) {
    const allElements = document.querySelectorAll('*');
    for (const el of allElements) {
      const rect = el.getBoundingClientRect();
      if (rect.right > vw + 2) { // 2px tolerance
        overflowingElements.push({
          tag: el.tagName.toLowerCase(),
          id: el.id || undefined,
          class: el.className ? String(el.className).slice(0, 80) : undefined,
          right: Math.round(rect.right),
          overflow: Math.round(rect.right - vw),
          width: Math.round(rect.width),
        });
      }
    }
    overflowingElements.sort((a, b) => b.overflow - a.overflow);
    overflowingElements.splice(5); // Keep top 5
  }

  // 3. 最小可交互元素尺寸检测（按钮、链接、输入框）
  const interactiveSelectors = 'a, button, input, select, textarea, [role="button"], [tabindex]';
  const interactiveElements = document.querySelectorAll(interactiveSelectors);
  const smallTouchTargets = [];
  for (const el of interactiveElements) {
    const rect = el.getBoundingClientRect();
    // 只检测可见元素
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    if (rect.width < 44 || rect.height < 44) {
      smallTouchTargets.push({
        tag: el.tagName.toLowerCase(),
        text: (el.textContent || '').trim().slice(0, 30),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
        id: el.id || undefined,
      });
    }
  }
  smallTouchTargets.splice(10); // Keep top 10

  // 4. 文字最小 font-size 检测
  const textElements = document.querySelectorAll('p, span, a, li, td, th, label, h1, h2, h3, h4, h5, h6, div');
  let minFontSize = Infinity;
  let minFontSizeElement = null;
  for (const el of textElements) {
    if (!el.textContent || el.textContent.trim().length === 0) continue;
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    const fontSize = parseFloat(style.fontSize);
    if (fontSize < minFontSize && fontSize > 0) {
      minFontSize = fontSize;
      minFontSizeElement = {
        tag: el.tagName.toLowerCase(),
        text: el.textContent.trim().slice(0, 30),
        fontSize: fontSize,
        id: el.id || undefined,
      };
    }
  }

  // 5. 主要区域宽度占比检测
  const mainSelectors = ['main', '[role="main"]', '#main', '#content', '.main-content', '.content'];
  let mainArea = null;
  for (const sel of mainSelectors) {
    const el = document.querySelector(sel);
    if (el) {
      const rect = el.getBoundingClientRect();
      mainArea = {
        selector: sel,
        width: Math.round(rect.width),
        widthPercent: Math.round((rect.width / vw) * 100),
        left: Math.round(rect.left),
      };
      break;
    }
  }

  // 6. 侧边栏/导航检测
  const navSelectors = ['nav', '[role="navigation"]', '.sidebar', '.side-bar', '#sidebar', 'aside'];
  const navElements = [];
  for (const sel of navSelectors) {
    const els = document.querySelectorAll(sel);
    for (const el of els) {
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;
      const style = window.getComputedStyle(el);
      if (style.display === 'none') continue;
      navElements.push({
        selector: sel,
        width: Math.round(rect.width),
        widthPercent: Math.round((rect.width / vw) * 100),
        height: Math.round(rect.height),
        position: style.position,
        isVisible: style.visibility !== 'hidden' && style.opacity !== '0',
      });
    }
  }

  // 7. 垂直竖排文字检测（宽度极小但有多行文字的元素）
  const suspectedVerticalText = [];
  for (const el of textElements) {
    const text = (el.textContent || '').trim();
    if (text.length < 2) continue;
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    // 宽度很小但高度很大，且包含多字符文字 → 可能被挤成竖排
    if (rect.width < 30 && rect.height > rect.width * 3 && text.length > 3) {
      suspectedVerticalText.push({
        tag: el.tagName.toLowerCase(),
        text: text.slice(0, 30),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
      });
    }
  }
  suspectedVerticalText.splice(5);

  // 8. 页面总高度（用于评估是否需要滚动截图）
  const totalPageHeight = Math.max(
    bodyScrollH,
    document.documentElement.scrollHeight,
    document.documentElement.offsetHeight
  );
  const screensNeeded = Math.ceil(totalPageHeight / vh);

  // 输出结构化结果
  const result = {
    viewport: { width: vw, height: vh },
    page: {
      scrollWidth: Math.max(bodyScrollW, docScrollW),
      scrollHeight: totalPageHeight,
      screensNeeded: screensNeeded,
    },
    horizontalOverflow: {
      detected: hasHorizontalOverflow,
      amount: overflowAmount,
      elements: overflowingElements,
    },
    touchTargets: {
      smallCount: smallTouchTargets.length,
      elements: smallTouchTargets,
    },
    typography: {
      minFontSize: minFontSize === Infinity ? null : minFontSize,
      minFontSizeElement: minFontSizeElement,
      suspectedVerticalText: suspectedVerticalText,
    },
    layout: {
      mainArea: mainArea,
      navElements: navElements,
    },
  };

  return JSON.stringify(result, null, 2);
})();
