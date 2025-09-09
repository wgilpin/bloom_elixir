@echo off
echo 🔍 Searching for processes using port 4000...

:: Find the PID listening on port 4000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :4000 ^| findstr LISTENING') do (
    if not "%%a"=="0" (
        echo 💀 Found process listening on port 4000 - PID: %%a
        taskkill /F /PID %%a >nul 2>&1
        if errorlevel 1 (
            echo   ❌ Failed to kill PID: %%a
        ) else (
            echo   ✅ Killed PID: %%a
        )
    )
)

:: Also kill any other processes connected to port 4000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :4000') do (
    if not "%%a"=="0" (
        taskkill /F /PID %%a >nul 2>&1
    )
)

echo.
echo 🔍 Killing all Erlang/Elixir processes...

:: Kill all erl.exe processes (Erlang runtime)
taskkill /F /IM erl.exe >nul 2>&1
if not errorlevel 1 (
    echo   ✅ Killed erl.exe processes
) else (
    echo   ✅ No erl.exe processes found
)

:: Kill beam.smp processes (Elixir runtime)
taskkill /F /IM beam.smp.exe >nul 2>&1
if not errorlevel 1 (
    echo   ✅ Killed beam.smp.exe processes
) else (
    echo   ✅ No beam.smp.exe processes found
)

echo.
echo 🧹 Cleanup complete!
echo 🚀 You can now start Phoenix server with: mix phx.server