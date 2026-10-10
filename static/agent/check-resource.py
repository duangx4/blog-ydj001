#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""资源投稿自检：校验 content/resources/<slug>/ 是否符合投稿契约。

用法:
    python3 check-resource.py content/resources/<slug> [--author <GitHub登录名>] [--max-size-mib 20]

退出码：0 = PASS（可能带 WARN），1 = FAIL。
契约：https://ydj001.xyz/agent/publish.md
不依赖任何第三方库（自带极简 front matter 解析，不需要 PyYAML）。

注意：上限 20 MiB 与 static/admin/config.yml 里 CMS 的 max_file_size 是一套，
改一个要同时改另一个（AGENTS.md「必须成对」）。
"""

import argparse
import datetime
import os
import re
import sys

SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
REQUIRED_FIELDS = ("title", "authors", "date", "description")
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".avif")

# 凭据 / 敏感串形态：命中即 FAIL
SECRET_PATTERNS = (
    (r"ghp_[A-Za-z0-9]{20,}", "GitHub PAT"),
    (r"github_pat_[A-Za-z0-9_]{20,}", "GitHub fine-grained PAT"),
    (r"gho_[A-Za-z0-9]{20,}", "GitHub OAuth token"),
    (r"sk-[A-Za-z0-9]{16,}", "API key (sk-)"),
    (r"AKIA[0-9A-Z]{16}", "AWS Access Key"),
    (r"xox[baprs]-[A-Za-z0-9-]{10,}", "Slack token"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "私钥"),
)
# 内网地址：只提醒，不拦（教程里出现 192.168.x.x 很正常）
PRIVATE_IP_PATTERNS = (
    r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b",
    r"\b192\.168\.\d{1,3}\.\d{1,3}\b",
    r"\b172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}\b",
)

errors = []
warnings = []
notes = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def strip_comment(s):
    """去掉行尾注释（引号内、以及 URL 里紧贴的 # 不算）。"""
    out = []
    quote = None
    for ch in s:
        if quote:
            if ch == quote:
                quote = None
            out.append(ch)
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#" and out and out[-1] in " \t":
            break
        else:
            out.append(ch)
    return "".join(out).rstrip()


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def parse_scalar(v):
    v = strip_comment(v).strip()
    if v.startswith("[") and v.endswith("]"):
        inner = v[1:-1].strip()
        return [unquote(x.strip()) for x in inner.split(",")] if inner else []
    return unquote(v)


def split_front_matter(text):
    if not text.lstrip().startswith("---"):
        return None, text
    m = re.match(r"^\s*---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)$", text, re.S)
    if not m:
        return None, text
    return m.group(1), m.group(2)


def parse_front_matter(raw):
    """极简 YAML：只认投稿契约用到的形态（顶层 key、缩进列表、行内列表、注释、引号）。"""
    data = {}
    cur = None
    for line in raw.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        body = strip_comment(line.strip())
        if not body:
            continue
        if indent > 0 and cur:
            if body.startswith("-"):
                item = body[1:].strip()
                if ":" in item and not item.startswith(("http://", "https://")):
                    item = item.split(":", 1)[1].strip()
                if isinstance(data.get(cur), list):
                    data[cur].append(unquote(item))
            continue
        if ":" not in body:
            continue
        key, _, val = body.partition(":")
        key = key.strip()
        val = val.strip()
        if val == "":
            data[key] = []
            cur = key
        else:
            data[key] = parse_scalar(val)
            cur = None
    return data


def _human_delta(seconds):
    """把秒数说成人话：3 分钟 / 2.5 小时 / 3 天。"""
    if seconds < 0:
        seconds = -seconds
    if seconds < 90:
        return "%d 秒" % int(seconds)
    if seconds < 5400:
        return "%d 分钟" % int(seconds / 60)
    if seconds < 172800:
        return "%.1f 小时" % (seconds / 3600.0)
    return "%.1f 天" % (seconds / 86400.0)


def as_list(v):
    if v is None:
        return []
    if isinstance(v, list):
        return [str(x) for x in v]
    return [str(v)]


