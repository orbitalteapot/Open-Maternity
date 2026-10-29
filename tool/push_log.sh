#!/usr/bin/env bash
# Pushes build logs (or a file) to a branch of their own, so the result of a CI
# run can be read with plain git, without access to the GitHub API.
# Usage: bash tool/push_log.sh <branch> <file>...
set -u
branch="$1"
shift
tmp="$(mktemp -d)"
for f in "$@"; do
  if [ -f "$f" ]; then cp "$f" "$tmp/"; fi
  if [ -d "$f" ]; then cp -r "$f" "$tmp/"; fi
done
{
  echo "status: ${JOB_STATUS:-unknown}"
  echo "workflow: ${GITHUB_WORKFLOW:-local} run ${GITHUB_RUN_NUMBER:-0} (${GITHUB_RUN_ID:-0})"
  echo "commit: ${GITHUB_SHA:-unknown}"
  echo "time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$tmp/STATUS.txt"
cd "$tmp" || exit 0
git init -q
git checkout -q -b "$branch"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -qm "${GITHUB_WORKFLOW:-CI} ${GITHUB_RUN_NUMBER:-0}: ${JOB_STATUS:-unknown}"
git push -qf "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/heads/$branch" || echo "could not push $branch"
