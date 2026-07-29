# ============================================================================
# AI 文章封面生成脚本 v1
# 用法: powershell -File generate-cover.ps1 -Slug "xxx" [-Prompt "自定义提示词"]
#       不传 Slug 则为所有无封面的文章生成
#
# 依赖:
#   - SiliconFlow API Key（从 $envPath 读取）
#   - .NET System.Drawing 用于裁剪
# ============================================================================

param(
    [string]$Slug = "",
    [string]$Prompt = ""
)

# --------------------- 配置 ---------------------
$blogDir = "C:\Users\21972\Desktop\blog-ydj001\content\blog"
$envPath = "C:\Users\21972\.ppt-master\.env"
# ------------------------------------------------

# 颜色
function Step($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "    XX  $msg" -ForegroundColor Red }

# 读取 API Key
$apiKey = ""
if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Encoding UTF8
    foreach ($line in $envContent) {
        if ($line -match '^SILICONFLOW_API_KEY=(.+)') {
            $apiKey = $matches[1].Trim('"').Trim("'")
        }
    }
}
if (-not $apiKey) {
    Fail "未找到 SILICONFLOW_API_KEY（请检查 $envPath）"
    exit 1
}
Ok "API Key 已读取"

# 封面提示词映射（按文章 slug）
$promptMap = @{
    "build-blog-from-scratch" = "A laptop displaying a code editor and terminal with Hugo static site generator commands, dark mode, minimalist tech aesthetic, blue and purple neon glow, website building concept, abstract server connections, 3D isometric style, high quality"
    "deploy-frp-tunnel" = "Network tunnel visualization, glowing blue data streams flowing through a digital tunnel connecting two servers, abstract network topology, dark tech background, neon cyan and purple, data packets visualized as glowing dots, futuristic infrastructure concept, 3D isometric, high quality"
    "pre-blog-dev-projects" = "Two connected server racks, data synchronization visualization, Docker containers abstract representation, glowing blue and purple network lines between machines, cloud infrastructure concept, dark tech theme, 3D isometric style, high quality digital illustration"
    "ppt-template-cloning-war" = "A battle or competition concept between two robots or AI agents, one holding a PowerPoint slide template, the other holding code scripts, minimalist tech style, glowing neon blue and red accents, dark background, futuristic presentation automation concept, 3D isometric, high quality digital illustration"
    "blog-evolution" = "A personal blog website cover image, dark tech theme, minimalistic, showing a laptop with code editor and blog interface on screen, glowing neon blue and purple lines connecting server nodes, abstract cloud infrastructure visualization, digital atmosphere, high quality, 16:9 composition suitable for blog cover"
}

# 获取文章列表
$articles = @()
if ($Slug) {
    $mdPath = Join-Path $blogDir "$Slug.md"
    if (Test-Path $mdPath) {
        $articles += @{slug=$Slug; mdPath=$mdPath; dir=Join-Path $blogDir $Slug}
    } else {
        Fail "未找到文章：$Slug"
        exit 1
    }
} else {
    # 找所有无封面的文章
    Get-ChildItem $blogDir -Filter "*.md" -File | Where-Object { $_.BaseName -ne "_index" } | ForEach-Object {
        $slug = $_.BaseName
        $dir = Join-Path $blogDir $slug
        $hasCover = (Test-Path (Join-Path $dir "featured.png")) -or (Test-Path (Join-Path $dir "featured.jpg"))
        if (-not $hasCover) {
            $articles += @{slug=$slug; mdPath=$_.FullName; dir=$dir}
        }
    }
}

if ($articles.Count -eq 0) {
    Warn "所有文章已有封面或没有符合条件的文章"
    exit 0
}

Step "需要生成封面的文章：$($articles.Count) 篇"
$articles | ForEach-Object { Write-Host "  - $($_.slug)" -ForegroundColor Yellow }

# 生图 API
$apiUrl = "https://api.siliconflow.cn/v1/images/generations"

# 加载 System.Drawing（用于裁剪）
Add-Type -AssemblyName System.Drawing

function Generate-Cover {
    param($slug, $prompt)
    
    Step "[$slug] 生成中..."
    
    # 调用 API
    $body = @{
        model = "Tongyi-MAI/Z-Image-Turbo"
        n = 1
        size = "1024x1024"
        prompt = $prompt
    } | ConvertTo-Json -Compress
    
    try {
        $r = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        } -Body $body -TimeoutSec 60
    } catch {
        Fail "[$slug] API 调用失败：$_"
        return $false
    }
    
    $imageUrl = $r.images[0].url
    Write-Host "        seed=$($r.seed) | inference=$($r.timings.inference)s"
    
    # 下载
    $tmp = Join-Path $env:TEMP "${slug}_cover_raw.png"
    curl.exe -s -o $tmp $imageUrl
    if (-not (Test-Path $tmp)) {
        Fail "[$slug] 下载失败"
        return $false
    }
    Write-Host "        已下载：$( (Get-Item $tmp).Length ) bytes"
    
    # 确保目标目录存在
    $dir = Join-Path $blogDir $slug
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $out = Join-Path $dir "featured.png"
    
    # 裁剪为 16:9 (1200x675)
    try {
        $img = [System.Drawing.Image]::FromFile($tmp)
        $w = $img.Width
        $h = $img.Height
        
        $targetRatio = 1200 / 675
        if ($w / $h -gt $targetRatio) {
            $newW = [int]($h * $targetRatio)
            $offset = [int](($w - $newW) / 2)
            $crop = $img.Clone([System.Drawing.Rectangle]::new($offset, 0, $newW, $h), $img.PixelFormat)
        } else {
            $newH = [int]($w / $targetRatio)
            $offset = [int](($h - $newH) / 2)
            $crop = $img.Clone([System.Drawing.Rectangle]::new(0, $offset, $w, $newH), $img.PixelFormat)
        }
        
        $resized = [System.Drawing.Bitmap]::new($crop, 1200, 675)
        $resized.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose(); $crop.Dispose(); $resized.Dispose()
        
        Ok "[$slug] 封面已保存：$( (Get-Item $out).Length ) bytes"
        return $true
    } catch {
        Fail "[$slug] 裁剪失败：$_"
        return $false
    }
}

# 逐一生成
$success = 0
$failed = 0

foreach ($article in $articles) {
    $slug = $article.slug
    $prompt = if ($Prompt) { $Prompt } elseif ($promptMap.ContainsKey($slug)) { $promptMap[$slug] } else { "" }
    
    if (-not $prompt) {
        Warn "[$slug] 没有提示词，跳过"
        continue
    }
    
    if (Generate-Cover -slug $slug -prompt $prompt) {
        $success++
    } else {
        $failed++
    }
}

# 总结
if ($failed -eq 0) {
    Ok "全部完成！$success 篇封面已生成"
} else {
    Warn "完成：$success 成功，$failed 失败"
}

Write-Host ""
Write-Host "提示：运行 deploy-blog.ps1 部署上线" -ForegroundColor Cyan
