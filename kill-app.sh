#!/bin/bash
#
# kill-app.sh - Force quit CrossRoads and cleanup processes
#

echo "🛑 Stopping CrossRoads..."

# Kill the main app
killall -9 CrossRoads 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ CrossRoads process killed"
else
    echo "ℹ️  No CrossRoads process found"
fi

# Kill any Node.js MCP server
pkill -f "crossroads-mcp" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ MCP server killed"
else
    echo "ℹ️  No MCP server found"
fi

# Kill any orphaned git processes from worktrees
pkill -f "git.*worktree" 2>/dev/null

echo ""
echo "✨ Cleanup complete! Safe to rebuild and run."
