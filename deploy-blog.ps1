# 博客发布脚本
# 用法: powershell -File deploy-blog.ps1

$hugo = "C:\Users\21972\AppData\Local\Microsoft\WinGet\Packages\Hugo.Hugo.Extended_Microsoft.Winget.Source_8wekyb3d8bbwe\hugo.exe"
$sshpass = "C:\Users\21972\AppData\Local\Microsoft\WinGet\Packages\xhcoding.sshpass-win32_Microsoft.Winget.Source_8wekyb3d8bbwe\sshpass.exe"
$blogDir = "C:\Users\21972\Desktop\blog-ydj001"
$server = "root@154.12.85.12"
$webRoot = "/var/www/ydj001.xyz"
$password = "z8W!McC~JGK"

Write-Host "=== 构建 ===" -ForegroundColor Cyan
Set-Location $blogDir
& $hugo --minify
if ($LASTEXITCODE -ne 0) { Write-Host "构建失败" -ForegroundColor Red; exit 1 }
Write-Host "构建成功" -ForegroundColor Green

Write-Host "=== 清空服务器旧文件 ===" -ForegroundColor Cyan
& $sshpass -p $password ssh -o StrictHostKeyChecking=no $server "rm -rf $webRoot/* $webRoot/.* 2>/dev/null"

Write-Host "=== 上传到服务器 ===" -ForegroundColor Cyan
& $sshpass -p $password scp -o StrictHostKeyChecking=no -r "$blogDir\public\*" "${server}:${webRoot}/"

Write-Host "=== 修正权限 ===" -ForegroundColor Cyan
& $sshpass -p $password ssh -o StrictHostKeyChecking=no $server "chown -R www-data:www-data $webRoot/"

Write-Host "=== 推送到 GitHub ===" -ForegroundColor Cyan
git add -A
git commit --allow-empty -m "deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git push

Write-Host "=== 发布完成! ===" -ForegroundColor Green
Write-Host "https://ydj001.xyz" -ForegroundColor Yellow
