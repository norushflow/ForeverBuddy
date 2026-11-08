# Entwicklung und Release

Arbeitsstand ist dieses Git-Repository. Projektregeln: [AGENTS.md](AGENTS.md).
Benötigt werden LuaJIT, zip und unzip.

- `./tools/check.sh`: TOC-Dateipfade, Lua-Syntax und Funktionstests prüfen.
- `./tools/package.sh`: geprüftes Installations-ZIP unter `dist/` erstellen. Bestehende gleichnamige Pakete werden nicht überschrieben.
- Version in TOC, README und internen Versionsmeldungen abgleichen.
- Geprüften Stand nach `main` übertragen. Ein Tag passend zur TOC (`v1.1.0`) startet die Veröffentlichung für WowUp.
- Release-Text wird ausschließlich aus dem passenden Abschnitt in `CHANGELOG.md` erstellt.

Das ZIP enthält Laufzeitdateien, Medien und aktuelle Herkunftshinweise. Entwicklerdokumentation, Tests und Workflows werden nicht installiert.

## Spielprüfung vor Veröffentlichung

Lokale Tests ersetzen keine Prüfung im Zielclient. Login, gespeicherte Einstellungen, Bedienung, Kampf, Gruppen/Raid und mögliche Taint-Meldungen prüfen.

Vorbereitung am 08.11.2026: lokale Syntax-, TOC- und Funktionstests erfolgreich.
