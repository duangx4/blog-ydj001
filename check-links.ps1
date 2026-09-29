# ============================================================================
# 资源链接巡检脚本
# 用法: powershell -File check-links.ps1
#      powershell -File check-links.ps1 -Path content/resources
#      powershell -File check-links.ps1 -SkipNetdisk      # 跳过网盘（更快）
#
# 说明:
#   - 扫描 content/**/*.md 里出现的所有 http(s) 链接（含 download-table /
#     pan-link 短代码内的 URL，以及 frontmatter、正文里的外链）
#   - 逐个发请求判定：可用 / 失效 / 需人工确认
#   - 有「失效」链接时以退出码 1 结束，方便挂到发布前检查
#   - 只读：不会改动任何文件
# ============================================================================

param(
    [string]$Path  = "content",
    [int]$TimeoutSec = 15,
    [int]$Retry      = 2,
    [switch]$SkipNetdisk
)

$ErrorActionPreference = 'Stop'

# 控制台按 UTF-8 输出，否则 PS 5.1 在中文环境下表格里的中文会乱码
try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $OutputEncoding = [Text.Encoding]::UTF8
} catch { }

# --------------------- 配置区 ---------------------
$BlogDir  = "C:\Users\21972\Desktop\blog-ydj001"
$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ydj001-link-checker/1.0"

# 网盘/跳转类：HEAD 常返回 403 或需要登录，不能据此判失效 → 只提示人工确认
$NetdiskHosts = @(
    'pan.baidu.com', 'yun.baidu.com',
    'pan.quark.cn', 'drive.uc.cn',
    'www.aliyundrive.com', 'www.alipan.com',
    'cloud.189.cn', 'caiyun.139.com',
    'lanzou', '123pan.com', 'mypikpak.com'
)
# --------------------------------------------------

# 颜色
function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "    XX  $msg" -ForegroundColor Red }

# PS 5.1 默认 TLS 1.0，不少站点已拒绝；证书过期也先放过（只是巡链，不涉及敏感数据）
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
} catch { Warn "无法放宽证书校验，个别自签证书站点可能误报" }

Step "扫描目录: $Path"

$root = Join-Path $BlogDir $Path
if (-not (Test-Path $root)) { Fail "目录不存在: $root"; exit 2 }

$files = Get-ChildItem -Path $root -Recurse -Filter *.md -File
if (-not $files) { Fail "没有找到 .md 文件"; exit 2 }

# ---------- 1. 提取 URL ----------
# 截断在反引号、括号、表格分隔符、空白和中文标点处。反引号那一段是必需的：
# markdown 常写成 `https://x.com/...`——说明，不排掉反引号就会把说明文字一起当 URL
# （曾抓出 "https://minotar.net/skin/%player%`（按玩家名查皮肤）。注意" 这种脏值）
$pattern = 'https?://[^\s"''`()<>|\]一-鿿　-〿＀-￯]+'
$urlMap  = @{}   # url -> 出现位置列表

foreach ($f in $files) {
    $text  = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $lines = $text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($m in [regex]::Matches($lines[$i], $pattern)) {
            $u = $m.Value.TrimEnd('.', ',', ';', '，', '。')
            if (-not $urlMap.ContainsKey($u)) { $urlMap[$u] = @() }
            $rel = $f.FullName.Substring($BlogDir.Length + 1)
            $urlMap[$u] += "$rel`:$($i + 1)"
        }
    }
}

if ($urlMap.Count -eq 0) { Ok "没有发现任何链接"; exit 0 }
Step "发现 $($urlMap.Count) 个唯一链接，开始逐个检查（超时 ${TimeoutSec}s，重试 $Retry 次）"

# ---------- 2. 逐个检查 ----------
# 探测后端用 curl.exe（Windows 10+ 自带），而不是 Invoke-WebRequest。原因：
#   1) PS 的 schannel 对部分站点 HEAD 会在 TLS 握手就失败，报「基础连接已经关闭」，
#      但同一 URL 用 curl 请求正常 → 用 PS 会大量误报失效
#   2) PS 不允许通过 -Headers 设置 Range（受限请求头），没法只取前 1KB
#      curl -r 0-1023 可以，服务端正常回 206，既能确认资源存在又不下载整包

$CurlExe = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source

