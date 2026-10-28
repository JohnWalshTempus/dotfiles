#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: plain.sh <worktree> [base-ref|PR#] | plain.sh <PR#>   (no-AI review window; base defaults to origin/HEAD)" >&2; exit 64; }
[[ $# -ge 1 && $# -le 2 ]] || usage
isnum() { [[ $1 =~ ^[0-9]+$ ]]; }
dir=$1 base=${2:-} pr=
if isnum "$1"; then
  [[ $# -eq 1 ]] || usage
  dir=. pr=$1 base=
elif isnum "$base"; then
  pr=$base base=
fi
wt=$(cd "$dir" && git rev-parse --show-toplevel)
here=$(cd "$(dirname "$0")" && pwd)
branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD)

if [[ -n "$pr" ]]; then
  info=$(cd "$wt" && gh pr view "$pr" --json headRefName,baseRefName -q '.headRefName + " " + .baseRefName')
  read -r head pr_base <<< "$info"
  [[ -n "${pr_base:-}" ]] || { echo "plain.sh: could not read PR #$pr" >&2; exit 1; }
  [[ "$branch" == "$head" ]] || { echo "run: gh pr checkout $pr"; exit 1; }
  [[ -z $(git -C "$wt" status --porcelain -- . ':(exclude).claude') ]] || echo "plain.sh: warning: working tree is dirty; uncommitted changes are included" >&2
  base=origin/$pr_base
fi
if [[ -z "$base" ]]; then
  base=$(git -C "$wt" symbolic-ref -q --short refs/remotes/origin/HEAD) || {
    for ref in origin/develop origin/main origin/master; do
      if git -C "$wt" rev-parse -q --verify "refs/remotes/$ref" >/dev/null; then base=$ref; break; fi
    done
  }
  [[ -n "$base" ]] || { echo "plain.sh: no origin/HEAD, origin/develop, origin/main or origin/master; pass a base ref" >&2; exit 1; }
fi
git -C "$wt" fetch -q origin "${base#origin/}" 2>/dev/null || echo "plain.sh: fetch failed, using local $base" >&2

repo=$(basename "$(dirname "$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)")")
out="${REVIEW_TOUR_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/review-tour}/$repo-${branch//\//-}"
mkdir -p "$out"
"$here/hunks.sh" "$wt" "$base" > "$out/hunks.tsv"
mb=$(sed -n '1s/^# base=//p' "$out/hunks.tsv")
[[ $(wc -l < "$out/hunks.tsv") -gt 1 ]] || { echo "plain.sh: nothing to review against $base"; exit 0; }

tail -n +2 "$out/hunks.tsv" |
  awk -F'\t' 'BEGIN { split("src config test doc generated lockfile", k, " "); for (i in k) rank[k[i]] = i }
    { printf "%d\t%s\t%08d\t%s\t%s\t%s\t%s\n", rank[$5], $1, $2, $3, $4, $5, $6 }' |
  sort -t$'\t' -k1,1n -k2,2 -k3,3n |
  awk -F'\t' -v OFS='\t' '
    { line = $3 + 0
      if ($2 == path && line - start <= 20) { add[n] += $4; rem[n] += $5; hunks[n]++; next }
      n++; path = $2; start = line; p[n] = $2; l[n] = line; add[n] = $4; rem[n] = $5; kind[n] = $6; st[n] = $7; hunks[n] = 1 }
    END { for (i = 1; i <= n; i++)
      printf "%s:%d: [%d/%d] %s %s +%d/-%d%s\n", p[i], l[i], i, n, kind[i], st[i], add[i], rem[i], (hunks[i] > 1 ? " (" hunks[i] " hunks)" : "") }' > "$out/tour.qf"

{
  echo "# $(basename "$wt") vs $base"
  echo
  echo "branch: $(git -C "$wt" rev-parse --abbrev-ref HEAD)  merge-base: ${mb:0:10}  stops: $(wc -l < "$out/tour.qf" | tr -d ' ')"
  echo
  echo '## Commits'
  git -C "$wt" log --oneline "$mb..HEAD" | head -20
  echo
  echo '## Files'
  git -C "$wt" diff --stat=100 --src-prefix=a/ --dst-prefix=b/ "$mb" -- . ':(exclude).claude'
  git -C "$wt" ls-files --others --exclude-standard -- . ':(exclude).claude' | sed 's/^/ (untracked) /'
  echo
  echo '## Stops by kind'
  awk '{ print $3 }' "$out/tour.qf" | sort | uniq -c
} > "$out/tour.md"

"$here/open.sh" "$wt" "$mb" "$out/tour.qf" "$out/tour.md" "$out/notes.txt"
echo "notes: $out/notes.txt"
