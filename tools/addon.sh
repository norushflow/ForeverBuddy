#!/usr/bin/env bash
# Shared by check.sh and release.sh. Run from the addon repository root.

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

regular_path() {
    local path=$1
    [[ -f $path && ! -L $path ]] || return 1
    while [[ $path == */* ]]; do
        path=${path%/*}
        [[ ! -L $path ]] || return 1
    done
}

load_addon() {
    shopt -s nullglob
    local tocs=(*.toc) line key
    [[ ${#tocs[@]} == 1 ]] || fail 'Genau eine TOC im Addon-Verzeichnis erwartet.'
    toc=${tocs[0]}
    addon=${toc%.toc}
    [[ $addon =~ ^[A-Za-z][A-Za-z0-9]*$ && ! -L $toc ]] || fail "Ungültige TOC: $toc"

    declare -gA metadata=() listed=()
    declare -ga entries=()
    local header='^##[[:blank:]]+([^:]+):[[:blank:]]*(.*)$'
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        if [[ $line =~ $header ]]; then
            key=${BASH_REMATCH[1],,}
            [[ ! ${metadata[$key]+present} ]] || fail "Doppeltes TOC-Feld: $key"
            metadata[$key]=${BASH_REMATCH[2]}
        elif [[ -n $line && $line != '#'* ]]; then
            [[ $line =~ ^([A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.(lua|xml)$ ]] &&
                [[ $line != tests/* && $line != tools/* && $line != TEMP/* && $line != dist/* ]] ||
                fail "Ungültiger TOC-Dateipfad: $line"
            regular_path "$line" || fail "TOC-Datei fehlt oder ist ein Link: $line"
            [[ ! ${listed[$line]+present} ]] || fail "Doppelter TOC-Eintrag: $line"
            listed[$line]=1
            entries+=("$line")
        fi
    done < "$toc"
    (( ${#entries[@]} > 0 )) || fail "Keine Laufzeitdateien in $toc"
    [[ ${listed[Core.lua]+present} ]] || fail "Core.lua fehlt in $toc"
    version=${metadata[version]-}
    title=${metadata[title]-}
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Ungültige Version in $toc"
    [[ ${metadata[interface]-} =~ ^[0-9]{5,6}$ ]] || fail "Ungültiges Interface in $toc"
}

release_notes() {
    awk -v version="$version" '
        { sub(/\r$/, "") }
        /^## / { active = ($0 == "## " version); if (active) sections++; next }
        active && NF { print; if (/^- [^ ]/) bullets++ }
        END { if (sections != 1 || !bullets) exit 1 }
    ' CHANGELOG.md
}

validate_release_metadata() {
    local account="${addon}DB" character="${addon}CharDB" key heading versions icon path
    [[ $addon != AzerothBuddyUI ]] || account=$addon
    [[ ${metadata[savedvariables]-} == "$account" &&
        ${metadata[savedvariablespercharacter]-} == "$character" ]] ||
        fail "SavedVariables in $toc müssen $account und $character sein."

    for key in "${!metadata[@]}"; do
        case $key in
            dep*|*deps|*dependencies|loadwith|loadmanagers|loadondemand)
                fail "Unerwartete Ladeabhängigkeit in $toc: $key" ;;
        esac
    done
    [[ ${metadata[x-curse-project-id]-} =~ ^[1-9][0-9]*$ &&
        -n ${metadata[notes]-} && -n ${metadata[notes-dede]-} ]] ||
        fail "CurseForge-ID oder Beschreibung fehlt in $toc."
    [[ -n $title ]] || fail "Titel fehlt in $toc."
    IFS= read -r heading < README.md || fail "README-Kopf fehlt."
    [[ ${heading%$'\r'} == "# $title $version" ]] || fail "README-Version passt nicht zu $toc."
    release_notes >/dev/null || fail "Changelog-Abschnitt für $version fehlt oder ist mehrdeutig."

    if [[ $addon == *[Uu][Ii] ]]; then
        versions=$(sed -nE 's/^UI\.VERSION[[:blank:]]*=[[:blank:]]*"([^"]+)".*/\1/p' Core.lua)
        [[ $versions == "$version" ]] || fail "UI.VERSION passt nicht zu $toc."
        for path in Core.lua Locales/enUS.lua Locales/deDE.lua; do
            versions=$(sed -nE 's/.*"Version ([0-9]+\.[0-9]+\.[0-9]+) .*".*/\1/p' "$path")
            [[ -n $versions ]] ||
                fail "Versionsmeldung in $path passt nicht zu $toc."
            while IFS= read -r key; do
                [[ $key == "$version" ]] || fail "Versionsmeldung in $path passt nicht zu $toc."
            done <<< "$versions"
        done
    fi

    icon=${metadata[icontexture]-}
    icon=${icon//\\/\/}
    [[ $icon == "Interface/AddOns/$addon/Media/"* ]] || fail "Ungültiger IconTexture-Pfad in $toc."
    icon=${icon#"Interface/AddOns/$addon/"}
    [[ $icon == *.tga ]] || icon+=.tga
    regular_path "$icon" && [[ -s $icon ]] || fail "TOC-Icon fehlt oder ist ungültig: $icon"
    local assets=()
    case $addon in
        AzerothBuddy|Foreverbuddy) assets=(Media/MORPHEUS.TTF) ;;
        AzerothBuddyUI|Foreverbuddyui) assets=(Media/BuddyIcon.png Media/Selection.tga) ;;
    esac
    if [[ $addon == Foreverbuddyui ]]; then
        assets+=(Media/UnitMasks/{148x28,220x18,240x38,260x18,264x18,296x22,300x46,56x58}.tga)
    fi
    for path in "${assets[@]}"; do
        regular_path "$path" && [[ -s $path ]] || fail "Paketdatei fehlt oder ist ungültig: $path"
    done
    [[ ! -f Style.lua || -f THIRD_PARTY.md ]] || fail 'Herkunftshinweise fehlen (THIRD_PARTY.md).'

    local notes_heading
    IFS= read -r notes_heading < RELEASE_NOTES.md || fail 'RELEASE_NOTES.md fehlt oder ist leer.'
    [[ $notes_heading == "# v$version" ]] && grep -Eq '^- [^[:space:]]' RELEASE_NOTES.md ||
        fail "RELEASE_NOTES.md muss zu v$version passen und Stichpunkte enthalten."

    awk -v addon="$addon" '
        BEGIN {
            split("AGENTS.md CHANGELOG.md DEVELOPMENT.md README.md RELEASE_NOTES.md SECURITY.md TEMP branding dist tests tools", required)
            for (i in required) allowed[required[i]] = 1
            allowed["docs"] = allowed["OMNIUM_PROFILES.md"] = 1
        }
        /^package-as:/ { if ($2 != addon || NF != 2) exit 1; names++; next }
        /^manual-changelog:[[:space:]]*$/ { manual++; next }
        /^[[:space:]]+filename: RELEASE_NOTES\.md$/ && manual { filenames++; next }
        /^[[:space:]]+markup-type: markdown$/ && manual { markup++; next }
        /^ignore:[[:space:]]*$/ { ignore++; next }
        /^[[:space:]]*- / && ignore {
            if (NF != 2 || !allowed[$2] || ignored[$2]) exit 1
            ignored[$2] = 1; next
        }
        /^[[:space:]]*(#.*)?$/ { next }
        { exit 1 }
        END {
            if (names != 1 || ignore != 1 || manual != 1 || filenames != 1 || markup != 1) exit 1
            for (i in required) if (!ignored[required[i]]) exit 1
        }
    ' .pkgmeta || fail "CurseForge-Paketkonfiguration passt nicht zu $toc."
    for path in docs OMNIUM_PROFILES.md; do
        if [[ -e $path ]]; then
            grep -Fxq -- "  - $path" .pkgmeta || fail "CurseForge muss $path ausschließen."
        fi
    done
}

package_name() {
    local suffix=
    if [[ -n ${1-} && $addon == Forever* ]]; then suffix=-forever; fi
    printf '%s-%s%s.zip\n' "$addon" "$version" "$suffix"
}
