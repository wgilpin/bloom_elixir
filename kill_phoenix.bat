@echo off
echo 🔍 Searching for processes using port 4000...

:: Find processes using port 4000
for /f "tokens=5" %%i in ('netstat -ano ^| findstr :4000') do (
    if not "%%i"=="0" (
        echo 💀 Killing PID: %%i
        taskkill /F /PID %%i >nul 2>&1
        if errorlevel 1 (
            echo   ❌ Failed to kill PID: %%i
        ) else (
            echo   ✅ Killed PID: %%i
        )
    )
)

echo.
echo 🔍 Also killing Elixir/Erlang processes...

:: Kill beam.smp processes (Elixir runtime)
taskkill /F /IM beam.smp.exe >nul 2>&1
if not errorlevel 1 echo   ✅ Killed beam.smp.exe processes

:: Kill erl.exe processes (Erlang runtime)  
taskkill /F /IM erl.exe >nul 2>&1
if not errorlevel 1 echo   ✅ Killed erl.exe processes

:: Kill any mix processes
taskkill /F /IM mix.bat >nul 2>&1
if not errorlevel 1 echo   ✅ Killed mix.bat processes

echo.
echo 🧹 Cleanup complete!
echo 🚀 You can now start Phoenix server with: mix phx.server