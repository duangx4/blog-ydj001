/* ==========================================================
   theme-toggle.js — 拓片（暗）↔ 白昼（亮）切换
   ========================================================== */
(function () {
  var STORAGE_KEY = "ink-theme";
  var BTN_SELECTOR = ".theme-btn";

  // 读取偏好：localStorage > prefers-color-scheme > "dark"
  function resolve() {
    var saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "light" || saved === "dark") return saved;
    if (window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches) return "light";
    return "dark";
  }

  function apply(theme) {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem(STORAGE_KEY, theme);
    // 更新所有切换按钮文案
    document.querySelectorAll(BTN_SELECTOR).forEach(function (btn) {
      btn.textContent = theme === "dark" ? "白昼" : "拓片";
      btn.setAttribute("aria-label", theme === "dark" ? "切换到白昼模式" : "切换到拓片模式");
    });
  }

  // 初始化
  apply(resolve());

  // 绑定按钮（DOMContentLoaded 后再绑，防止脚本在 body 前加载）
  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(BTN_SELECTOR).forEach(function (btn) {
      btn.addEventListener("click", function () {
        var current = document.documentElement.dataset.theme || "dark";
        apply(current === "dark" ? "light" : "dark");
      });
    });
  });
}());
