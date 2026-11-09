# Entwicklung und Release

Arbeitsstand ist dieses Git-Repository. Projektregeln: [AGENTS.md](AGENTS.md).
Benötigt werden LuaJIT, zip und unzip.

- `./tools/check.sh`: TOC-Dateipfade, Lua-Syntax und Funktionstests prüfen.
- `./tools/package.sh`: geprüftes Installations-ZIP unter `dist/` erstellen. Bestehende gleichnamige Pakete werden nicht überschrieben.
- Version in TOC, README und internen Versionsmeldungen abgleichen.
- Geprüften Stand nach `main` übertragen. Ein Tag passend zur TOC (`v1.1.1`) startet die Veröffentlichung für WowUp.
- Vor dem Tag `RELEASE_NOTES.md` ersetzen. Erste Zeile `# vX.Y.Z` passend zur TOC-Version, danach englische Markdown-Stichpunkte nur für dieses Release. Die Historie bleibt in `CHANGELOG.md`.
- GitHub verwendet `RELEASE_NOTES.md` direkt. Für CurseForge denselben Tag nach erfolgreichem GitHub-Workflow mit dem Packager und der eingecheckten `.pkgmeta` veröffentlichen. Bei einem manuellen ZIP-Upload den Inhalt derselben Datei als Markdown einfügen.

Das ZIP enthält Laufzeitdateien, Medien und aktuelle Herkunftshinweise. Entwicklerdokumentation, Tests und Workflows werden nicht installiert.

## Spielprüfung vor Veröffentlichung

Lokale Tests ersetzen keine Prüfung im Zielclient. Login, gespeicherte Einstellungen, Bedienung, Kampf, Gruppen/Raid und mögliche Taint-Meldungen prüfen.

Vorbereitung am 08.11.2026: lokale Syntax-, TOC- und Funktionstests erfolgreich.
