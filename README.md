# givepw

Hand a secret to a script or an AI agent without it ever passing through the
chat, a command argument or your shell history.

You type the secret into a masked prompt (or a dialog, when there is no
terminal). givepw stores it where the consumer expects it: a file, a key in a
`.env` file, or the keychain. The consumer reads it from there; files are read
once and removed with `givepw take`.

```console
$ givepw ~/.synology-pw
Secret for /Users/me/.synology-pw: ************
✓ stored in /Users/me/.synology-pw (mode 600). Read it once with: givepw take /Users/me/.synology-pw
```

## Why

Agents and scripts regularly need a password or token they don't have. The
usual shortcuts leak it:

| Shortcut | Where the secret ends up |
|---|---|
| paste it into the chat | conversation history, logs, model context |
| `tool --password s3cret` | shell history, `ps` output, terminal scrollback |
| `echo s3cret > file` | shell history |

givepw takes no secret as an argument (it refuses extra arguments), never
prints it, and hands it to helper programs (`security`, `secret-tool`) on
stdin only.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/iret77/givepw/main/install.sh | bash
```

Installs `givepw` to `~/.local/bin` (override with `GIVEPW_BIN_DIR`). Needs
bash 3.2 or later; macOS and Linux.

## Usage

```bash
givepw [FILE]                                  # file, mode 600, no trailing newline
givepw --env .env API_TOKEN                    # set API_TOKEN=... in .env (mode 600)
givepw --keychain my-service --account me      # macOS keychain / Linux secret-tool
givepw take FILE                               # print FILE, then delete it
```

Without `FILE`, the secret goes to `~/.ssh-bootstrap-pw` (override with
`GIVEPW_DEFAULT_FILE`).

**Input**, first that applies:

1. `--stdin`: read from stdin, trailing newlines dropped (for password
   managers and scripts that already hold the secret)
2. a terminal: masked prompt, one `*` per character (`--no-stars` for blind input)
3. no terminal: on macOS a dialog with a hidden field (`--timeout`, default
   120 s); on a Linux desktop `zenity --password`
4. otherwise givepw exits with status 2 and tells you to run it in a terminal

**Options:** `--label TEXT` (what to ask for), `--force` (overwrite an existing
file), `--account NAME` (keychain account, default `$USER`).

**Exit status:** 0 stored, 1 aborted or rejected input, 2 usage error or no
way to ask.

### `.env` values

Consumers disagree on quoting (`docker run --env-file` keeps quotes literally,
dotenv and Compose strip them). givepw therefore only writes values made of
`A–Z a–z 0–9 _ . / : @ % + = , ~ -` and refuses anything else, including
newlines. Use the file target for such secrets. An existing `KEY=` or
`export KEY=` line is replaced; all other lines stay as they are.

### Keychain

- **macOS:** `security add-generic-password -U` in the default keychain; the
  command reaches `security` over stdin (`security -i`), so the secret is never
  in its argv. Read it with `security find-generic-password -s SERVICE -a ACCOUNT -w`
  (values with non-ASCII characters are printed as hex there).
- **Linux:** `secret-tool store` (package `libsecret-tools`), which reads the
  secret from stdin. Read it with `secret-tool lookup service SERVICE account ACCOUNT`.

## For AI agents

`skills/givepw/SKILL.md` is an agent skill (Claude Code and compatible
agents): it tells the agent to never ask for a secret in chat, to have the
user run givepw, and to consume the result with `givepw take`. Install it with:

```bash
mkdir -p ~/.claude/skills/givepw && curl -fsSL \
  https://raw.githubusercontent.com/iret77/givepw/main/skills/givepw/SKILL.md \
  -o ~/.claude/skills/givepw/SKILL.md
```

On macOS, an agent without a terminal can run `givepw --force FILE` itself:
the user gets a dialog and types the secret there.

## Development

```bash
script/setup          # git hooks
bats tests/           # tests (bats, shellcheck)
```

Tests cover argv refusal, file mode and content, `.env` upsert, keychain
helpers (stubbed), dialogs (stubbed), `take` and the headless case. CI runs
them on Linux; they also pass under macOS `/bin/bash` 3.2.

## License

MIT, see [LICENSE](LICENSE).
