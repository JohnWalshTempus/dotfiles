---
name: chezmoi
description: Sync John's dotfiles with chezmoi. Pull the latest from the dotfiles repo and apply it safely, or push local dotfile changes up, while keeping macOS, Linux, work and remote-server machines working and keeping work details out of the public repo. Use when John runs /chezmoi, or asks to pull, update, sync, push or commit his dotfiles, or to get a config change onto his other machines.
---

# /chezmoi: pull and push dotfiles

The source repo is `$(chezmoi source-path)` (usually `~/.local/share/chezmoi`). Its remote, `JohnWalshTempus/dotfiles`, is **public**. One source tree serves several kinds of machine:

| Axis | Data key | Where it branches |
|---|---|---|
| OS | `.chezmoi.os` (`darwin` / `linux`) | `dot_gitconfig.tmpl` (osxkeychain), `dot_tmux.conf.tmpl`, `dot_tmux/theme.sh.tmpl`, `.chezmoiignore` (`.tmux/bin`), the Ubuntu `run_once` script |
| Work machine | `work`, `workRepoUrl` | `.chezmoiexternal.toml` clones the private work layer into `~/.zsh/work` |
| Shared/remote server | `remote` | `.chezmoiignore` skips kitty, workmux, review-tour, the global gitignore, claude.zsh and this skill |
| Claude installed | `stat ~/.claude/agents/coordinator.md` | `.chezmoiignore` skips claude.zsh and workmux |

Prompt answers live in `~/.config/chezmoi/chezmoi.toml` on each machine and are never committed.

Argument: `pull`, `push`, or nothing. With nothing, run **status** and suggest which one fits.

## Status (always run this first)

```sh
chezmoi git -- fetch -q
chezmoi git -- status -sb            # source: uncommitted edits, ahead/behind origin
chezmoi git -- log --oneline HEAD..@{u}   # incoming
chezmoi git -- log --oneline @{u}..HEAD   # local commits not pushed
chezmoi status                       # targets that differ from source
```

How to read `chezmoi status`: a letter in the **first** column means the file in `$HOME` was changed since the last apply, which is a local edit. A letter only in the **second** column means `apply` would change the file. **`chezmoi diff` shows `-` for what is in `$HOME` now and `+` for what apply would write.** If a `-` line looks deliberate, it is a local edit that apply would destroy.

Report the result in one short block: incoming commits, local edits, unpushed commits.

## Pull

1. **Protect local edits first.** For every target that `chezmoi status` flags as edited in `$HOME`, show the diff and ask John which of these to do. Don't apply until each one is settled.
   - **keep and share**: run the Push flow for it first.
   - **keep on this box only**: move it to the matching local layer (`~/.zshrc.local`, `~/.gitconfig.local`, `~/.tmux.conf.local`, `~/.zsh/work/*.zsh`), then let apply overwrite the managed file.
   - **discard**: let apply overwrite it.
2. Make sure the source tree is clean. If there are uncommitted source edits or unpushed commits, stop and report them. Don't stash or reset.
3. Pull fast-forward only. Never use `chezmoi update`, which pulls and applies with no review.
   ```sh
   chezmoi git -- pull --ff-only
   ```
   If it can't fast-forward, stop and show both sides. Don't rebase or merge without John.
4. **If `.chezmoi.toml.tmpl` changed in the pulled range** (`git diff --stat ORIG_HEAD.. -- .chezmoi.toml.tmpl`), there may be a new prompt. Read the template, ask John for each new answer, then run `chezmoi init` non-interactively. Existing answers are kept.
   ```sh
   chezmoi init --promptBool "shared or remote server (pared-down set)=false"
   ```
   Pass the prompt text exactly as the template writes it. `chezmoi init` with no flags would hang waiting for input.
5. Review before writing anything:
   ```sh
   chezmoi diff --no-pager
   ```
   Summarize what will change, by file. Call out `run_*` scripts, which may sudo-install packages, and `.chezmoiexternal.toml` changes.
6. Apply, then confirm `chezmoi status` is empty:
   ```sh
   chezmoi apply -v
   ```
   Add `-R` only when John wants the externals (antidote, the work layer) refreshed.
7. Tell John what needs a reload: `exec zsh` for shell files, `tmux source ~/.tmux.conf` for tmux, restarting nvim for nvim. Lazy plugin changes need `:Lazy sync`.

## Push

### 1. Get the change into the source

- A plain (non-template) file edited in `$HOME`: `chezmoi re-add <target>`.
- A templated target (the source file ends in `.tmpl`): `re-add` skips templates. Edit the source file by hand (`chezmoi source-path <target>`), keep every OS, work and remote branch intact, and only move the new lines into the right branch.
- A new file: `chezmoi add <target>`. Ask first whether it belongs on every machine. If it is box-specific, it goes in a `*.local` file and is never added.

### 2. Check that every machine still works

For each changed template, render it for each relevant combination and check the result makes sense:

```sh
for os in darwin linux; do
  for d in '{"work":false,"remote":false}' '{"work":true,"remote":false}' '{"remote":true}'; do
    echo "== $os $d"
    chezmoi --override-data "{\"chezmoi\":{\"os\":\"$os\"},${d#\{}" cat <target> | head -40
  done
done
```

`lookPath` and `stat` checks still reflect *this* box, so read those branches by eye.

