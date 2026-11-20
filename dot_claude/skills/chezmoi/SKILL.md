---
name: chezmoi
description: Sync John's dotfiles with chezmoi. Pull the latest from the dotfiles repo and apply it safely, push local dotfile changes up, or (on the machine that publishes) pull in a patch another box left in its outbox, while keeping macOS, Linux, work and remote-server machines working and keeping work details out of the public repo. Use when John runs /chezmoi, or asks to pull, update, sync, push or commit his dotfiles, to "pull from" a box or check its outbox, or to get a config change onto his other machines.
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

## Roles

Exactly one kind of machine pushes to GitHub: the **publisher**, John's desktop, where he reviews changes. Every other box (home servers, headless boxes) is **pull-only**: it pulls over public HTTPS, holds no push credential, and hands its changes back as patches in `~/dotfiles-outbox/`. The publisher fetches, reviews and publishes them. This keeps one reviewed path into a repo whose contents run on every machine, the work laptop included.

Find out which you are without prompting:

```sh
GIT_TERMINAL_PROMPT=0 chezmoi git -- push --dry-run 2>&1   # succeeds only on the publisher
```

The publisher reaches boxes by their ssh alias. **Never write an alias or hostname into this file**, which is public. Take it from John or your memory, and ask the first time.

Argument: `status`, `pull`, `push`, `pull from <box>` (also `inbox <box>`), or nothing. With nothing, run **status** and suggest which one fits.

**ssh in John's shells can be wrapped** (for example a function that resets the terminal after ssh exits and prints escape codes to stdout). Never capture `ssh host cat …` into a file. Copy files with `scp`, and run remote commands with `command ssh -o BatchMode=yes`.

## Status (always run this first)

```sh
chezmoi git -- fetch -q
chezmoi git -- status -sb            # source: uncommitted edits, ahead/behind origin
chezmoi git -- log --oneline HEAD..@{u}   # incoming
chezmoi git -- log --oneline @{u}..HEAD   # local commits not pushed
chezmoi status                       # targets that differ from source
```

How to read `chezmoi status`: a letter in the **first** column means the file in `$HOME` was changed since the last apply, which is a local edit. A letter only in the **second** column means `apply` would change the file. **`chezmoi diff` shows `-` for what is in `$HOME` now and `+` for what apply would write.** If a `-` line looks deliberate, it is a local edit that apply would destroy.

On the publisher, also check each box John uses for waiting patches:

```sh
command ssh -o BatchMode=yes -o ConnectTimeout=5 <alias> 'ls -1 ~/dotfiles-outbox/*.patch 2>/dev/null'
```

