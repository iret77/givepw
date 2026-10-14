#!/usr/bin/env bats
# Acceptance criteria (written before the tests):
#  A1 a secret given as an argument is refused (exit 2), nothing is written
#  A2 the secret never shows up on stdout/stderr, except from `givepw take`
#  A3 the secret never shows up in the argv of a child process
#  A4 file target: exact content, no trailing newline, mode 600
#  A5 an existing file is only overwritten with --force (or a "y" at a terminal)
#  A6 .env target: upsert of KEY=value, other lines kept, idempotent, mode 600;
#     unsafe values and newlines are rejected and leave the file unchanged
#  A7 keychain target: secret goes to security(1)/secret-tool over stdin only
#  A8 `givepw take FILE` prints exactly the content and the file is gone
#  A9 no terminal, no --stdin, no dialog: exit 2 with a hint
#  A10 everything passes under /bin/bash 3.2 (macOS) and bash 5 (Linux)

# shellcheck disable=SC2016  # stub bodies are literal shell code
GIVEPW="$BATS_TEST_DIRNAME/../givepw"
SECRET='s3cr3t-Value_42'

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  export STUB_LOG="$BATS_TEST_TMPDIR/log"
  mkdir -p "$STUB_LOG"
  export PATH="$STUBS:$PATH"
  export GIVEPW_NO_TTY=1
  unset DISPLAY WAYLAND_DISPLAY GIVEPW_PLATFORM
}

perm() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# stub NAME BODY — fake command that logs its argv and runs BODY
stub() {
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$STUB_LOG/%s.argv"\n%s\n' "$1" "$2" > "$STUBS/$1"
  chmod +x "$STUBS/$1"
}

