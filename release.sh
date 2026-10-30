#!/bin/zsh
# Usage: ./release.sh 1.0.1 [--install]
# Commits pending changes, tags v<version>, pushes, waits for the GitHub Actions build,
# and (with --install) installs the published release via the public installer.
set -e
cd "${0:A:h}"

version=${1:?usage: ./release.sh <version> [--install]}
tag="v$version"
git rev-parse "$tag" >/dev/null 2>&1 && { echo "Tag $tag already exists."; exit 1; }

if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "Release $tag"
fi
git push origin HEAD
git tag "$tag"
git push origin "$tag"

echo "Waiting for the release build..."
sleep 5
run=$(gh run list --workflow release.yml --branch "$tag" --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$run" --exit-status

echo "Published: $(gh release view "$tag" --json url -q .url)"
if [[ $2 == --install ]]; then
  curl -fsSL https://github.com/MariosIgkiempor/iconvert/releases/latest/download/install.sh | bash
fi
