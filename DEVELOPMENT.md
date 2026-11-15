# Entwicklung und Release

- `./tools/check.sh --quick` prüft TOC und Lua-Syntax und wählt bekannte Tests anhand der Änderungen. `--quick -- PFAD …` begrenzt einen Arbeitsschritt. Bei unbekannten oder gemeinsamen Pfaden läuft die gesamte Suite.
- `./tools/check.sh --full` prüft außerdem Paket- und Versionsdaten. `--debug` zeigt erfolgreiche Testausgaben. Ein ZIP-Bau enthält bereits den Volltest.
- `./tools/release.sh --output-dir VERZEICHNIS` baut ein lokales ZIP. Bash, LuaJIT, zip und unzip müssen verfügbar sein. Bestehende ZIPs bleiben erhalten. Vor einem Release Login, gespeicherte Einstellungen und betroffene Funktionen im Zielclient prüfen, bei UI-Änderungen auch Kampf und Taint. Persönliche Expressway-Dateien gehören in die Spielinstallation.

## Lokaler Spieltest

Nach technischen Tests für eine spielrelevante Änderung diesen Befehl am Ende der Antwort ausgeben und für den Spieltest im lokalen Fedora-Terminal nutzen:

```bash
cd /mnt/UserData/Dokumente/ChatGPT/wow_addon && ./tools/spieltest.sh Foreverbuddy
```

WoW kann geöffnet bleiben. Nach erfolgreicher Installation im WoW-Chat `/reload` ausführen und die betroffene Funktion prüfen.

## Veröffentlichung nach Freigabe

1. Remote-Stand prüfen und die Version in TOC und README setzen. Englischen Abschnitt `## X.Y.Z` in `CHANGELOG.md` ergänzen und dessen Text unter `# vX.Y.Z` in `RELEASE_NOTES.md` übernehmen. Den geprüften Commit auf `main` in `norushflow/ForeverBuddy` bereitstellen.
2. `gh workflow run release.yml --ref main --repo norushflow/ForeverBuddy` starten. Der vorhandene Workflow prüft, baut und vergleicht das ZIP im Release-Entwurf. GitHub legt den Tag beim Veröffentlichen an. Ergebnis in Actions und im Release prüfen. Bei Fehlern denselben Lauf erneut ausführen. Bei einem historischen Tag ohne Release den vorhandenen Tag und das exakt dazu gebaute ZIP gemeinsam abgleichen.
3. In CurseForge zuerst die Dateiliste einschließlich ausstehender Dateien des TOC-Projekts prüfen. Für eine neue Version einmal das GitHub-ZIP mit dem Inhalt von `RELEASE_NOTES.md` als Markdown, der passenden Spielversion und Kanal **Release** einreichen. Bei unklarem Upload-Ausgang zuerst die Dateiliste prüfen. Nach Freigabe Dateilink, Download und Changelog bestätigen. GitHub-Erfolg und CurseForge-Freigabe getrennt melden.
4. Wago: `wago-release.yml` mit dem veröffentlichten Tag starten. Standard ist ein Trockenlauf. Für den Upload `dry_run=false` und `confirm_new=<Tag>` erst nach Prüfung auf Wago setzen; `WAGO_API_TOKEN` muss als GitHub-Secret hinterlegt sein; die GitHub-Variable `WAGO_PROJECT_ID` muss zur TOC passen. Ein erfolgreicher Upload wird für sichere Wiederholungen vermerkt. Bei unklarem Ausgang Wago prüfen; nur falls die Version fehlt, den angezeigten `recover_status_id` für einen erneuten Versuch verwenden. Wago-Freigabe gesondert kontrollieren.
