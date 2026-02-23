# Changelog

All notable changes to gh-notify are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

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

[Unreleased]: https://github.com/joryeugene/gh-notify/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/joryeugene/gh-notify/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/joryeugene/gh-notify/releases/tag/v0.1.0
