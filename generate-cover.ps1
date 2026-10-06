# ============================================================================
# AI 文章封面生成脚本 v2
# 用法: powershell -ExecutionPolicy Bypass -File .\generate-cover.ps1 -Slug "xxx" [-Prompt "自定义提示词"]
#       不传 -Slug 则为所有【无封面】的文章生成；加 -Force 则连已有封面一起重出
#
# v1 -> v2 变更：
#   v1 调硅基流动 Z-Image（已停用）；v2 改调本机 DAX 出图 API（https://img.ydj001.xyz，
#   botcf 中转的 gpt-image 系列）。出图后在本地裁成 16:9 存 featured.png。
#
# 依赖:
#   - 出图通行证 token（见下方“读取 token”，仓库是公开仓库，token 绝不写进本文件）
#   - .NET System.Drawing 用于裁剪（Windows PowerShell 自带）
# ============================================================================

param(
    [string]$Slug       = "",
    [string]$Prompt     = "",
    [string]$Model      = "gpt-image-2.5-flare-4k",
    [string]$BlogDir    = "",
    [string]$TokenFile  = "",
    [string]$BaseUrl    = "https://img.ydj001.xyz",
    [int]   $TimeoutSec = 300,
    [int]   $Width      = 1200,
    [int]   $Height     = 675,
    [switch]$Force,
    [switch]$NoQuota
)

$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

# 颜色输出（必须在配置段之前定义：先用到后定义会 not recognized）
function Step($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "    XX  $msg" -ForegroundColor Red }

# --------------------- 配置 ---------------------
$repoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $BlogDir) {
    $BlogDir = Join-Path $repoRoot "content\blog"
    if (-not (Test-Path $BlogDir)) {
        Fail "找不到文章目录：$BlogDir（用 -BlogDir 指定仓库的 content/blog）"
        exit 1
    }
}
# 浏览器 UA：Cloudflare 会 403 掉默认 UA 的请求（curl / PowerShell 默认 UA 都会中招）
$Script:UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
# ------------------------------------------------

# 读取 token：环境变量 IMGEN_HTTP_TOKEN -> -TokenFile -> 默认 .env 文件（键名 IMGEN_HTTP_TOKEN）
function Get-ImgenToken {
    if ($env:IMGEN_HTTP_TOKEN) { return $env:IMGEN_HTTP_TOKEN.Trim() }
    $cands = @()
    if ($TokenFile) { $cands += $TokenFile }
    if ($env:USERPROFILE) { $cands += (Join-Path $env:USERPROFILE ".imgen_http.env") }
    $cands += (Join-Path $repoRoot ".env")
    foreach ($c in $cands) {
        if ($c -and (Test-Path $c)) {
            foreach ($line in (Get-Content $c -Encoding UTF8)) {
                if ($line -match '^\s*IMGEN_HTTP_TOKEN\s*=(.+)$') {
                    return $matches[1].Trim().Trim('"').Trim("'")
                }
            }
        }
    }
    return ""
}
$apiKey = Get-ImgenToken
if (-not $apiKey) {
    Fail "未找到 IMGEN_HTTP_TOKEN（设环境变量，或写进 -TokenFile 指定的 .env）"
    exit 1
}
Ok "token 已读取"