def check_front_matter(fm, author):
    missing = [k for k in REQUIRED_FIELDS if k not in fm]
    if missing:
        err("front matter 缺必填字段：%s（见契约 §3）" % "、".join(missing))
        return
    notes.append("front matter 必填字段齐全")

    title = fm.get("title")
    if isinstance(title, str) and title.strip():
        notes.append("标题：%s" % title.strip())
    else:
        err("title 是空的")

    desc = fm.get("description")
    if isinstance(desc, str) and not desc.strip():
        err("description 是空的（它会显示在资源卡片上）")
    elif isinstance(desc, str) and len(desc.strip()) > 120:
        warn("description 有 %d 字，建议压到 30–60 字，卡片上会被截" % len(desc.strip()))

    authors = [a for a in as_list(fm.get("authors")) if a and a != "-"]
    if not authors:
        err("authors 是空的，必须写上投稿人本人的 GitHub 登录名")
    elif author and author not in authors:
        err("authors 里没有 %s（当前是：%s）——CI 的归属校验会打回"
            % (author, ", ".join(authors) or "空"))
    elif author:
        notes.append("署名包含 %s" % author)
    if len(authors) > 1:
        warn("authors 填了 %d 个（%s）——资源页只署一个人，多了容易和归属校验打架"
             % (len(authors), ", ".join(authors)))

    cats = as_list(fm.get("categories"))
    if cats and "资源分享" not in cats:
        warn("categories 建议写成 [\"资源分享\"]（当前：%s）" % ", ".join(cats))

    draft = str(fm.get("draft", "")).strip().lower()
    if draft in ("true", "yes", "1"):
        err("draft: true —— 资源页上不会出现这篇文章，改成 false")

    date = str(fm.get("date", "")).strip().strip('"').strip("'")
    if date in ("", "[]"):
        err("date 是空的——必填，填提交当时的当前时间（格式示例：2026-09-01T10:00:00+08:00）")
        date = ""
    if date:
        dt = None
        try:
            dt = datetime.datetime.fromisoformat(date.replace("Z", "+00:00"))
        except ValueError:
            warn("date 不是合法 ISO 8601（建议 2026-09-01T10:00:00+08:00）：%s——这种 Hugo 解析不了，构建会直接报错（CI 的 build 会红）" % date)
        if dt is not None:
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=datetime.timezone.utc)  # Hugo 对不带时区的日期按 UTC 算
            delta = (dt - datetime.datetime.now(datetime.timezone.utc)).total_seconds()
            if delta > 600:
                err("date 是未来的时间（%s，比现在晚 %s）——站点配置里 buildFuture=false，"
                    "合并后这个页面根本不会生成；改成当前时间或更早"
                    % (date, _human_delta(delta)))
            elif delta > 0:
                warn("date 比现在晚 %s（未来时间）：Hugo 默认不发布未来页面，确认不是写错"
                     % _human_delta(delta))
        if date[:4].isdigit() and int(date[:4]) > datetime.datetime.now().year:
            warn("date 的年份是 %s，确认不是手误" % date[:4])
    if "lastmod" in fm:
        lm = str(fm.get("lastmod", "")).strip()
        try:
            lmdt = datetime.datetime.fromisoformat(lm.replace("Z", "+00:00"))
        except ValueError:
            lmdt = None
        if lmdt is not None:
            if lmdt.tzinfo is None:
                lmdt = lmdt.replace(tzinfo=datetime.timezone.utc)
            if (lmdt - datetime.datetime.now(datetime.timezone.utc)).total_seconds() > 86400:
                warn("lastmod 比现在晚了一天以上（%s），确认时间没写错" % lm)


def check_files(bundle, fm, max_bytes):
    cover = fm.get("cover")
    cover = cover if isinstance(cover, str) else ""
    cover = cover.strip().strip('"').strip("'")
    if cover and "://" not in cover:
        if not os.path.isfile(os.path.join(bundle, cover)):
            err("cover 写的 %s 在文章目录里不存在（封面图要和 index.md 放同一目录）" % cover)
        elif not cover.lower().endswith(IMG_EXT):
            warn("cover 是 %s，不是常见图片扩展名" % cover)

    for item in as_list(fm.get("attachments")):
        item = item.strip().strip('"').strip("'")
        if not item or item == "-" or "://" in item:
            continue
        if not os.path.isfile(os.path.join(bundle, item)):
            err("attachments 里的 %s 不存在" % item)


def check_sizes(bundle, max_bytes):
    total = 0
    for root, _dirs, files in os.walk(bundle):
        for name in files:
            path = os.path.join(root, name)
            size = os.path.getsize(path)
            total += size
            if size > max_bytes:
                err("%s 有 %.1f MiB，超过 %.0f MiB 上限：放网盘，正文用 pan-link"
                    % (os.path.relpath(path, bundle), size / 1048576.0, max_bytes / 1048576.0))
    if total > max_bytes:
        warn("这个资源总共 %.1f MiB（单个文件都合格，但整个目录偏大）" % (total / 1048576.0))


def check_sensitive(bundle):
    for root, _dirs, files in os.walk(bundle):
        for name in files:
            path = os.path.join(root, name)
            if os.path.getsize(path) > 4 * 1048576:
                continue
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except OSError:
                continue
            rel = os.path.relpath(path, bundle)
            for pattern, label in SECRET_PATTERNS:
                if re.search(pattern, text):
                    err("%s 里出现疑似%s，凭据不能进仓库（契约 §10）" % (rel, label))
            for pattern in PRIVATE_IP_PATTERNS:
                if re.search(pattern, text):
                    warn("%s 里出现内网地址，确认不是内部资料" % rel)


