# Changelog

All notable changes to gh-notify are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

---

## [0.3.0] - 2026-02-23

### Added
- Daemon liveness check in bar: yellow `⚠ daemon offline` warning fires within 2s of crash
- `[r]` keybind to restart the daemon from the bar without relaunching the session
- `just uninstall` recipe to cleanly remove all installed files and state
- Troubleshooting section in README covering the 5 most common failure modes
- Uninstall section in README with `seen-ids` backup note

### Changed
- TLDR prerequisites moved before numbered steps as a runnable block (auth failure is now obvious before install)
- Diagram surfaces `sfx-state` gate making the `[s]` sound toggle architecturally visible
- Poll interval docs clarify default (30s) and minimum (15s) without contradicting each other

### Fixed
- `[r]` restart waits for old daemon's lock release before spawning (prevented silent spawn failure)
- `just lint` SC2088 warning on `~/.local/bin` display string suppressed with inline comment

---

## [0.2.0] - 2026-02-23

### Added
- CLI wrapper `gh-notify` installed to `~/.local/bin` — no more bare `bash` launch instructions
- `justfile` with `lint`, `install`, and `release` recipes
- `just notes` recipe to draft changelog sections from git log

### Changed
- Notifications within a poll cycle are now batched and deduped by repo + title
- Sound dispatch uses priority queue: Hero > Glass > Ping > Tink
- Exactly one sound and one popup fires per poll — "N new notifications" when count > 1, eliminating popup spam under load

---

## [0.1.0] - 2026-02-23

### Added
- Background daemon polling GitHub notifications via `gh` CLI
- tmux status bar integration showing unread count
- macOS native popups via `osascript`
- macOS system sound notifications (Glass, Ping, Tink, Hero)
- Sound on/off toggle persisted to `~/.config/gh-notify/sfx-state`
- `seen-ids` dedup across sessions
- `install.sh` with prerequisite checks (gh, jq, tmux, osascript)

---

[Unreleased]: https://github.com/joryeugene/gh-notify/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/joryeugene/gh-notify/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/joryeugene/gh-notify/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/joryeugene/gh-notify/releases/tag/v0.1.0
