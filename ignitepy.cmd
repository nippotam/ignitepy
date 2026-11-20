@echo off
rem Launcher for ignitepy.ps1 - works from cmd.exe or PowerShell, bypassing the
rem execution policy for this one script only. Keep it next to ignitepy.ps1.
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0ignitepy.ps1" %*
exit /b %ERRORLEVEL%
