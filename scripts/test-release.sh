#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
fixture="$stage/project with spaces"
mkdir -p "$fixture/scripts" "$stage/bin"
cp "$project_root/scripts/"*.sh "$fixture/scripts/"
cp -R "$project_root/resources" "$fixture/"
bash "$fixture/scripts/package-theme.sh" --version 1.0.99
diff -r "$project_root/resources" "$fixture/resources"
unzip -p "$fixture/dist/helheim-1.0.99.jar" theme/helheim.theme.json | jq -e '.ui.ToolWindow["HeaderTab.padding"] == "4,10,4,10"' >/dev/null
unzip -p "$fixture/dist/helheim-1.0.99.zip" helheim/lib/helheim-1.0.99.jar | cmp - "$fixture/dist/helheim-1.0.99.jar"
if bash "$fixture/scripts/package-theme.sh" --version invalid >/dev/null 2>&1; then
  echo 'Invalid version accepted' >&2; exit 1
fi
mv "$fixture/resources/theme/Helheim.xml" "$stage/Helheim.xml"
if bash "$fixture/scripts/package-theme.sh" --version 1.0.99 >/dev/null 2>&1; then
  echo 'Missing scheme accepted' >&2; exit 1
fi
mv "$stage/Helheim.xml" "$fixture/resources/theme/Helheim.xml"

cat > "$stage/bin/git" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$MOCK_LOG"
case $SCENARIO in
  new) exit 2 ;;
  git_error) exit 128 ;;
  orphan) exit 2 ;;
  *) exit 0 ;;
esac
MOCK
cat > "$stage/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$MOCK_LOG"
if [[ $1 == api && $2 == */commits/* ]]; then
  if [[ $SCENARIO == divergent ]]; then printf '%040d\n' 0; else echo "$TEST_COMMIT"; fi
elif [[ $1 == api ]]; then
  [[ $SCENARIO != api_error ]] || exit 1
  [[ $SCENARIO == new || $SCENARIO == annotated ]] || echo 42
else
  [[ $SCENARIO != upload_error ]] || exit 1
fi
MOCK
chmod +x "$stage/bin/git" "$stage/bin/gh"
export PATH="$stage/bin:$PATH" GH_REPO=example/helheim
export TEST_COMMIT=1111111111111111111111111111111111111111
export MOCK_LOG="$stage/calls"
for scenario in new rerun annotated divergent orphan git_error api_error upload_error missing_asset; do
  export SCENARIO=$scenario
  : > "$MOCK_LOG"
  if [[ $scenario == missing_asset ]]; then rm "$fixture/dist/helheim-1.0.99.jar"; fi
  status=0
  bash "$fixture/scripts/publish-release.sh" --version 1.0.99 --commit "$TEST_COMMIT" > "$stage/output" 2>&1 || status=$?
  case $scenario in
    new|annotated)
      [[ $status == 0 ]]
      grep -q 'release create v1.0.99' "$MOCK_LOG"
      grep -q -- "--target $TEST_COMMIT.*--latest=false" "$MOCK_LOG"
      ;;
    rerun)
      [[ $status == 0 ]]
      grep -q 'release upload v1.0.99.*--clobber' "$MOCK_LOG"
      ;;
    *)
      [[ $status != 0 ]]
      if [[ $scenario != upload_error ]] && grep -q 'release create\|release upload' "$MOCK_LOG"; then
        echo 'Unexpected publication after failure' >&2; exit 1
      fi
      ;;
  esac
  if [[ $scenario == annotated ]]; then grep -qF 'refs/tags/v1.0.99^{}' "$MOCK_LOG"; fi
  if [[ $scenario == rerun ]]; then grep -q -- '--paginate' "$MOCK_LOG"; fi
  printf 'Passed: %s\n' "$scenario"
done
