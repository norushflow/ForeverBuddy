#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
toc=Foreverbuddy.toc

if ! command -v luajit >/dev/null; then
    echo 'LuaJIT fehlt. Fedora: sudo dnf install luajit' >&2
    exit 2
fi

declare -A entries=()
while IFS= read -r entry; do
    if [[ ! -f "$entry" ]]; then
        printf 'TOC-Datei fehlt: %s\n' "$entry" >&2
        exit 1
    fi
    entries["$entry"]=1
done < <(awk '{ sub(/\r$/, ""); sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if (NF && !/^#/) print }' "$toc")
test "${#entries[@]}" -gt 0
while IFS= read -r -d '' path; do
    entry=${path#./}
    if [[ ! ${entries[$entry]+listed} ]]; then
        printf 'Lua-Datei fehlt in %s: %s\n' "$toc" "$entry" >&2
        exit 1
    fi
    luajit -bl "$path" >/dev/null
done < <(find . \( -path './.git' -o -path './tests' -o -path './dist' \) -prune -o -type f -name '*.lua' -print0)
printf 'TOC und Lua-Syntax OK (%s)\n' "$toc"

for test in tests/test_*.lua; do
    printf '\n%s\n' "$test"
    luajit "$test"
done
luajit tests/test_buddy.lua disabled
