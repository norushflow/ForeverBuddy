#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source tools/addon.sh

tag=
output=dist
while (( $# )); do
    case $1 in
        --tag) tag=${2:?Versions-Tag fehlt.}; shift 2 ;;
        --output-dir) output=${2:?Zielverzeichnis fehlt.}; shift 2 ;;
        *) fail 'Aufruf: ./tools/release.sh [--tag vX.Y.Z] [--output-dir VERZEICHNIS]' ;;
    esac
done
for command in zip unzip; do
    command -v "$command" >/dev/null || fail "Benötigtes Programm fehlt: $command"
done

load_addon
[[ -z $tag || $tag == "v$version" ]] || fail "Git-Tag muss v$version entsprechen."
out="$output/$(package_name)"
[[ ! -e $out && ! -L $out ]] || fail "ZIP existiert bereits: $out"
./tools/check.sh --full

mkdir -p -- "$output"
stage=$(mktemp -d -- "$output/.package.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir -- "$stage/$addon"
load_media
files=("$toc" "${entries[@]}" "${media[@]}")
for notice in LICENSE* THIRD_PARTY.md; do
    if [[ -f $notice && ! -L $notice ]]; then files+=("$notice"); fi
done

for path in "${files[@]}"; do
    [[ $path =~ ^[A-Za-z0-9_./-]+$ ]] || fail "Ungültiger Paketpfad: $path"
done
cp --parents -- "${files[@]}" "$stage/$addon/"
# Normalize metadata on the copies and pass a sorted file list to Info-ZIP.
(
    cd -- "$stage"
    export LC_ALL=C TZ=UTC
    find "$addon" -type f -exec chmod 0644 {} +
    find "$addon" -type f -exec touch -t 198001010000.00 {} +
    find "$addon" -type f -print | sort | ZIPOPT= zip -q -X -9 addon.zip -@
    unzip -tq addon.zip >/dev/null
    diff -q <(find "$addon" -type f -print | sort) <(unzip -Z -1 addon.zip | sort) >/dev/null ||
        fail 'ZIP-Inhalt stimmt nicht mit den geprüften Paketdateien überein.'
    unzip -p addon.zip "$addon/$toc" | cmp -s "$addon/$toc" - || fail 'TOC im ZIP stimmt nicht überein.'
)
ln -T -- "$stage/addon.zip" "$out"
printf 'Installations-ZIP: %s\n' "$out"
