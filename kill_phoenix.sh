#!/bin/bash

# Script to kill old Phoenix server instances
echo "🔍 Searching for processes using port 4000..."

# Find the PID listening on port 4000
LISTENING_PID=$(netstat -ano | grep :4000 | grep LISTENING | awk '{print $5}' | head -1)

if [ -n "$LISTENING_PID" ] && [ "$LISTENING_PID" != "0" ]; then
    echo "💀 Found process listening on port 4000 - PID: $LISTENING_PID"
    taskkill /F /PID $LISTENING_PID 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "  ✅ Killed PID: $LISTENING_PID"
    else
        echo "  ❌ Failed to kill PID: $LISTENING_PID"
    fi
else
    echo "✅ No process found listening on port 4000"
fi

# Also kill any other processes connected to port 4000
OTHER_PIDS=$(netstat -ano | grep :4000 | awk '{print $5}' | sort -u)
for pid in $OTHER_PIDS; do
    if [ "$pid" != "0" ] && [ -n "$pid" ] && [ "$pid" != "$LISTENING_PID" ]; then
        taskkill /F /PID $pid 2>/dev/null
    fi
done

echo ""
echo "🔍 Killing all Erlang/Elixir processes..."

# Kill all erl.exe processes
taskkill /F /IM erl.exe 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  ✅ Killed erl.exe processes"
else
    echo "  ✅ No erl.exe processes found"
fi

# Kill all beam.smp.exe processes
taskkill /F /IM beam.smp.exe 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  ✅ Killed beam.smp.exe processes"  
else
    echo "  ✅ No beam.smp.exe processes found"
fi

echo ""
echo "🧹 Cleanup complete!"
echo "🚀 You can now start Phoenix server with: mix phx.server"