# gh-notify development and release workflow

default:
    @just --list

# Lint all shell scripts with shellcheck
lint:
    shellcheck scripts/gh-notify-daemon.sh scripts/gh-notify-bar.sh install.sh

# Run the installer locally (idempotent)
install:
    bash install.sh

# Tag and push a release (creates GitHub release draft)
# Usage: just release 0.2.0
release version:
    @echo "Tagging v{{version}}..."
    git tag -a "v{{version}}" -m "v{{version}}"
    git push origin "v{{version}}"
    @echo "Draft release at: https://github.com/joryeugene/gh-notify/releases/new?tag=v{{version}}"
