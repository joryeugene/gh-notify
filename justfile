# gh-notify development and release workflow

default:
    @just --list

# Lint all shell scripts with shellcheck
lint:
    shellcheck scripts/gh-notify-daemon.sh scripts/gh-notify-bar.sh install.sh

# Copy scripts to ~/.config/gh-notify/ — fast dev deploy, no prereq checks
# Use after any edit to scripts/; press [r] in the bar to reload
sync:
    @mkdir -p "${HOME}/.config/gh-notify"
    @cp scripts/gh-notify-daemon.sh "${HOME}/.config/gh-notify/gh-notify-daemon.sh"
    @cp scripts/gh-notify-bar.sh    "${HOME}/.config/gh-notify/gh-notify-bar.sh"
    @chmod +x "${HOME}/.config/gh-notify/gh-notify-daemon.sh" \
              "${HOME}/.config/gh-notify/gh-notify-bar.sh"
    @echo "synced → ~/.config/gh-notify/  (press [r] in bar to reload)"

# Full install: prereq checks, copy scripts, install CLI wrapper (first-time setup)
install:
    bash install.sh

# Remove all installed files and state
uninstall:
    @echo "Stopping any running processes..."
    @pkill -f gh-notify-daemon 2>/dev/null || true
    @pkill -f gh-notify-bar 2>/dev/null || true
    @echo "Removing state directory..."
    @rm -rf "${HOME}/.config/gh-notify"
    @echo "Removing CLI wrapper..."
    @rm -f "${HOME}/.local/bin/gh-notify"
    @echo "Uninstalled."

# Print a draft CHANGELOG section from commits since last tag
# Review and paste into CHANGELOG.md [Unreleased] before releasing
notes:
    #!/usr/bin/env bash
    set -euo pipefail
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    DATE=$(date +%Y-%m-%d)
    if [[ -z "$LAST_TAG" ]]; then
        echo "## [Unreleased] - ${DATE}"
        echo ""
        git log --pretty="format:- %s" --reverse
    else
        echo "## [Unreleased] - ${DATE}"
        echo ""
        git log --pretty="format:- %s" --reverse "${LAST_TAG}..HEAD"
    fi

# Tag and push a release: lints, syncs locally, tags, pushes, prints release URL
# Prereq: CHANGELOG.md already updated for the version; commit all changes first
# Usage: just release 0.6.0
release version:
    @echo "→ Checking CHANGELOG.md has [{{version}}] entry..."
    @grep -q "\[{{version}}\]" CHANGELOG.md || { echo "✗  [{{version}}] not found in CHANGELOG.md — update it first"; exit 1; }
    @echo "→ Linting..."
    @just lint
    @echo "→ Syncing scripts to ~/.config/gh-notify/..."
    @just sync
    @echo "→ Tagging v{{version}}..."
    git tag -a "v{{version}}" -m "v{{version}}"
    git push origin main "v{{version}}"
    @echo "→ Draft release: https://github.com/joryeugene/gh-notify/releases/new?tag=v{{version}}"