# 出图 API 调用（PS 5.1 注意：UA 必须走 -UserAgent，塞进 -Headers 会被 .NET 拒绝；
# body 转 UTF-8 字节再发，否则中文提示词会变乱码）
function Invoke-ImgenApi {
    param([string]$Method, [string]$Url, $BodyObj = $null)
    $headers = @{ "Authorization" = "Bearer $apiKey" }
    if ($null -ne $BodyObj) {
        $json  = $BodyObj | ConvertTo-Json -Compress -Depth 5
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -UserAgent $Script:UA `
            -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 90
    }
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -UserAgent $Script:UA -TimeoutSec 90
}

function Get-ErrText($err) {
    try {
        $resp = $err.Exception.Response
        if ($null -ne $resp) {
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $txt = $sr.ReadToEnd(); $sr.Close()
            if ($txt) { return $txt }
        }
    } catch { }
    return $err.Exception.Message
}

# 封面提示词映射（按文章 slug）
$promptMap = @{
    "build-blog-from-scratch" = "A laptop displaying a code editor and terminal with Hugo static site generator commands, dark mode, minimalist tech aesthetic, blue and purple neon glow, website building concept, abstract server connections, 3D isometric style, high quality"
    "deploy-frp-tunnel" = "Network tunnel visualization, glowing blue data streams flowing through a digital tunnel connecting two servers, abstract network topology, dark tech background, neon cyan and purple, data packets visualized as glowing dots, futuristic infrastructure concept, 3D isometric, high quality"
    "pre-blog-dev-projects" = "Two connected server racks, data synchronization visualization, Docker containers abstract representation, glowing blue and purple network lines between machines, cloud infrastructure concept, dark tech theme, 3D isometric style, high quality digital illustration"
    "ppt-template-cloning-war" = "A battle or competition concept between two robots or AI agents, one holding a PowerPoint slide template, the other holding code scripts, minimalist tech style, glowing neon blue and red accents, dark background, futuristic presentation automation concept, 3D isometric, high quality digital illustration"
    "blog-evolution" = "A personal blog website cover image, dark tech theme, minimalistic, showing a laptop with code editor and blog interface on screen, glowing neon blue and purple lines connecting server nodes, abstract cloud infrastructure visualization, digital atmosphere, high quality, 16:9 composition suitable for blog cover"
    "dax-personal-agent" = "水墨风格的科技插画：画面中央是一座由线条构成的控制中枢，向四周延伸出多条纤细的连接线，连到几台不同形态的设备（笔记本、服务器机柜、手机、天穹上的云）。整体是宣纸般的米色底纹叠加深色墨色，点缀朱砂红与暗金的细线，留白充足，构图克制优雅，扁平插画，无文字，无字母"
}

# 获取文章列表
$articles = @()
if ($Slug) {
    $mdPath = Join-Path $BlogDir "$Slug.md"
    if (Test-Path $mdPath) {
        $articles += @{slug=$Slug; mdPath=$mdPath; dir=Join-Path $BlogDir $Slug}
    } else {
        Fail "未找到文章：$Slug（$mdPath）"
        exit 1
    }
} else {
    Get-ChildItem $BlogDir -Filter "*.md" -File | Where-Object { $_.BaseName -ne "_index" } | ForEach-Object {
        $slug = $_.BaseName
        $dir = Join-Path $BlogDir $slug
        $hasCover = (Test-Path (Join-Path $dir "featured.png")) -or (Test-Path (Join-Path $dir "featured.jpg"))
        if ($Force -or -not $hasCover) {
            $articles += @{slug=$slug; mdPath=$_.FullName; dir=$dir}
        }
    }
}

if ($articles.Count -eq 0) {
    Warn "所有文章已有封面或没有符合条件的文章（要重出加 -Force）"
    exit 0
}

Step "待生成封面：$($articles.Count) 篇"
$articles | ForEach-Object { Write-Host "  - $($_.slug)" -ForegroundColor Yellow }

# 配额预检（顺带验证 token 是否有效，快速失败）
if (-not $NoQuota) {
    try {
        $q = Invoke-ImgenApi -Method Get -Url "$BaseUrl/v1/quota"
        Ok "配额：$($q | ConvertTo-Json -Compress -Depth 5)"
    } catch {
        Warn "配额查询失败（继续）：$(Get-ErrText $_)"
    }
}

# 加载 System.Drawing（用于裁剪；非 Windows 或精简运行时可能没有，此时退化为直接保存原图）
# 注意：只知道程序集能加载还不够 —— GDI+ 在部分 Linux 运行时是"加载成功、调用才炸"，
# 所以这里真建一个 1x1 位图探一次。
$Script:CanCrop = $true
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $probe = [System.Drawing.Bitmap]::new(1, 1)
    $probe.Dispose()
} catch {
    $Script:CanCrop = $false
    Warn "System.Drawing / GDI+ 不可用，将直接保存原图（不裁剪）"
}

function Generate-Cover {
    param($slug, $prompt)

    Step "[$slug] 生成中（$Model）..."

    # 调用 API：同步返回 200，或排队返回 202 + job_id
    $payload = @{
        prompt    = $prompt
        model     = $Model
        n         = 1
        name      = $slug
        requester = "generate-cover.ps1"
    }
    try {
        $r = Invoke-ImgenApi -Method Post -Url "$BaseUrl/v1/images" -BodyObj $payload
    } catch {
        Fail "[$slug] 提交失败：$(Get-ErrText $_)"
        return $false
    }

    $jobId = $r.job_id
    if ($r.status -eq "queued" -or ($r.status -ne "ok" -and $jobId)) {
        Write-Host "        job=$jobId 已入队，等待出图（最长 $TimeoutSec 秒）..."
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 8
            try {
                $r = Invoke-ImgenApi -Method Get -Url "$BaseUrl/v1/jobs/$jobId"
            } catch {
                Warn "查询 job 失败（继续等）：$(Get-ErrText $_)"
                continue
            }
            if ($r.status -eq "ok" -or $r.status -eq "error") { break }
        }
    }

    if ($r.status -ne "ok") {
        Fail "[$slug] 出图未成功：$($r | ConvertTo-Json -Compress -Depth 4)"
        return $false
    }

    $item = @($r.images)[0]
    if ($null -eq $item) {
        Fail "[$slug] 返回里没有图片：$($r | ConvertTo-Json -Compress -Depth 4)"
        return $false
    }

    # 拼出图片地址：优先用 -BaseUrl 拼相对路径（网关的 abs_url 是按 Host / X-Forwarded-Proto
    # 头拼出来的，直连 http://127.0.0.1:7072 这类明文入口时会拼成 https://127.0.0.1:7072
    # 从而握手失败）；相对地址缺失时才退回 abs_url
    $imageUrl = $item.url
    if ($imageUrl -and $imageUrl -notmatch '^https?://') { $imageUrl = "$BaseUrl$imageUrl" }
    if (-not $imageUrl) { $imageUrl = $item.abs_url }

    # 下载
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "$slug`_cover_raw.png"
    try {
        Invoke-WebRequest -Uri $imageUrl -Headers @{ "Authorization" = "Bearer $apiKey" } `
            -UserAgent $Script:UA -OutFile $tmp -TimeoutSec 120
    } catch {
        Fail "[$slug] 下载失败：$(Get-ErrText $_)"
        return $false
    }
    if (-not (Test-Path $tmp)) { Fail "[$slug] 下载失败：文件不存在"; return $false }
    Write-Host "        已下载：$((Get-Item $tmp).Length) bytes"

    # 确保目标目录存在
    $dir = Join-Path $BlogDir $slug
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $out = Join-Path $dir "featured.png"

    # 裁成 16:9（居中裁剪，再缩放到 $Width x $Height）
    # 裁剪失败不能丢图：退化成"保存原图"总比整篇失败强
    $cropped = $false
    if ($Script:CanCrop) {
        $img = $null; $crop = $null; $resized = $null
        try {
            $img = [System.Drawing.Image]::FromFile($tmp)
            $w = $img.Width
            $h = $img.Height

            $targetRatio = $Width / $Height
            if ($w / $h -gt $targetRatio) {
                $newW = [int]($h * $targetRatio)
                $x = [int](($w - $newW) / 2)
                $crop = $img.Clone([System.Drawing.Rectangle]::new($x, 0, $newW, $h), $img.PixelFormat)
            } else {
                $newH = [int]($w / $targetRatio)
                $y = [int](($h - $newH) / 2)
                $crop = $img.Clone([System.Drawing.Rectangle]::new(0, $y, $w, $newH), $img.PixelFormat)
            }

            $resized = [System.Drawing.Bitmap]::new($crop, $Width, $Height)
            $resized.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
            $cropped = $true
        } catch {
            Warn "[$slug] 裁剪失败，改为保存原图：$(Get-ErrText $_)"
        } finally {
            if ($img) { $img.Dispose() }
            if ($crop) { $crop.Dispose() }
            if ($resized) { $resized.Dispose() }
        }
    } else {
        Warn "[$slug] System.Drawing / GDI+ 不可用，保存原图（未裁剪）"
    }

    if (-not $cropped) {
        Copy-Item $tmp $out -Force
        Remove-Item $tmp -ErrorAction SilentlyContinue
        Ok "[$slug] 封面已保存（原图，未裁剪）：$((Get-Item $out).Length) bytes -> $out"
        return $true
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Ok "[$slug] 封面已保存：$((Get-Item $out).Length) bytes -> $out"
    return $true
}

# 逐一生成
$success = 0
$failed = 0

foreach ($article in $articles) {
    $slug = $article.slug
    $prompt = if ($Prompt) { $Prompt } elseif ($promptMap.ContainsKey($slug)) { $promptMap[$slug] } else { "" }

    if (-not $prompt) {
        Warn "[$slug] 没有提示词，跳过（用 -Prompt 指定）"
        continue
    }

    if (Generate-Cover -slug $slug -prompt $prompt) {
        $success++
    } else {
        $failed++
    }
}

# 总结
Write-Host ""
if ($failed -eq 0) {
    Ok "全部完成！$success 篇封面已生成"
} else {
    Warn "完成：$success 成功，$failed 失败"
}

Write-Host ""
Write-Host "提示：改完 git add / commit / push，GitHub Actions 会自动部署上线" -ForegroundColor Cyan
if ($failed -gt 0) { exit 2 }
exit 0