Portability rules:
- macOS ships BSD userland. Avoid GNU-only `sed -i` without a suffix, `readlink -f`, `date -d`, and `grep -P`, or guard them.
- Homebrew lives at `/opt/homebrew`. Don't hard-code `/usr` or `/home/john` paths. Use `{{ .chezmoi.homeDir }}` or `$HOME`.
- Guard optional tools (`command -v x >/dev/null && …` in shell, `lookPath` in templates) the way the existing files do.
- Gate OS-specific files in `.chezmoiignore`, and gate `run_*` scripts on `.chezmoi.os`.
- A new data key needs a `promptXOnce` line in `.chezmoi.toml.tmpl`, plus a row in the README prompts table. Read it with `index . "key"`, not `.key`, because machines initialised before the key existed don't have it.
- `chezmoi diff` on this box must show only the intended change. `chezmoi execute-template < .chezmoiignore` must render.

### 3. Keep work details out of the public repo

Before committing, scan the staged diff:

```sh
chezmoi git -- add -A && chezmoi git -- diff --cached
chezmoi git -- diff --cached | grep -nEi '@[a-z0-9-]+\.[a-z]|https?://|[0-9]{1,3}(\.[0-9]{1,3}){3}|token|secret|passw|api[_-]?key|BEGIN .*KEY|\.internal|\.corp'
```

Each hit needs a reason to stay. Never commit any of these:
- work emails, hostnames, internal URLs, or the `workRepoUrl` value
- employer or client names, or any customer names
- tokens or keys
- machine names, IPs, or anything else specific to one box

These belong in the private work layer (`~/.zsh/work`, its own repo, pushed separately) or in `~/.gitconfig.local`.

**Commit identity:** on a work machine, `user.email` is the work address and the signing key may be a work key. Commit to the dotfiles repo with the public noreply identity, and without a work signature:

```sh
chezmoi git -- -c user.name="John Walsh" \
  -c user.email="49658092+JohnWalshTempus@users.noreply.github.com" \
  -c commit.gpgsign=false commit -m "<area>: <what changed>"
```

Match the existing message style (`nvim: …`, `Add …`). End the message with the Co-Authored-By line from the session's attribution instructions. Only sign if John says the configured key is his personal one.

### 4. Push, or bail with a patch

Check whether this box can push, without prompting:

```sh
GIT_TERMINAL_PROMPT=0 chezmoi git -- push --dry-run 2>&1
```

- **It can push**, and John has said to push: run `chezmoi git -- pull --ff-only`, then `chezmoi git -- push`. On a work machine, check that the credential that pushed is John's personal GitHub account, not a work account. If it might be the work account, stop and ask.
- **It can't push** (pull-only boxes, such as home servers with no GitHub credential): don't leave the commit on `main`, because the hash rewritten on the Mac would break later fast-forward pulls here. Instead:
  ```sh
  slug=<short-kebab>; src=$(chezmoi source-path)
  git -C "$src" switch -c "outbox/$slug"
  # commit as in step 3
  mkdir -p ~/dotfiles-outbox
  git -C "$src" format-patch origin/main --stdout > ~/dotfiles-outbox/$(date +%F)-$slug.patch
  git -C "$src" switch main
  ```
  Give John **one paste-ready block** for the Mac, with `P`, `SUM` (`sha256sum` of the patch) and `HOST` filled in. `HOST` is the ssh alias John uses to reach this box. Check memory for it, or ask him the first time. The block fetches the patch over ssh and verifies its hash. It refuses to run on a dirty or non-`main` source, scans for work details, applies the patch with `git am`, shows the commit, and runs `chezmoi apply`, which still prompts before overwriting a file edited on the Mac. It does not push.
  ```sh
  ( set -euo pipefail
    HOST=<ssh-alias>; P=<file>.patch; SUM=<sha256>
    cd "$(chezmoi source-path)"
    [ -z "$(git status --porcelain)" ] || { echo "✗ source has uncommitted changes"; exit 1; }
    [ "$(git branch --show-current)" = main ] || { echo "✗ source not on main"; exit 1; }
    git pull -q --ff-only
    t=$(mktemp -d); ssh "$HOST" "cat ~/dotfiles-outbox/$P" > "$t/$P"
    echo "$SUM  $t/$P" | shasum -a 256 -c - >/dev/null && echo "✓ checksum"
    if grep '^+' "$t/$P" | grep -nEi -- '-----BEGIN [A-Z ]+KEY-----|[a-z0-9-]+\.(corp|internal)|(api[_-]?key|token|secret) *[:=] *[A-Za-z0-9_/+-]{16,}'; then echo "✗ scan hits above"; exit 1; fi
    echo "✓ scan"
    git am -q --3way "$t/$P" || { git am --abort; echo "✗ patch did not apply"; exit 1; }
    git log -1 --stat --format='✓ applied %h %s'
    chezmoi apply -v
    echo "→ review, then push with: chezmoi git -- push"
  )
  ```
  Add any work-specific words John has asked to block to the scan pattern. Keep them out of this file, because this skill is published in the public repo.
  After that, the next `/chezmoi pull` here brings the change back. Until then, `chezmoi status` keeps showing that target as edited, which is expected. Leave the `outbox/` branch until John says to delete it.

Never force-push, never push without John saying so, and never rewrite published history.
