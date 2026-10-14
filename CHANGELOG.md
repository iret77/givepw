# Changelog

[SemVer](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] — unreleased

First public version, grown out of a private helper script.

### Added

- Targets: file (mode 600, no trailing newline), `--env ENVFILE KEY` (upsert into
  a `.env` file, safe charset only) and `--keychain SERVICE` (macOS `security`,
  Linux `secret-tool`, secret over stdin only).
- `givepw take FILE`: print once, then delete.
- Input without a terminal: dialog on macOS (`--timeout`, default 120 s),
  `zenity` on a Linux desktop; otherwise exit 2 with a hint.
- `--stdin`, `--label`, `--force`, `--version`; `GIVEPW_DEFAULT_FILE`.
- Agent skill `skills/givepw/SKILL.md`, `install.sh`, bats tests, CI.

### Changed (compared to the private script)

- Without a terminal, givepw no longer reads stdin implicitly; pass `--stdin`.
- An existing file is only overwritten after a "y" at the terminal or with `--force`.
- Messages are in English.
