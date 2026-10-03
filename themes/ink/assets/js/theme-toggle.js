/* ==========================================================
   theme-toggle.js — 拓片（暗）↔ 白昼（亮）切换
   ----------------------------------------------------------
   切换时给 <html> 加 .ink-switching，让纸色/墨色做一次交叉过渡。
   不做反相 —— 宣纸和拓片是两种真东西，只是换了张纸。
   过渡结束立刻摘掉这个类，避免它影响页面后续的其它动画。
   ========================================================== */
(function () {
  var STORAGE_KEY = "ink-theme";
  var BTN_SELECTOR = ".theme-btn";
  var SWITCH_MS = 460;

  // 读取偏好：localStorage > prefers-color-scheme > "dark"
  function resolve() {
    var saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "light" || saved === "dark") return saved;
    if (window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches) return "light";
    return "dark";
  }

  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // 更新所有切换按钮文案。文案是刻意的：暗色模式的「去处」是白昼，
  // 亮色模式的「去处」是拓片 —— 按钮说的是你将要去哪，不是你现在在哪。
  function syncButtons(theme) {
    document.querySelectorAll(BTN_SELECTOR).forEach(function (btn) {
      btn.textContent = theme === "dark" ? "白昼" : "拓片";
      btn.setAttribute("aria-label", theme === "dark" ? "切换到白昼模式" : "切换到拓片模式");
      btn.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    });
  }

  function apply(theme, animate) {
    var root = document.documentElement;

    if (animate && !reduce) {
      root.classList.add("ink-switching");
      window.clearTimeout(apply._t);
      apply._t = window.setTimeout(function () {
        root.classList.remove("ink-switching");
      }, SWITCH_MS);
    }

    root.dataset.theme = theme;
    try { localStorage.setItem(STORAGE_KEY, theme); } catch (e) {}
    syncButtons(theme);
  }

  // 初始化（首屏不animate，避免和 head 里的防闪脚本打架）
  apply(resolve(), false);

  // 绑定按钮
  document.addEventListener("DOMContentLoaded", function () {
    syncButtons(document.documentElement.dataset.theme || "dark");
    document.querySelectorAll(BTN_SELECTOR).forEach(function (btn) {
      btn.addEventListener("click", function () {
        var current = document.documentElement.dataset.theme || "dark";
        apply(current === "dark" ? "light" : "dark", true);
      });
    });
  });

  // 跟随系统（用户没手动选过时才跟随）
  if (window.matchMedia) {
    var mq = window.matchMedia("(prefers-color-scheme: light)");
    var onChange = function (e) {
      if (localStorage.getItem(STORAGE_KEY)) return;
      apply(e.matches ? "light" : "dark", true);
    };
    if (mq.addEventListener) mq.addEventListener("change", onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }
}());