Report the result in one short block: incoming commits, local edits, unpushed commits, and (publisher) patches waiting in each box's outbox.

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
  Then tell John, in one short block: the patch filename, its `sha256sum`, a one-line summary, and the line to give the publisher's Claude: `/chezmoi pull from <alias> <file> <sha256>`. `<alias>` is the ssh alias John uses to reach this box. Check memory for it, or ask him the first time.

  If he'd rather run it himself, also give **one paste-ready block** for the publisher with `P`, `SUM` and `HOST` filled in. It refuses to run on a dirty or non-`main` source, fetches the patch with `scp` and stops if the hash doesn't match, scans for work details, applies the patch with `git am`, shows the commit, and runs `chezmoi apply`, which still prompts before overwriting a file edited on the publisher. It does not push.
  ```sh
  ( set -euo pipefail
    HOST=<ssh-alias>; P=<file>.patch; SUM=<sha256>
    cd "$(chezmoi source-path)"
    [ -z "$(git status --porcelain)" ] || { echo "✗ source has uncommitted changes"; exit 1; }
    [ "$(git branch --show-current)" = main ] || { echo "✗ source not on main"; exit 1; }
    git pull -q --ff-only
    t=$(mktemp -d); scp -q "$HOST:dotfiles-outbox/$P" "$t/$P"
    echo "$SUM  $t/$P" | shasum -a 256 -c - >/dev/null || { echo "✗ checksum mismatch"; exit 1; }
    echo "✓ checksum"
    if grep '^+' "$t/$P" | grep -nEi -- '-----BEGIN [A-Z ]+KEY-----|[a-z0-9-]+\.(corp|internal)|(api[_-]?key|token|secret) *[:=] *[A-Za-z0-9_/+-]{16,}'; then echo "✗ scan hits above"; exit 1; fi
    echo "✓ scan"
    git am -q --3way "$t/$P" || { git am --abort; echo "✗ patch did not apply"; exit 1; }
    git log -1 --stat --format='✓ applied %h %s'
    chezmoi apply -v
    echo "→ review, then push with: chezmoi git -- push"
  )
  ```
  Under `set -e`, a failing command on the left of `&&` does not stop the script, so every check in the block ends in `|| { …; exit 1; }`, never `&& echo ✓`. Copy with `scp`, never `ssh … cat >`, which can pick up bytes from a wrapped ssh (see Roles).
  Add any work-specific words John has asked to block to the scan pattern. Keep them out of this file, because this skill is published in the public repo.
  Once the publisher has pushed, the next `/chezmoi pull` here brings the change back. Until then, `chezmoi status` keeps showing that target as edited, which is expected. Leave the `outbox/` branch until John says to delete it.

## Pull from a box (publisher only)

`/chezmoi pull from <box> [<file> [<sha256>]]`: bring a pull-only box's outbox patch into the repo. Run this only on the publisher. If the push dry-run fails, stop and say so. Treat the patch as coming from a less-trusted machine: read it, don't only scan it.

1. **Clean start.** Run the source checks from status. The source must be on `main`, with no uncommitted edits and no unpushed commits, and must fast-forward with `chezmoi git -- pull --ff-only`. Otherwise stop and report.
2. **Find the patch.** If no file was given, list the box's outbox (see Status). One patch: use it. Several: oldest first, one at a time, and confirm the order with John.
3. **Fetch it with `scp`**, into a fresh directory:
   ```sh
   t=$(mktemp -d); scp -q "<alias>:dotfiles-outbox/<file>" "$t/"
   shasum -a 256 "$t/<file>"
   ```
   If John or the box gave a hash, it must match exactly. A mismatch stops everything. Don't retry with another copy method.
4. **Review the whole patch.**
   - Which files it touches. Call out anything that runs code (`run_*` scripts, `.chezmoiexternal.toml`, shell rc files, hooks) and say what it would do.
   - The private-details scan from Push step 3, on the `+` lines.
   - The author is the noreply identity.
   - It doesn't remove guards for the work, remote or OS branches.
5. **Apply it as a commit**, keeping the box's author and message:
   ```sh
   chezmoi git -- am --3way "$t/<file>" || { chezmoi git -- am --abort; echo "✗ did not apply"; }
   ```
   If it doesn't apply, stop and show why. The box should rebase onto the new `main` and make the patch again.
6. **Check every machine still works.** Render changed templates for each variant (Push step 2), and confirm `chezmoi execute-template < "$(chezmoi source-path)/.chezmoiignore"` renders.
7. **Apply here.** Handle local edits as in Pull step 1, then run `chezmoi diff --no-pager`. Summarize by file, then `chezmoi apply -v`.
8. **Push when John says to**: `chezmoi git -- push`. Until then, the commit stays local, and the patch stays in the box's outbox.
9. **Close the loop** after pushing. Archive the patch on the box, and tell John the box should run `/chezmoi pull`, after which its `outbox/<slug>` branch can be deleted there:
   ```sh
   command ssh -o BatchMode=yes <alias> 'mkdir -p ~/dotfiles-outbox/applied && mv ~/dotfiles-outbox/<file> ~/dotfiles-outbox/applied/'
   ```

Never force-push, never push without John saying so, and never rewrite published history.
