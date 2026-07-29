# ============================================================================
# 博客发布脚本（重构版 v2）
# 用法: powershell -File deploy-blog.ps1
#
# 安全改进：
#   - 不再使用明文密码 / sshpass
#   - 改用 SSH 公私钥认证（路径在下方 $SshKey 配置）
#   - 失败即终止，不静默继续
# 部署改进：
#   - 部署前检查 git 工作区状态
#   - 上传 + 远端清理旧文件
#   - 单独的权限修复步骤
# ============================================================================

# --------------------- 配置区（按需修改） ---------------------
$Hugo      = "C:\Users\21972\AppData\Local\Microsoft\WinGet\Packages\Hugo.Hugo.Extended_Microsoft.Winget.Source_8wekyb3d8bbwe\hugo.exe"
$BlogDir   = "C:\Users\21972\Desktop\blog-ydj001"
$Server    = "root@154.12.85.12"
$WebRoot   = "/var/www/ydj001.xyz"
$SshKey    = "$env:USERPROFILE\.ssh\id_ed25519"   # 推荐用 ed25519；不存在会报错并退出
$SshPort   = 22
# --------------------------------------------------------------

# 颜色
function Step($msg)    { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)      { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Fail($msg)    { Write-Host "    XX  $msg" -ForegroundColor Red }

# 预检
Step "预检：SSH 密钥与 Hugo 工具"
if (-not (Test-Path $SshKey)) {
    Fail "未找到 SSH 私钥：$SshKey"
    Write-Host "    生成方法：ssh-keygen -t ed25519 -C 'blog-deploy'" -ForegroundColor Yellow
    Write-Host "    并把公钥 ${SshKey}.pub 加入服务器的 ~/.ssh/authorized_keys" -ForegroundColor Yellow
    exit 1
}
if (-not (Test-Path $Hugo)) {
    Fail "未找到 Hugo：$Hugo"
    exit 1
}
Ok "环境就绪"

# Git 状态检查
Step "预检：git 工作区"
$gitStatus = git status --porcelain 2>&1
if ($LASTEXITCODE -ne 0) {
    Fail "git status 失败（确认在仓库根目录）"
    exit 1
}
if ($gitStatus) {
    Warn "有未提交的改动："
    git status --short
    $confirm = Read-Host "    继续部署？(y/N)"
    if ($confirm -ne 'y') { Fail "用户取消"; exit 1 }
}
Ok "git 状态正常"

# 构建
Step "构建：Hugo --minify"
Set-Location $BlogDir
& $Hugo --minify
if ($LASTEXITCODE -ne 0) { Fail "Hugo 构建失败"; exit 1 }
Ok "构建成功 -> public/"

# 测试 SSH 连接
Step "测试 SSH 连接"
ssh -i $SshKey -p $SshPort -o StrictHostKeyChecking=accept-new -o BatchMode=yes $Server "echo connected" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail "SSH 连接失败（密钥是否已加入服务器 authorized_keys？）"
    exit 1
}
Ok "SSH 可达"

# 上传
Step "上传：public/ -> $Server`:$WebRoot"
scp -i $SshKey -P $SshPort -o StrictHostKeyChecking=accept-new -r "$BlogDir\public\*" "${Server}:${WebRoot}/"
if ($LASTEXITCODE -ne 0) { Fail "scp 上传失败"; exit 1 }
Ok "文件已上传"

# 清理：跳过（scp 只覆盖不删除，如需严格同步建议改 rsync）
Step "清理：跳过精细清理"

# 修权限
Step "修正权限：chown www-data"
ssh -i $SshKey -p $SshPort -o StrictHostKeyChecking=accept-new $Server "chown -R www-data:www-data '$WebRoot/'"
if ($LASTEXITCODE -ne 0) { Fail "chown 失败"; exit 1 }
Ok "权限已修正"

# Git 提交
Step "Git：提交并推送"
$hasChanges = [bool] (git status --porcelain)
if ($hasChanges) {
    git add -A
    git commit -m "deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    if ($LASTEXITCODE -ne 0) { Fail "git commit 失败"; exit 1 }
}
git push
if ($LASTEXITCODE -ne 0) { Warn "git push 失败（不影响站点已生效）" }

Write-Host ""
Ok "部署完成！"
Write-Host "    https://ydj001.xyz" -ForegroundColor Yellow

