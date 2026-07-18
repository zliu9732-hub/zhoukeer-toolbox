#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

CURRENT_VERSION="$(tr -d '\r\n' < VERSION)"
NEW_VERSION="$(echo "$CURRENT_VERSION" | awk -F. '{ if ($3 >= 9) printf "%d.%d.0", $1, $2 + 1; else printf "%d.%d.%d", $1, $2, $3 + 1 }')"
TAG_MESSAGE="v$NEW_VERSION"

printf '%s\n' "$NEW_VERSION" > VERSION
bash scripts/package_release.sh || exit 1

git add -A
git commit -m "v$NEW_VERSION: $TAG_MESSAGE" 2>/dev/null || true
git tag -d "v$NEW_VERSION" 2>/dev/null || true
git tag -a "v$NEW_VERSION" -m "$TAG_MESSAGE" || exit 1

if git remote get-url origin --push --all 2>/dev/null | wc -l | grep -q '^[2-9]'; then
    git push origin main --follow-tags
else
    git push origin main && git push origin "v$NEW_VERSION" || true
    git push gitee main && git push gitee "v$NEW_VERSION" || true
fi

echo "v$NEW_VERSION released"
