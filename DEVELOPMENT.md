# Entwicklung und Release

Benötigt werden Bash und LuaJIT, für ZIPs zusätzlich zip und unzip. Die TOC definiert Dateireihenfolge, Zielclient und Version.

- `./tools/check.sh --quick` prüft alle Lua-Dateien und die TOC-Struktur. Die Tests folgen bekannten Änderungen aus Git. Bei gemeinsam genutzten oder unbekannten Pfaden sowie ohne Änderungen läuft die gesamte Suite. Mit `--quick -- PFAD ...` lässt sich der Prüfumfang für einen Arbeitsschritt explizit wählen.
- `./tools/check.sh --full` ist der Standard. Er prüft alle Testszenarien, SavedVariables-Namen, Abhängigkeiten, Versionsstand und Paketdateien. Erfolg ergibt eine Zeile. `--debug` zeigt auch erfolgreiche Testausgaben.
- `./tools/release.sh` baut nach einem Volltest ein reproduzierbares ZIP in `dist/`. `./tools/package.sh` bleibt als bisheriger Aufruf verfügbar. `--output-dir VERZEICHNIS` erlaubt ein anderes Ziel. Vorhandene ZIPs bleiben erhalten.
- Nach Releasefreigabe Version in TOC, README und gegebenenfalls UI-Version und Startmeldung abgleichen. In `CHANGELOG.md` unter `## X.Y.Z` kurze englische Aufzählungspunkte pflegen. `RELEASE_NOTES.md` mit `# vX.Y.Z` und den englischen Punkten für GitHub und CurseForge aktualisieren. Ein passender Tag `vX.Y.Z` startet den GitHub-Workflow für WowUp.
- Das ZIP enthält TOC-Dateien, geladene Lua-/XML-Dateien, Medien und Herkunftshinweise. CurseForge-Projekt-ID und Paketkonfiguration stehen in TOC und `.pkgmeta`.

Vor einer Veröffentlichung Login, gespeicherte Einstellungen, Bedienung, Kampf, Gruppen/Raid und Taint im Zielclient prüfen.
