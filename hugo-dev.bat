@echo off
:: Hugo 开发服务器一键启动脚本
:: 用 0.0.0.0 绑定，方便 xbrowser 截图（避开 127.0.0.1 不安全源拦截）
:: 端口 13130 默认 + 自动递增找空闲端口

setlocal
set HUGO=C:\Users\21972\AppData\Local\Microsoft\WinGet\Packages\Hugo.Hugo.Extended_Microsoft.Winget.Source_8wekyb3d8bbwe\hugo.exe
set PORT=13130

:check_port
netstat -an | findstr ":%PORT% " | findstr "LISTENING" >nul
if %errorlevel%==0 (
    set /a PORT+=1
    goto :check_port
)

echo.
echo 启动 Hugo 开发服务器:
echo   绑定: 0.0.0.0:%PORT%
echo   访问: http://localhost:%PORT%
echo.
echo 按 Ctrl+C 停止服务
echo.

pushd "%~dp0"
"%HUGO%" server --bind 0.0.0.0 --port %PORT% --baseURL http://localhost:%PORT%
popd
