#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "usage: hunks.sh <worktree> <base-ref>   (TSV: path, line, added, removed, kind, status)" >&2; exit 64; }
wt=$1 base=$2
mb=$(git -C "$wt" merge-base "$base" HEAD)
echo "# base=$mb"

kind() {
  case "$1" in
    *package-lock.json|*yarn.lock|*pnpm-lock.yaml|*poetry.lock|*Cargo.lock|*go.sum|*lazy-lock.json|*.lock) echo lockfile ;;
    *.snap|dist/*|*/dist/*|*generated*|*.gen.*|*.min.js) echo generated ;;
    *.spec.*|*.test.*|*/test/*|*/tests/*|*/spec/*|test/*|tests/*|*_test.go|*/test_*.py|test_*.py) echo test ;;
    *.md|*.mdx|*.rst|docs/*) echo doc ;;
    *.json|*.yaml|*.yml|*.toml|*.tf|*.tfvars|*.hcl|*Dockerfile*|.env*|*/.env*|*.config.*|*rc|*.ini|Makefile|config/*) echo config ;;
    *) echo src ;;
  esac
}

git -C "$wt" diff -U0 --no-color --no-ext-diff --no-renames --src-prefix=a/ --dst-prefix=b/ "$mb" -- . ':(exclude).claude' |
  awk -F'\t' '
    /^--- / { old = substr($0, 5); sub(/^a\//, "", old); next }
    /^\+\+\+ / { new = substr($0, 5); sub(/^b\//, "", new)
      if (new == "/dev/null") { path = old; status = "deleted" } else { path = new; status = (old == "/dev/null") ? "added" : "modified" }
      next }
    /^@@ / {
      split($0, p, " "); o = p[2]; n = p[3]
      sub(/^-/, "", o); sub(/^\+/, "", n)
      split(o, oo, ","); split(n, nn, ",")
      rem = (oo[2] == "") ? 1 : oo[2]; add = (nn[2] == "") ? 1 : nn[2]
      line = (status == "deleted") ? 1 : ((nn[1] == 0) ? 1 : nn[1])
      printf "%s\t%d\t%d\t%d\t%s\n", path, line, add, rem, status
    }' |
  while IFS=$'\t' read -r path line add rem status; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$path" "$line" "$add" "$rem" "$(kind "$path")" "$status"
  done

git -C "$wt" ls-files --others --exclude-standard -- . ':(exclude).claude' |
  while IFS= read -r path; do
    printf '%s\t1\t%s\t0\t%s\tuntracked\n' "$path" "$(wc -l < "$wt/$path" | tr -d ' ')" "$(kind "$path")"
  done
