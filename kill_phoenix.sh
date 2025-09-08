#!/bin/bash

# Script to kill old Phoenix server instances
echo "🔍 Searching for processes using port 4000..."

# Find processes using port 4000
PIDS=$(netstat -ano | grep :4000 | awk '{print $5}' | sort -u)

if [ -z "$PIDS" ]; then
    echo "✅ No processes found using port 4000"
else
    echo "📋 Found processes using port 4000:"
    for pid in $PIDS; do
        if [ "$pid" != "0" ] && [ -n "$pid" ]; then
            # Get process name if possible
            PROCESS_NAME=$(tasklist | grep "^.*\s$pid\s" | awk '{print $1}' || echo "Unknown")
            echo "  PID: $pid ($PROCESS_NAME)"
        fi
    done
    
    echo ""
    echo "💀 Killing processes..."
    for pid in $PIDS; do
        if [ "$pid" != "0" ] && [ -n "$pid" ]; then
            taskkill /F /PID $pid 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "  ✅ Killed PID: $pid"
            else
                echo "  ❌ Failed to kill PID: $pid"
            fi
        fi
    done
fi

echo ""
echo "🔍 Also checking for Elixir/Erlang processes..."

# Kill any beam.smp or erl processes (Erlang/Elixir)
BEAM_PIDS=$(tasklist | grep -i "beam\|erl" | awk '{print $2}')
if [ -n "$BEAM_PIDS" ]; then
    echo "📋 Found Erlang/Elixir processes:"
    echo "$BEAM_PIDS" | while read pid; do
        if [ -n "$pid" ]; then
            echo "  Killing PID: $pid"
            taskkill /F /PID $pid 2>/dev/null
        fi
    done
else
    echo "✅ No Erlang/Elixir processes found"
fi

echo ""
echo "🧹 Cleanup complete!"
echo "🚀 You can now start Phoenix server with: mix phx.server"