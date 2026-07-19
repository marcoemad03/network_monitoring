@echo off
set JWT_ACCESS_SECRET=dev-secret-key-change-in-production-123456
set JWT_REFRESH_SECRET=dev-refresh-secret-key-change-in-production-789012
set DB_PASSWORD=changeme
set LOG_LEVEL=error
start /B "" "C:\Users\marco\Desktop\network_monitorong\backend\server.exe" > "C:\Users\marco\Desktop\network_monitorong\backend\server_bg.log" 2>&1
echo Server PID: %ERRORLEVEL%
