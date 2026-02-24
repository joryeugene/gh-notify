# gh-notify development and release workflow

default:
    @just --list

# Lint all shell scripts with shellcheck
lint:
    shellcheck scripts/gh-notify-daemon.sh scripts/gh-notify-bar.sh install.sh

# Run the installer locally (idempotent)
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

# Tag and push a release (creates GitHub release draft)
# Update CHANGELOG.md [Unreleased] section first, then: just release 0.2.0
release version:
    @echo "→ CHANGELOG.md updated for v{{version}}? (Ctrl-C to abort)"
    @read -r _
    git tag -a "v{{version}}" -m "v{{version}}"
    git push origin "v{{version}}"
    @echo "Draft release at: https://github.com/joryeugene/gh-notify/releases/new?tag=v{{version}}"
