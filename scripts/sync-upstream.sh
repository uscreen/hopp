#!/usr/bin/env bash
# Fast-forwards main to upstream/main and pushes main plus new upstream tags
# to origin. Aborts if main contains commits of our own.
# Background and workflow: see FORK.md.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

for remote in origin upstream; do
  git remote get-url "$remote" >/dev/null 2>&1 || {
    echo "Error: remote '$remote' is missing (see FORK.md)." >&2
    exit 1
  }
done

git fetch upstream --tags
git fetch origin

for ref in main origin/main; do
  git rev-parse --verify --quiet "$ref" >/dev/null || continue
  own=$(git rev-list --count "upstream/main..$ref")
  if [ "$own" -gt 0 ]; then
    echo "Error: $ref contains $own commit(s) that are not in upstream/main:" >&2
    git --no-pager log --oneline "upstream/main..$ref" >&2
    echo "main is a pure mirror. Move the commits to a feat/ branch, then run this again." >&2
    exit 1
  fi
done

if [ "$(git symbolic-ref --quiet --short HEAD || true)" = "main" ]; then
  git merge --ff-only upstream/main
else
  # No leading + in the refspec: git rejects anything that is not a fast-forward.
  git fetch . upstream/main:main
fi

git push origin main

# Push only tags that exist upstream: no local experiments, no *-uscreen.* tags.
upstream_tags=$(git ls-remote --tags --refs upstream | sed 's#.*refs/tags/##')
origin_tags=$(git ls-remote --tags --refs origin | sed 's#.*refs/tags/##')
new_tags=$(comm -23 <(sort <<<"$upstream_tags") <(sort <<<"$origin_tags"))

if [ -n "$new_tags" ]; then
  refspecs=()
  while IFS= read -r tag; do
    refspecs+=("refs/tags/$tag")
  done <<<"$new_tags"
  git push origin "${refspecs[@]}"
  echo "New upstream tags: $(tr '\n' ' ' <<<"$new_tags")"
  echo "Next step: rebase uscreen onto the new tag (see FORK.md)."
else
  echo "No new upstream tags."
fi

echo "main is at $(git rev-parse --short main) (upstream/main)."
