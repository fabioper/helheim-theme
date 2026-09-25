#!/usr/bin/env bash
set -euo pipefail

[[ $# == 2 && $1 == --version ]] || { echo 'Usage: package-theme.sh --version VERSION' >&2; exit 1; }
version=$2
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]] || { echo 'Invalid version' >&2; exit 1; }
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/resources" "$stage/helheim/lib" "$project_root/dist"
cp -R "$project_root/resources/." "$stage/resources/"
descriptor="$stage/resources/META-INF/plugin.xml"
xmlstarlet val -e "$descriptor" >/dev/null
theme_path=$(xmlstarlet sel -t -v '/idea-plugin/extensions/themeProvider/@path' "$descriptor")
[[ -n $theme_path ]] || { echo 'Missing theme resource path' >&2; exit 1; }
theme="$stage/resources/${theme_path#/}"
jq -e 'type == "object" and (.editorScheme | type == "string" and length > 0)' "$theme" >/dev/null
scheme_path=$(jq -r '.editorScheme' "$theme")
scheme="$stage/resources/${scheme_path#/}"
[[ -f $scheme ]] || { echo "Editor scheme resource not found: $scheme_path" >&2; exit 1; }
xmlstarlet val -e "$scheme" >/dev/null
[[ $(xmlstarlet sel -t -v 'local-name(/*)' "$scheme") == scheme ]] || { echo 'Expected scheme XML root' >&2; exit 1; }
[[ $(xmlstarlet sel -t -v 'count(/idea-plugin/version)' "$descriptor") == 1 ]] || { echo 'Expected one plugin version' >&2; exit 1; }
xmlstarlet ed -L -u '/idea-plugin/version' -v "$version" "$descriptor"
jar="$stage/helheim/lib/helheim-$version.jar"
(cd "$stage/resources" && zip -q -r "$jar" .)
(cd "$stage" && zip -q "helheim-$version.zip" "helheim/lib/helheim-$version.jar")

# Validate archives before making them available for publication.
unzip -tq "$jar"
unzip -tq "$stage/helheim-$version.zip"
[[ $(unzip -p "$jar" META-INF/plugin.xml | xmlstarlet sel -t -v '/idea-plugin/version') == "$version" ]]
unzip -p "$jar" "${theme_path#/}" | cmp - "$theme"
unzip -p "$jar" "${scheme_path#/}" | cmp - "$scheme"
cp "$jar" "$project_root/dist/helheim-$version.jar"
cp "$stage/helheim-$version.zip" "$project_root/dist/helheim-$version.zip"
printf 'Created %s\n' "$project_root/dist/helheim-$version.jar" "$project_root/dist/helheim-$version.zip"
