/* ==========================================================
   ink.js — 墨与器的行为层
   四件事，全部无依赖、幂等、尊重 prefers-reduced-motion：
     1. 落墨显影 —— 标记 .reveal 的元素进视口时显出来
     2. 顶栏飞白 —— 离开页首后给 nav 加 .is-stuck
     3. 代码块    —— 语言标注 + 复制按钮
     4. 目录航迹  —— 右侧竖线随阅读进度填充，当前节的路点点朱砂
   ========================================================== */
(function () {
  "use strict";

  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* 告诉 CSS「JS 可用」，避免无 JS 时内容被 .reveal 藏住 */
  document.documentElement.classList.remove("no-js");
  document.documentElement.classList.add("js");

  /* ------------------------------------------------------
     1. 落墨显影
     ------------------------------------------------------ */
  function initReveal() {
    var els = document.querySelectorAll(".reveal");
    if (!els.length) return;

    /* 不支持 IntersectionObserver 或用户要求减弱动效 → 直接显示 */
    if (reduce || !("IntersectionObserver" in window)) {
      els.forEach(function (el) { el.classList.add("is-inked"); });
      return;
    }

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-inked");
        io.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });

    els.forEach(function (el) { io.observe(el); });

    /* 兜底：万一 IntersectionObserver 的回调没如期触发（扩展干扰等），
       把「此刻已经在视口内或已滚过」的元素放行 —— 否则它们会一直空白。
       注意只放行这些，不能无条件全放：那会把首屏之下的元素提前点亮，
       整个落墨动画就白做了。延迟阈值取视口高度，给滚动留出余地。 */
    setTimeout(function () {
      var vh = window.innerHeight || 0;
      els.forEach(function (el) {
        if (el.classList.contains("is-inked")) return;
        if (el.getBoundingClientRect().top < vh) el.classList.add("is-inked");
      });
    }, 2500);
  }

  /* ------------------------------------------------------
     2. 顶栏飞白
     ------------------------------------------------------ */
  function initNav() {
    var nav = document.querySelector("nav.top");
    if (!nav) return;
    var on = false;
    function update() {
      var next = window.scrollY > 8;
      if (next !== on) {
        on = next;
        nav.classList.toggle("is-stuck", on);
      }
    }
    window.addEventListener("scroll", update, { passive: true });
    update();
  }

  /* ------------------------------------------------------
     3. 代码块：语言标注 + 复制
     ------------------------------------------------------ */
  function initCode() {
    var pres = document.querySelectorAll(".prose pre");
    if (!pres.length) return;

    pres.forEach(function (pre) {
      /* 幂等：已经包过就跳过（pre 现在在 .code-wrap 里） */
      if (pre.parentElement && pre.parentElement.classList.contains("code-wrap")) return;

      /* 把 pre 包进一个不滚动的容器里，工具栏挂在容器上。
         原因：pre 自己是 overflow-x:auto 的滚动容器，
         绝对定位的元素会跟着横向滚动一起卷走 —— 长行代码一右滚，
         复制按钮就跑出屏幕了。挂在容器外就永远钉在右上角。 */
      var wrap = document.createElement("div");
      wrap.className = "code-wrap";
      pre.parentNode.insertBefore(wrap, pre);
      wrap.appendChild(pre);

      var code = pre.querySelector("code");
      var lang = detectLang(pre, code);

      var meta = document.createElement("div");
      meta.className = "code-meta";

      if (lang) {
        var label = document.createElement("span");
        label.textContent = lang;
        meta.appendChild(label);
      }

      var btn = document.createElement("button");
      btn.type = "button";
      btn.textContent = "复制";
      btn.setAttribute("aria-label", "复制这段代码");
      btn.addEventListener("click", function () {
        var text = code ? code.textContent : pre.textContent;
        copy(text).then(function () {
          btn.textContent = "已复制";
          setTimeout(function () { btn.textContent = "复制"; }, 1800);
        }, function () {
          btn.textContent = "复制失败";
          setTimeout(function () { btn.textContent = "复制"; }, 1800);
        });
      });
      meta.appendChild(btn);

      wrap.appendChild(meta);
    });
  }

  /* 语言名：优先取 chroma 高亮的 class（language-xxx / chroma 的 data-lang），
     再退回 pre 上的 class，最后放弃标注（不猜） */
  function detectLang(pre, code) {
    var m = null;
    if (code) {
      m = code.className.match(/(?:language|lang)-([a-z0-9+#]+)/i);
      if (m) return m[1].toLowerCase();
    }
    m = (pre.className || "").match(/language-([a-z0-9+#]+)/i);
    if (m) return m[1].toLowerCase();
    var dl = pre.getAttribute("data-lang");
    if (dl) return dl.toLowerCase();
    /* 有 chroma 高亮但没写语言：标一个通用名，好过空着 */
    if (/\bchroma\b/.test(pre.className || "")) return "code";
    return "";
  }

  /* 复制。两级策略：
     1. Clipboard API（需安全上下文 + 文档聚焦）
     2. 被拒时退到 execCommand 选区复制 —— 文档失焦、权限被拒时
        前者会 reject，没有这一层就彻底失败了。 */
  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).catch(function () {
        return legacyCopy(text);
      });
    }
    return legacyCopy(text);
  }

  function legacyCopy(text) {
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        /* 放进视口内再选中：完全移出视口（top:-1000px）时，
           部分浏览器 select() 无效 */
        ta.style.cssText = "position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none";
        document.body.appendChild(ta);
        var sel = document.getSelection();
        var prev = sel && sel.rangeCount ? sel.getRangeAt(0) : null;
        ta.select();
        ta.setSelectionRange(0, text.length);
        var ok = false;
        try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
        document.body.removeChild(ta);
        /* 复原用户原本的选区，别把人家选中的东西弄丢 */
        if (prev && sel) { sel.removeAllRanges(); sel.addRange(prev); }
        ok ? resolve() : reject(new Error("execCommand copy failed"));
      } catch (e) {
        reject(e);
      }
    });
  }

  /* ------------------------------------------------------
     4. 目录航迹
     ------------------------------------------------------ */
  function initToc() {
    var rail = document.getElementById("toc-rail");
    var list = document.getElementById("toc-rail-list");
    var fill = document.getElementById("toc-rail-fill");
    if (!rail || !list) return;

    var headings = [].slice.call(
      document.querySelectorAll("article.prose h2[id], article.prose h3[id]")
    );
    /* 少于 3 个标题就不值得画一条轨 */
    if (headings.length < 3) { rail.remove(); return; }

    var links = headings.map(function (h) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.href = "#" + h.id;
      a.textContent = h.textContent;
      /* 三级标题缩进 */
      if (h.tagName === "H3") a.style.paddingLeft = "10px";
      li.appendChild(a);
      list.appendChild(li);
      return a;
    });

    rail.classList.add("is-ready");

    var current = -1;

    function update() {
      var scrollY = window.scrollY;
      var navH = 92;
      /* 当前节：最后一个已经滚过导航栏的标题 */
      var idx = 0;
      for (var i = 0; i < headings.length; i++) {
        if (headings[i].getBoundingClientRect().top <= navH) idx = i;
      }
      if (idx !== current) {
        if (links[current]) links[current].classList.remove("is-current");
        links[idx].classList.add("is-current");
        current = idx;
      }
      /* 填充轨：当前标题到下一个标题之间的进度 */
      if (fill) {
        var top = headings[0].getBoundingClientRect().top + scrollY;
        var last = headings[headings.length - 1];
        var bottom = last.getBoundingClientRect().top + scrollY + last.offsetHeight;
        var pct = (scrollY + navH - top) / Math.max(1, bottom - top);
        pct = Math.max(0, Math.min(1, pct));
        var h = rail.querySelector(".toc-rail-track").offsetHeight;
        fill.style.height = (pct * h) + "px";
      }
    }

    var ticking = false;
    function onScroll() {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(function () { update(); ticking = false; });
    }
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    update();
  }

  /* ------------------------------------------------------ */
  function boot() {
    initReveal();
    initNav();
    initCode();
    initToc();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
