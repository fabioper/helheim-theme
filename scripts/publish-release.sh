#!/usr/bin/env bash
set -euo pipefail

[[ $# == 4 && $1 == --version && $3 == --commit ]] || { echo 'Usage: publish-release.sh --version VERSION --commit SHA' >&2; exit 1; }
version=$2
commit=$4
[[ $version =~ ^1\.0\.[0-9]+$ && $commit =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid version or commit' >&2; exit 1; }
: "${GH_REPO:?GH_REPO must identify the GitHub repository}"
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tag="v$version"
assets=("$project_root/dist/helheim-$version.jar" "$project_root/dist/helheim-$version.zip")
for asset in "${assets[@]}"; do
  [[ -f $asset ]] || { echo "Missing release asset: $asset" >&2; exit 1; }
done

tag_exists=false
if git -C "$project_root" ls-remote --exit-code --tags origin "refs/tags/$tag" "refs/tags/$tag^{}" >/dev/null; then
  tag_exists=true
else
  status=$?
  [[ $status == 2 ]] || { echo 'Failed to query remote tags' >&2; exit 1; }
fi
if [[ $tag_exists == true ]]; then
  tag_commit=$(gh api "repos/$GH_REPO/commits/$tag" --jq '.sha')
  [[ $tag_commit == "$commit" ]] || { echo "Tag $tag already points to another commit" >&2; exit 1; }
fi

release_id=$(gh api "repos/$GH_REPO/releases" --paginate --jq ".[] | select(.tag_name == \"$tag\") | .id")
if [[ -n $release_id ]]; then
  [[ $tag_exists == true ]] || { echo "Release $tag exists but its tag is missing" >&2; exit 1; }
  gh release upload "$tag" "${assets[@]}" --clobber
else
  gh release create "$tag" "${assets[@]}" --target "$commit" --generate-notes --title "Helheim $tag" --latest=false
fi
