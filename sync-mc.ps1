# ============================================================================
# MC 页面一键同步脚本（独立站 + 博客站）
# 用法: powershell -File sync-mc.ps1
#
# 说明:
#   - 源文件: C:\Users\21972\Desktop\blog-ydj001\static\mc\  (改这里!)
#   - 目标1:  https://mc.ydj001.xyz       (独立宣传站)
#   - 目标2:  https://ydj001.xyz/mc/      (博客子路径)
#   - 图片自动同步, 自动校验 MD5
# ============================================================================

$ErrorActionPreference = 'Stop'

# --------------------- 配置区 ---------------------
$McDir     = "C:\Users\21972\Desktop\blog-ydj001\static\mc"
$Server    = "root@154.12.85.12"
$SshKey    = "$env:USERPROFILE\.ssh\id_ed25519"
$Site1Root = "/var/www/mc.ydj001.xyz"      # 独立站
$Site2Root = "/var/www/ydj001.xyz/mc"      # 博客站
$Images    = @('hero.jpg','feature-1.jpg','feature-2.jpg','feature-3.jpg',
               'gallery-1.jpg','gallery-2.jpg','gallery-3.jpg','gallery-4.jpg','gallery-5.jpg')
# --------------------------------------------------

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "    XX  $msg" -ForegroundColor Red; exit 1 }

# 预检
Step "预检"
if (-not (Test-Path "$McDir\index.html")) { Fail "未找到 $McDir\index.html" }
if (-not (Test-Path $SshKey)) { Fail "未找到 SSH 私钥: $SshKey" }
Ok "源文件与密钥就绪"

# 上传 index.html 到两个站 (一次 scp 传两个目标目录, 用中间文件避免重复)
Step "上传 index.html"
# scp 到独立站和博客站用两次调用即可, 保持简单
scp -i $SshKey -o BatchMode=yes "$McDir\index.html" "${Server}:${Site1Root}/index.html"
if ($LASTEXITCODE -ne 0) { Fail "上传独立站失败" }
scp -i $SshKey -o BatchMode=yes "$McDir\index.html" "${Server}:${Site2Root}/index.html"
if ($LASTEXITCODE -ne 0) { Fail "上传博客站失败" }
Ok "index.html 已上传"

# 上传图片（显式列表，避免通配符问题）
Step "上传图片 ($($Images.Count) 张)"
$imgArgs = @()
foreach ($img in $Images) {
    $p = "$McDir\img\$img"
    if (Test-Path $p) { $imgArgs += $p }
}
if ($imgArgs.Count -gt 0) {
    scp -i $SshKey -o BatchMode=yes @imgArgs "${Server}:${Site1Root}/img/"
    if ($LASTEXITCODE -ne 0) { Fail "上传独立站图片失败" }
    scp -i $SshKey -o BatchMode=yes @imgArgs "${Server}:${Site2Root}/img/"
    if ($LASTEXITCODE -ne 0) { Fail "上传博客站图片失败" }
}
Ok "图片已上传"

# 远端校验: 先算本地 MD5, 再比对远端 (一次 ssh 批量获取)
Step "MD5 校验"
$fail = 0
# 构建远端 md5sum 命令: 对两个站的所有文件一次性计算
$remotePaths = @()
foreach ($site in @($Site1Root, $Site2Root)) {
    $remotePaths += "$site/index.html"
    foreach ($img in $Images) { $remotePaths += "$site/img/$img" }
}
$md5Output = ssh -i $SshKey -o BatchMode=yes $Server "cd / && md5sum $($remotePaths -join ' ')" 2>&1
if ($LASTEXITCODE -ne 0) { Fail "远端 md5sum 执行失败" }
# 解析远端输出: "<md5>  <path>"
$remoteMap = @{}
foreach ($line in $md5Output) {
    if ($line -match '^([0-9a-f]{32})\s+(.+)$') {
        $remoteMap[$matches[2].Trim()] = $matches[1]
    }
}
# 比对 index.html
$localMd5 = (Get-FileHash "$McDir\index.html" -Algorithm MD5).Hash.ToLower()
foreach ($site in @($Site1Root, $Site2Root)) {
    $key = "$site/index.html"
    $remoteMd5 = $remoteMap[$key]
    if ($remoteMd5 -eq $localMd5) { Ok "index.html 一致 ($site)" }
    else { Warn "index.html 不一致! ($site)"; $fail = 1 }
}
# 比对图片
foreach ($img in $Images) {
    $p = "$McDir\img\$img"
    if (-not (Test-Path $p)) { continue }
    $localMd5 = (Get-FileHash $p -Algorithm MD5).Hash.ToLower()
    foreach ($site in @($Site1Root, $Site2Root)) {
        $key = "$site/img/$img"
        $remoteMd5 = $remoteMap[$key]
        if ($remoteMd5 -eq $localMd5) { Ok "$img 一致 ($site)" }
        else { Warn "$img 不一致! ($site)"; $fail = 1 }
    }
}
if ($fail -ne 0) { Fail "存在不一致文件, 请检查" }

# 修权限
Step "修正权限"
ssh -i $SshKey -o BatchMode=yes $Server "chown -R www-data:www-data $Site1Root/ $Site2Root/"
if ($LASTEXITCODE -ne 0) { Fail "chown 失败" }
Ok "权限已修正"

Write-Host ""
Ok "同步完成!"
Write-Host "    https://mc.ydj001.xyz" -ForegroundColor Yellow
Write-Host "    https://ydj001.xyz/mc/" -ForegroundColor Yellow
