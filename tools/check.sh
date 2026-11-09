#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source tools/addon.sh

mode=full
debug=false
if [[ ${1-} == --quick || ${1-} == --full ]]; then mode=${1#--}; shift; fi
if [[ ${1-} == --debug ]]; then debug=true; shift; fi
if [[ $mode == quick && ${1-} == -- ]]; then
    shift
elif (( $# )); then
    fail 'Aufruf: ./tools/check.sh [--quick|--full] [--debug]; --quick akzeptiert zusätzlich -- PFAD ...'
fi
command -v luajit >/dev/null || fail 'LuaJIT fehlt.'

load_addon
if [[ $mode == full ]]; then validate_release_metadata; fi

# One LuaJIT process compiles runtime files, tests and support files without executing them.
paths=$(find . \( -path './.git' -o -path './dist' -o -path './TEMP' -o -path './WTF' \
    -o -path './SavedVariables' -o -path './Fremd_Addons' -o -path './snapshots' \) -prune \
    -o \( -type f -o -type l \) -name '*.lua' -print)
lua_files=()
while IFS= read -r path; do
    [[ -n $path ]] || continue
    path=${path#./}
    [[ $path == tests/* || ${listed[$path]+present} ]] || fail "Lua-Datei fehlt in $toc: $path"
    lua_files+=("$path")
done <<< "$paths"
luajit - "${lua_files[@]}" <<'LUA'
for _, path in ipairs(arg) do
    local chunk, err = loadfile(path)
    if not chunk then
        io.stderr:write(err, "\n")
        os.exit(1)
    end
end
LUA

# Use one temporary file for git status and test output.
log=$(mktemp)
trap 'rm -f -- "$log"' EXIT
tests=(tests/test_*.lua)
(( ${#tests[@]} > 0 )) || fail 'Keine Testdateien gefunden.'
declare -A selected=()
targeted=false
if [[ $mode == quick ]]; then
    changes=("$@")
    if (( ${#changes[@]} == 0 )) && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git status --porcelain=v1 --no-renames -z --untracked-files=all > "$log"
        while IFS= read -r -d '' record; do changes+=("${record:3}"); done < "$log"
    fi
    if (( ${#changes[@]} )); then
        targeted=true
        for path in "${changes[@]}"; do
            path=${path#./}
            case "$addon:$path" in
                *:Modules/Characters.lua) match=(tests/test_buddy.lua) ;;
                *:Modules/Meters.lua) match=(tests/test_meters.lua) ;;
                *:Modules/Transmog.lua) match=(tests/test_extensions.lua) ;;
                *:Modules/Mail.lua) match=(tests/test_mail.lua) ;;
                *:Modules/Bars/*) match=(tests/test_bars.lua) ;;
                *:Modules/Omnium/*) match=(tests/test_omnium.lua tests/test_performance.lua) ;;
                *:Modules/Tiefen/*) match=(tests/test_delve_*.lua tests/test_identify.lua) ;;
                AzerothBuddy:Layout.lua) match=(tests/test_layout.lua) ;;
                *:ActionStorage.lua|*:ActionStorageGame.lua) match=(tests/test_action_storage.lua) ;;
                *:EditLayout.lua) match=(tests/test_edit_layout.lua tests/test_welcome.lua tests/test_ui.lua) ;;
                *:Equipment.lua) match=(tests/test_equipment.lua tests/test_ui.lua) ;;
                *:Castbars.lua|*:ClassPower.lua|*:Layout.lua|*:Progress.lua|*:RaidTest.lua|*:Tooltips.lua|*:GroupDebuffs.lua|*:Units.lua)
                    match=(tests/test_ui.lua) ;;
                *:Welcome.lua) match=(tests/test_welcome.lua tests/test_ui.lua) ;;
                *:tests/test_*.lua) match=("$path") ;;
                *) targeted=false; break ;;
            esac
            if [[ $path != tests/* ]]; then
                match+=(tests/test_localization.lua)
                if [[ -f tests/test_buddy.lua ]]; then match+=(tests/test_buddy.lua); fi
            fi
            for test in "${match[@]}"; do
                if [[ ! -f $test ]]; then targeted=false; break 2; fi
                selected[$test]=1
            done
        done
    fi
fi

count=0
run_test() {
    if ! luajit "$@" > "$log" 2>&1; then
        printf '%s: %s\n' "$addon" "$*" >&2
        cat -- "$log" >&2
        exit 1
    fi
    if $debug; then
        printf '\n%s\n' "$*"
        cat -- "$log"
    fi
    count=$((count + 1))
}

for test in "${tests[@]}"; do
    if ! $targeted || [[ ${selected[$test]+present} ]]; then
        run_test "$test"
        case $test in
            tests/test_buddy.lua) run_test "$test" disabled ;;
            tests/test_ui.lua) run_test "$test" startup-failure ;;
        esac
    fi
done
printf '%s %s OK (%d Lua-Dateien, %d Testläufe)\n' "$addon" "$mode" "${#lua_files[@]}" "$count"
