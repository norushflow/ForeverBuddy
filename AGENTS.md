# Foreverbuddy

Forever. Einstieg in `Core.lua`, `Initialize.lua` und `Modules/`. Aktionsleisten, Rollenvorlagen, native Klickzauber, Berufspost und `/fb` erhalten.

- `git status --short` und TOC zuerst prüfen. Nur relevante Dateien und Tests lesen. Lokale Änderungen erhalten und Diffs prüfen.
- `./tools/check.sh --quick` für gezielte Iteration, `./tools/check.sh --full` für den Abschluss. Bei Fehlern oder Bedarf `--debug` verwenden.
- SavedVariables, Migrationen, Slash-Befehle und Addon-Unabhängigkeit erhalten. Secret Values vor Lua-Operationen prüfen und bestehende Guards für Kampf, geschützte und verbotene Frames beibehalten.
- Keine neuen dauerhaften Ticker, automatischen CVar-Änderungen oder Abhängigkeiten ohne Auftrag. UI, Kampf und Taint im Zielclient prüfen.
- Release-Ablauf in `DEVELOPMENT.md`. Version, Push, Tag und Veröffentlichung nur nach ausdrücklichem Auftrag. Veröffentlichungsziel `norushflow/ForeverBuddy`.
- `TEMP/UEBERGABE.md` hält lokal Ziel, Änderungen, Prüfstatus und nächsten Schritt fest.
