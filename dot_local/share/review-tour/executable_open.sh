#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 5 ]] || { echo "usage: open.sh <worktree> <merge-base-sha> <tour.qf> <tour.md> <notes-file>" >&2; exit 64; }
wt=$1 base=$2 qf=$3 md=$4 notes=$5
[[ -n "${TMUX:-}" ]] || { echo "open.sh: not inside tmux" >&2; exit 1; }
for f in "$qf" "$md"; do [[ -s "$f" ]] || { echo "open.sh: missing $f" >&2; exit 1; }; done
touch "$notes"
name="review-$(basename "$wt")"
tmux new-window -n "$name" -c "$wt" \
  -e "REVIEW_TOUR_QF=$qf" -e "REVIEW_TOUR_MD=$md" \
  -e "REVIEW_NOTES=$notes" -e "REVIEW_BASE=$base" \
  "nvim -c \"lua require('custom.review_tour').start()\""
echo "$name"
