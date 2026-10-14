# Contributing

- `script/setup` once (git hooks), then work on a branch and open a PR.
- Keep `givepw` a single bash script that runs on macOS `/bin/bash` 3.2.
- The secret must never reach argv, stdout/stderr (except `givepw take`) or a
  file other than the target. Every change keeps `tests/givepw.bats` green and
  adds a test for new behaviour.
- `shellcheck givepw` stays clean.
- Fix = patch, feature = minor; bump `VERSION` and `CHANGELOG.md` in the same commit.