function Test-Url($url) {
    if (-not $CurlExe) { return @{ Code = $null; Err = 'curl.exe 不可用' } }

    $lastCode = $null
    $lastErr  = $null

    for ($attempt = 1; $attempt -le ($Retry + 1); $attempt++) {
        # 先 HEAD；失败再 GET + Range（只取前 1KB）
        foreach ($mode in @('head', 'range')) {
            # 注意：不能用 $args，那是 PowerShell 自动变量
            # 也不要给 curl 加 -S：它把错误写 stderr，PS 5.1 会当成 NativeCommandError
            # 记进 $Error 并可能中断脚本。错误情况统一靠 %%{http_code} 和退出码判断。
            $curlArgs = @('-s', '-L', '-m', $TimeoutSec, '-A', $UserAgent,
                          '--write-out', "%{http_code}`t%{size_download}", '-o', 'NUL')
            if ($mode -eq 'head') { $curlArgs += '-I' } else { $curlArgs += @('-r', '0-1023') }
            $curlArgs += $url

            $out = & $CurlExe @curlArgs 2>&1 | Out-String
            $curlExit = $LASTEXITCODE
            $errText = ''
            $code = $null

            foreach ($line in @($out)) {
                $t = "$line".Trim()
                if ($t -match '^(\d{3})\t(\d+)$') { $code = [int]$Matches[1] }
            }
            if (-not $code) { $errText = ("$out" -replace '\s+', ' ').Trim() }

            if ($code) {
                # 2xx/3xx = 可用；其余把状态码交给上层分类
                return @{ Code = $code; Err = $errText }
            }

            $lastCode = $null
            $lastErr  = if ($errText) { $errText } else { '连接失败' }
        }
        if ($attempt -le $Retry) { Start-Sleep -Milliseconds 600 }
    }
    return @{ Code = $lastCode; Err = $lastErr }
}

$okList = @(); $badList = @(); $manualList = @()

foreach ($url in ($urlMap.Keys | Sort-Object)) {
    $where  = ($urlMap[$url] -join ', ')
    $isNetdisk = $false
    foreach ($h in $NetdiskHosts) { if ($url -like "*$h*") { $isNetdisk = $true; break } }

    if ($isNetdisk -and $SkipNetdisk) {
        $manualList += [pscustomobject]@{ Url = $url; Code = 'skip'; Where = $where; Why = '网盘（-SkipNetdisk）' }
        continue
    }

    Write-Host "    ... $url" -ForegroundColor DarkGray
    $r = Test-Url $url

    if ($r.Err -and -not $r.Code) {
        # 连不上：DNS / 超时 / TLS。网盘多为反爬，不算硬失效
        if ($isNetdisk) {
            $manualList += [pscustomobject]@{ Url = $url; Code = 'conn'; Where = $where; Why = '网盘，请求被拒需人工打开' }
        } else {
            $badList += [pscustomobject]@{ Url = $url; Code = 'ERR'; Where = $where; Why = $r.Err }
        }
    }
    elseif ($r.Code -ge 200 -and $r.Code -lt 400) {
        $okList += [pscustomobject]@{ Url = $url; Code = $r.Code; Where = $where; Why = '' }
    }
    elseif ($r.Code -eq 401 -or $r.Code -eq 403) {
        $why = if ($isNetdisk) { '网盘/防盗链，需人工打开' } else { '需鉴权或拒绝访问，人工确认' }
        $manualList += [pscustomobject]@{ Url = $url; Code = $r.Code; Where = $where; Why = $why }
    }
    elseif ($r.Code -eq 404 -or $r.Code -eq 410) {
        $badList += [pscustomobject]@{ Url = $url; Code = $r.Code; Where = $where; Why = '链接失效' }
    }
    else {
        $manualList += [pscustomobject]@{ Url = $url; Code = $r.Code; Where = $where; Why = '状态码异常，人工确认' }
    }
}

# ---------- 3. 报告 ----------
Write-Host ''
Write-Host '================ 巡检结果 ================' -ForegroundColor Cyan

if ($badList.Count -gt 0) {
    Fail "失效 $($badList.Count) 个："
    $badList | Format-Table -AutoSize -Wrap Url, Code, Where, Why | Out-String -Width 200 | Write-Host
} else {
    Ok "没有发现失效链接"
}

if ($manualList.Count -gt 0) {
    Warn "需人工确认 $($manualList.Count) 个："
    $manualList | Format-Table -AutoSize -Wrap Url, Code, Where, Why | Out-String -Width 200 | Write-Host
}

Ok "可用 $($okList.Count) 个"
if ($okList.Count -gt 0) {
    $okList | Format-Table -AutoSize -Wrap Url, Code | Out-String -Width 200 | Write-Host
}

Write-Host "合计: 可用 $($okList.Count) / 失效 $($badList.Count) / 待确认 $($manualList.Count)" -ForegroundColor Cyan

if ($badList.Count -gt 0) { exit 1 } else { exit 0 }