def check_shortcodes(body, bundle):
    dt_opens = re.findall(r"\{\{[<%]\s*download-table\b", body)
    dt_closes = re.findall(r"\{\{[<%]\s*/download-table\s*[>%]\}\}", body)
    if len(dt_opens) != len(dt_closes):
        err("download-table 开合不配对：%d 个开头、%d 个结尾" % (len(dt_opens), len(dt_closes)))

    for block in re.findall(r"\{\{[<%]\s*download-table\b.*?[>%]\}\}(.*?)\{\{[<%]\s*/download-table\s*[>%]\}\}",
                            body, re.S):
        for line in block.splitlines():
            line = line.strip()
            if not line:
                continue
            cells = [c.strip() for c in line.split("|")]
            if len(cells) > 6:
                err("下载表格有 %d 列，超过 6 列上限（第 7 列起会被忽略）：%s"
                    % (len(cells), line[:60]))
            elif len(cells) < 3:
                warn("下载表格这行只有 %d 列（最少 3 列，按「名称|大小|下载」理解）：%s"
                     % (len(cells), line[:60]))
            last = cells[-1]
            if last and last != "-" and not last.startswith(("http://", "https://")):
                if os.path.isfile(os.path.join(bundle, last)):
                    notes.append("下载按钮指向附件 %s" % last)
                else:
                    warn("「下载」那格写的 %s 既不是 URL 也不是本目录文件，页面上只会显示纯文本"
                         % last)

    for attrs in re.findall(r"\{\{[<%]\s*pan-link\b(.*?)[>%]\}\}", body, re.S):
        params = dict(re.findall(r"(\w+)\s*=\s*\"([^\"]*)\"", attrs))
        if not params.get("name"):
            err("pan-link 缺 name 参数")
        url = params.get("url", "")
        if not url:
            err("pan-link 缺 url 参数")
        elif not url.startswith(("http://", "https://")):
            err("pan-link 的 url 必须以 http(s):// 开头：%s" % url)

    if "download-table" not in body and "pan-link" not in body:
        warn("正文里没有 download-table / pan-link，读者找不到下载入口")


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("target", help="content/resources/<slug> 目录或其中的 index.md")
    ap.add_argument("--author", default="", help="投稿人的 GitHub 登录名（CI 会传 PR 作者）")
    ap.add_argument("--max-size-mib", type=float, default=20.0)
    args = ap.parse_args()

    target = args.target.rstrip("/")
    if target.endswith(".md"):
        bundle, index = os.path.dirname(target) or ".", target
    else:
        bundle, index = target, os.path.join(target, "index.md")

    print("资源自检：%s（契约 v1）" % bundle)
    max_bytes = int(args.max_size_mib * 1048576)

    slug = os.path.basename(os.path.abspath(bundle))
    if not SLUG_RE.match(slug):
        err("slug（目录名）%r 不合规：只能用英文小写、数字和 -（如 stm32-toolbox）" % slug)
    elif len(slug) > 40:
        err("slug 有 %d 个字符，超过 40 字符上限" % len(slug))
    elif len(slug) < 2:
        warn("slug 只有 %d 个字符，建议 2–40 字符（网址好认一点）" % len(slug))
    else:
        notes.append("slug 合法：%s" % slug)
    if "/content/resources/" not in os.path.abspath(bundle).replace("\\", "/"):
        warn("目录不在 content/resources/ 下，确认路径没写错")

    if not os.path.isfile(index):
        err("找不到 %s：资源文章必须是 content/resources/<slug>/index.md" % index)
    else:
        with open(index, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        raw_fm, body = split_front_matter(text)
        if raw_fm is None:
            err("%s 开头缺少 --- 包裹的 front matter" % index)
        else:
            fm = parse_front_matter(raw_fm)
            check_front_matter(fm, args.author.strip())
            check_files(bundle, fm, max_bytes)
        if not body.strip():
            err("正文是空的，至少要写「这是什么」和「下载」")
        else:
            check_shortcodes(body, bundle)

    check_sizes(bundle, max_bytes)
    check_sensitive(bundle)

    for n in notes:
        print("  ·  %s" % n)
    for w in warnings:
        print("  ⚠  %s" % w)
    for e in errors:
        print("  ✗  %s" % e)

    if errors:
        print("\n结果：FAIL（%d 个错误，%d 个提醒）" % (len(errors), len(warnings)))
        return 1
    print("\n结果：PASS（%d 个提醒）" % len(warnings))
    return 0


if __name__ == "__main__":
    sys.exit(main())
