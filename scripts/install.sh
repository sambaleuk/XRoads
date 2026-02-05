#!/bin/bash
#
# XRoads Loop Scripts Installer
# Installs Nexus Loop scripts to ~/.nexus for global access
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEXUS_HOME="${HOME}/.nexus"
NEXUS_BIN="${HOME}/bin"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           XRoads Loop Scripts Installer                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "${NEXUS_HOME}/lib"
mkdir -p "${NEXUS_BIN}"

# Copy library
echo "Installing common.sh to ${NEXUS_HOME}/lib/"
cp "${SCRIPT_DIR}/lib/common.sh" "${NEXUS_HOME}/lib/common.sh"
chmod +x "${NEXUS_HOME}/lib/common.sh"

# Copy scripts to ~/bin for PATH access
echo "Installing scripts to ${NEXUS_BIN}/"
cp "${SCRIPT_DIR}/nexus-init" "${NEXUS_BIN}/nexus-init"
cp "${SCRIPT_DIR}/nexus-loop" "${NEXUS_BIN}/nexus-loop"
cp "${SCRIPT_DIR}/gemini-loop" "${NEXUS_BIN}/gemini-loop"
cp "${SCRIPT_DIR}/codex-loop" "${NEXUS_BIN}/codex-loop"
chmod +x "${NEXUS_BIN}/nexus-init" "${NEXUS_BIN}/nexus-loop" "${NEXUS_BIN}/gemini-loop" "${NEXUS_BIN}/codex-loop"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Installed files:"
echo "  - ${NEXUS_HOME}/lib/common.sh"
echo "  - ${NEXUS_BIN}/nexus-init"
echo "  - ${NEXUS_BIN}/nexus-loop"
echo "  - ${NEXUS_BIN}/gemini-loop"
echo "  - ${NEXUS_BIN}/codex-loop"
echo ""

# Check if ~/bin is in PATH
if [[ ":$PATH:" != *":${NEXUS_BIN}:"* ]]; then
    echo "⚠️  ${NEXUS_BIN} is not in your PATH."
    echo ""
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo "  export PATH=\"\$HOME/bin:\$PATH\""
    echo ""
fi

echo "Usage:"
echo "  nexus-loop   # Run with Claude Code"
echo "  gemini-loop  # Run with Gemini CLI"
echo "  codex-loop   # Run with Codex CLI"
echo ""
