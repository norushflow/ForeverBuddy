#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
addon=Foreverbuddy
for command in zip unzip; do
    if ! command -v "$command" >/dev/null; then
        echo 'Fedora: sudo dnf install zip unzip' >&2
        exit 2
    fi
done

./tools/check.sh
version=$(awk '/^## Version:/ {gsub(/\r/, ""); print $3}' "$addon.toc")
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo 'Ungültige TOC-Version' >&2; exit 1; }

mkdir -p dist
out="$PWD/dist/$addon-$version.zip"
if [[ -e "$out" || -L "$out" ]]; then
    printf 'ZIP existiert bereits: %s\n' "$out" >&2
    exit 1
fi

stage=$(mktemp -d "$PWD/dist/.package.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir "$stage/$addon"
while IFS= read -r entry; do
    case "${entry,,}" in
        *.lua|*.xml) cp --parents -- "$entry" "$stage/$addon/" ;;
        *) printf 'Unerwarteter Dateityp in TOC: %s\n' "$entry" >&2; exit 1 ;;
    esac
done < <(awk '{ sub(/\r$/, ""); sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if (NF && !/^#/) print }' "$addon.toc")
cp -- "$addon.toc" "$stage/$addon/"
# Copy only runtime media, even if development notes are stored in Media/.
while IFS= read -r -d '' media; do
    cp --parents -- "$media" "$stage/$addon/"
done < <(find Media -type f \( -iname '*.png' -o -iname '*.tga' -o -iname '*.ttf' \) -print0)
for notice in LICENSE* THIRD_PARTY.md; do
    if [[ -f "$notice" ]]; then cp -- "$notice" "$stage/$addon/"; fi
done
(cd -- "$stage" && zip -qrX addon.zip "$addon")
unzip -tq "$stage/addon.zip"
ln -- "$stage/addon.zip" "$out"
printf 'Installations-ZIP: %s\n' "$out"