no_secret_in_argv() {
  if cat "$STUB_LOG"/*.argv 2>/dev/null | grep -F -q "$SECRET"; then
    echo "secret found in a child's argv"; return 1
  fi
}

# ── A1 ──────────────────────────────────────────────────────────────────────
@test "A1: secret as argument is refused" {
  run bash "$GIVEPW" "$HOME/f" "$SECRET" < /dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"don't"* ]]
  [ ! -e "$HOME/f" ]
}

@test "A1: refused after -- as well" {
  run bash "$GIVEPW" "$HOME/f" -- "$SECRET" < /dev/null
  [ "$status" -eq 2 ]
  [ ! -e "$HOME/f" ]
}

# ── A2, A4 ──────────────────────────────────────────────────────────────────
@test "A4: --stdin writes exact content without newline, mode 600" {
  run bash "$GIVEPW" --stdin "$HOME/f" <<< "$SECRET"
  [ "$status" -eq 0 ]
  [ "$(perm "$HOME/f")" = "600" ]
  [ "$(od -An -c "$HOME/f" | tr -d ' \n')" = "$(printf '%s' "$SECRET" | od -An -c | tr -d ' \n')" ]
  [[ "$output" != *"$SECRET"* ]]
}

@test "A4: multi-line input keeps inner newlines" {
  printf 'line1\nline2\n' | bash "$GIVEPW" --stdin "$HOME/key"
  [ "$(cat "$HOME/key")" = "$(printf 'line1\nline2')" ]
  [ "$(tail -c 1 "$HOME/key" | od -An -c | tr -d ' ')" = "2" ]
}

@test "default target honours GIVEPW_DEFAULT_FILE" {
  GIVEPW_DEFAULT_FILE="$HOME/default" run bash "$GIVEPW" --stdin <<< "$SECRET"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/default")" = "$SECRET" ]
}

@test "empty secret: exit 1, nothing written" {
  run bash "$GIVEPW" --stdin "$HOME/f" < /dev/null
  [ "$status" -eq 1 ]
  [ ! -e "$HOME/f" ]
}

# ── A5 ──────────────────────────────────────────────────────────────────────
@test "A5: existing file without --force stays unchanged" {
  printf 'old' > "$HOME/f"
  run bash "$GIVEPW" --stdin "$HOME/f" <<< "$SECRET"
  [ "$status" -eq 1 ]
  [ "$(cat "$HOME/f")" = "old" ]
  bash "$GIVEPW" --stdin --force "$HOME/f" <<< "$SECRET"
  [ "$(cat "$HOME/f")" = "$SECRET" ]
}

# ── A9, dialogs ─────────────────────────────────────────────────────────────
@test "A9: no terminal, no --stdin, no dialog: exit 2 with a hint" {
  GIVEPW_PLATFORM=Linux run bash "$GIVEPW" "$HOME/f" < /dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"--stdin"* ]]
  [ ! -e "$HOME/f" ]
}

@test "macOS without terminal: dialog value is stored, not passed as argv" {
  stub osascript "printf '%s\n' '$SECRET'"
  GIVEPW_PLATFORM=Darwin run bash "$GIVEPW" "$HOME/f" < /dev/null
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/f")" = "$SECRET" ]
  [[ "$output" != *"$SECRET"* ]]
  grep -q 'giving up after' "$STUB_LOG/osascript.argv"
}

@test "macOS dialog cancelled: exit 1, nothing written" {
  stub osascript 'exit 1'
  GIVEPW_PLATFORM=Darwin run bash "$GIVEPW" "$HOME/f" < /dev/null
  [ "$status" -eq 1 ]
  [ ! -e "$HOME/f" ]
}

@test "macOS dialog timed out (empty answer): exit 1" {
  stub osascript 'printf ""'
  GIVEPW_PLATFORM=Darwin run bash "$GIVEPW" "$HOME/f" < /dev/null
  [ "$status" -eq 1 ]
  [ ! -e "$HOME/f" ]
}

@test "Linux desktop without terminal: zenity value is stored" {
  stub zenity "printf '%s\n' '$SECRET'"
  DISPLAY=:0 GIVEPW_PLATFORM=Linux run bash "$GIVEPW" "$HOME/f" < /dev/null
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/f")" = "$SECRET" ]
}

# ── A6 ──────────────────────────────────────────────────────────────────────
@test "A6: .env is created with KEY=value and mode 600" {
  bash "$GIVEPW" --stdin --env "$HOME/.env" API_TOKEN <<< "$SECRET"
  [ "$(cat "$HOME/.env")" = "API_TOKEN=$SECRET" ]
  [ "$(perm "$HOME/.env")" = "600" ]
}

@test "A6: upsert replaces the key, keeps other lines and export prefix, idempotent" {
  printf '# comment\nA=1\nexport API_TOKEN=old\nB=2' > "$HOME/.env"
  bash "$GIVEPW" --stdin --env "$HOME/.env" API_TOKEN <<< "$SECRET"
  expected=$(printf '# comment\nA=1\nexport API_TOKEN=%s\nB=2' "$SECRET")
  [ "$(cat "$HOME/.env")" = "$expected" ]
  cp "$HOME/.env" "$HOME/.env.first"
  bash "$GIVEPW" --stdin --env "$HOME/.env" API_TOKEN <<< "$SECRET"
  cmp "$HOME/.env" "$HOME/.env.first"
}

@test "A6: unsafe value or newline is rejected, file unchanged" {
  printf 'A=1\n' > "$HOME/.env"
  run bash "$GIVEPW" --stdin --env "$HOME/.env" K <<< 'has space'
  [ "$status" -eq 1 ]
  run bash "$GIVEPW" --stdin --env "$HOME/.env" K <<< 'q"uote'
  [ "$status" -eq 1 ]
  run bash "$GIVEPW" --stdin --env "$HOME/.env" K < <(printf 'a\nb')
  [ "$status" -eq 1 ]
  [ "$(cat "$HOME/.env")" = "A=1" ]
}

@test "A6: invalid variable name is a usage error" {
  run bash "$GIVEPW" --stdin --env "$HOME/.env" 1BAD <<< "$SECRET"
  [ "$status" -eq 2 ]
  [ ! -e "$HOME/.env" ]
}

# ── A3, A7 ──────────────────────────────────────────────────────────────────
@test "A7: macOS keychain gets the secret over stdin only" {
  stub security "case \"\$1\" in -i) cat > \"\$STUB_LOG/security.stdin\" ;; find-generic-password) printf '%s\n' \"\$KC_RETURN\" ;; esac"
  KC_RETURN="$SECRET" GIVEPW_PLATFORM=Darwin run bash "$GIVEPW" --stdin --keychain svc --account acc <<< "$SECRET"
  [ "$status" -eq 0 ]
  grep -q -- '^-i$' "$STUB_LOG/security.argv"
  grep -F -q -- "-w \"$SECRET\"" "$STUB_LOG/security.stdin"
  no_secret_in_argv
  [[ "$output" != *"$SECRET"* ]]
}

@test "A7: keychain value escapes quotes and backslashes for security -i" {
  stub security "case \"\$1\" in -i) cat > \"\$STUB_LOG/security.stdin\" ;; find-generic-password) printf '%s\n' 'a\"b\\c' ;; esac"
  GIVEPW_PLATFORM=Darwin run bash "$GIVEPW" --stdin --keychain svc <<< 'a"b\c'
  [ "$status" -eq 0 ]
  grep -F -q -- '-w "a\"b\\c"' "$STUB_LOG/security.stdin"
}

@test "A7: keychain read-back mismatch fails" {
  stub security "case \"\$1\" in -i) cat > /dev/null ;; find-generic-password) printf 'other\n' ;; esac"
  GIVEPW_PLATFORM=Darwin run bash "$GIVEPW" --stdin --keychain svc <<< "$SECRET"
  [ "$status" -eq 1 ]
}

@test "A7: Linux secret-tool gets the secret over stdin only" {
  stub secret-tool 'cat > "$STUB_LOG/secret-tool.stdin"'
  GIVEPW_PLATFORM=Linux run bash "$GIVEPW" --stdin --keychain svc --account acc <<< "$SECRET"
  [ "$status" -eq 0 ]
  [ "$(cat "$STUB_LOG/secret-tool.stdin")" = "$SECRET" ]
  grep -q 'service svc account acc' "$STUB_LOG/secret-tool.argv"
  no_secret_in_argv
}

# ── A8 ──────────────────────────────────────────────────────────────────────
@test "A8: take prints exactly the content and deletes the file" {
  printf '%s' "$SECRET" > "$HOME/f"
  run bash "$GIVEPW" take "$HOME/f"
  [ "$status" -eq 0 ]
  [ "$output" = "$SECRET" ]
  [ ! -e "$HOME/f" ]
}

@test "A8: take on a missing file or a directory fails" {
  run bash "$GIVEPW" take "$HOME/missing"
  [ "$status" -eq 1 ]
  mkdir "$HOME/dir"
  run bash "$GIVEPW" take "$HOME/dir"
  [ "$status" -eq 1 ]
  [ -d "$HOME/dir" ]
}

@test "help and version" {
  run bash "$GIVEPW" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"givepw take FILE"* ]]
  run bash "$GIVEPW" --version
  [[ "$output" =~ ^givepw\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}
