#!/usr/bin/env bash
# gh-notify installer
# Installs background GitHub notification daemon + tmux bar for macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joryeugene/gh-notify/main/install.sh | bash
#   # or from local clone:
#   ./install.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "  ${BLUE}--${RESET} $*"; }
ok()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()  { echo -e "  ${YELLOW}!${RESET}  $*"; }
die()   { echo -e "  ${RED}✗${RESET}  $*"; exit 1; }

STATE_DIR="${HOME}/.config/gh-notify"
GITHUB_RAW="https://raw.githubusercontent.com/joryeugene/gh-notify/main"

# Detect local vs remote execution (empty BASH_SOURCE[0] when piped through bash)
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    IS_REMOTE=false
else
    IS_REMOTE=true
    SCRIPT_DIR=""
fi

echo
echo -e "${BOLD}gh-notify installer${RESET}"
echo

# -------------------------------------------------------------------
# 1. Check prerequisites
# -------------------------------------------------------------------
info "Checking prerequisites..."
echo

FAIL=0

if command -v gh &>/dev/null; then
    ok "gh CLI found: $(gh --version | head -1)"
else
    warn "gh CLI not found. Install: brew install gh"
    FAIL=1
fi

if command -v jq &>/dev/null; then
    ok "jq found: $(jq --version)"
else
    warn "jq not found. Install: brew install jq"
    FAIL=1
fi

if command -v tmux &>/dev/null; then
    ok "tmux found: $(tmux -V)"
else
    warn "tmux not found. Install: brew install tmux"
    FAIL=1
fi

if command -v osascript &>/dev/null; then
    ok "osascript found (macOS confirmed)"
else
    die "osascript not found. gh-notify requires macOS for notifications and sounds."
fi

if [[ "$FAIL" -eq 1 ]]; then
    echo
    die "Missing prerequisites above. Install them and re-run."
fi

echo

# -------------------------------------------------------------------
# 2. Copy scripts to ~/.config/gh-notify/
# -------------------------------------------------------------------
info "Installing scripts to ${STATE_DIR}..."

mkdir -p "$STATE_DIR"

if [[ "$IS_REMOTE" == "true" ]]; then
    info "Remote install — downloading scripts from GitHub..."
    curl -fsSL "${GITHUB_RAW}/scripts/gh-notify-daemon.sh" -o "${STATE_DIR}/gh-notify-daemon.sh" || die "Download failed"
    curl -fsSL "${GITHUB_RAW}/scripts/gh-notify-bar.sh"    -o "${STATE_DIR}/gh-notify-bar.sh"    || die "Download failed"
else
    [[ -d "${SCRIPT_DIR}/scripts" ]] || die "scripts/ not found. Run from the gh-notify repo root."
    cp "${SCRIPT_DIR}/scripts/gh-notify-daemon.sh" "${STATE_DIR}/gh-notify-daemon.sh"
    cp "${SCRIPT_DIR}/scripts/gh-notify-bar.sh"    "${STATE_DIR}/gh-notify-bar.sh"
fi
chmod +x "${STATE_DIR}/gh-notify-daemon.sh" "${STATE_DIR}/gh-notify-bar.sh"

ok "Copied gh-notify-daemon.sh"
ok "Copied gh-notify-bar.sh"

# Init state files (idempotent)
[[ -f "${STATE_DIR}/sfx-state" ]] || echo "ON" > "${STATE_DIR}/sfx-state"
touch "${STATE_DIR}/events.log" "${STATE_DIR}/seen-ids"

ok "State directory ready: ${STATE_DIR}"
echo

# -------------------------------------------------------------------
# 3. Verify
# -------------------------------------------------------------------
info "Verifying installation..."
echo

VFAIL=0

# Check daemon script is executable
if [[ -x "${STATE_DIR}/gh-notify-daemon.sh" ]]; then
    ok "gh-notify-daemon.sh is executable"
else
    warn "gh-notify-daemon.sh is not executable"
    VFAIL=1
fi

# Check bar script is executable
if [[ -x "${STATE_DIR}/gh-notify-bar.sh" ]]; then
    ok "gh-notify-bar.sh is executable"
else
    warn "gh-notify-bar.sh is not executable"
    VFAIL=1
fi

# Check gh auth
if gh auth status &>/dev/null; then
    ok "gh auth: authenticated"
else
    warn "gh auth: not authenticated. Run: gh auth login"
    VFAIL=1
fi

# Check osascript works
if osascript -e 'return 0' &>/dev/null; then
    ok "osascript: working"
else
    warn "osascript: not responding"
    VFAIL=1
fi

echo

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
if [[ "$VFAIL" -eq 0 ]]; then
    echo -e "${BOLD}Installation complete!${RESET}"
    echo
    echo -e "  ${DIM}Test a sound:   afplay /System/Library/Sounds/Glass.aiff${RESET}"
    echo -e "  ${DIM}Test a popup:   osascript -e 'display notification \"Ready\" with title \"gh-notify\"'${RESET}"
    echo -e "  ${DIM}Launch bar:     bash ~/.config/gh-notify/gh-notify-bar.sh${RESET}"
else
    warn "Installation completed with warnings above."
    echo -e "  ${DIM}Run manual checks to resolve issues.${RESET}"
fi
echo
