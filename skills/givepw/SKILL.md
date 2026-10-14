---
name: givepw
description: Gets a secret (password, token, API key) from the user without it passing through the chat, command arguments or shell history. Use whenever a task needs a credential you do not have, or the user offers to paste one. The user types it into givepw (terminal prompt, or a dialog on macOS); you read it from the file with `givepw take`, from a .env file or from the keychain. Never ask for a secret in the conversation and never put one in a command line.
---

# givepw — secrets without chat

## Rules

- Never ask the user to paste a secret into the chat. If they do anyway, don't
  repeat it; tell them to rotate it if it matters.
- Never put a secret in a command argument, URL, log line, commit, issue or file
  you created for another purpose. Pass it on stdin or via a file with mode 600.
- Read a secret file once and remove it: `givepw take FILE`.

## Get a secret

Pick the target the consumer needs:

| Consumer needs | Ask the user to run |
|---|---|
| a file (sshpass `-f`, restic `--password-file`, …) | `givepw ~/.myservice-pw` |
| a variable in a `.env` file | `givepw --env path/to/.env API_TOKEN` |
| the keychain | `givepw --keychain myservice --account NAME` |

Tell the user the exact command and wait until they confirm. Check that it
worked without reading the secret: `test -s FILE` or, for `.env`,
`grep -q '^API_TOKEN=' path/to/.env`.

**macOS, no terminal of your own:** you may run `givepw --force --label "…" FILE`
yourself. If the secret is needed on another host, add `--to HOST`
(e.g. `givepw --to devhost --force ~/.myservice-pw`): the dialog appears on the user's Mac,
the secret goes over ssh into givepw on that host. It opens a dialog on the user's screen; tell the user before you run
it. Exit status 1 means they cancelled or the dialog timed out — ask, don't retry
in a loop. Exit status 2 means there is no way to ask (headless Linux): ask the
user to run the command in their terminal. On a remote host without a terminal of your
own, ask the user to run it in a terminal on that host, or, from their Mac,
`givepw --to HOST FILE`.

## Use it

```bash
sshpass -f <(givepw take ~/.myservice-pw) ssh host      # file, read once, then gone
security find-generic-password -s myservice -a NAME -w   # macOS keychain
secret-tool lookup service myservice account NAME        # Linux keychain
```

Store a secret you have to keep (the user asked for it) only with givepw or the
keychain, never in a plain file you write yourself.
