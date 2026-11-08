# ForeverBuddy 1.1.3

<p align="center"><img src="branding/icon-400.png" alt="ForeverBuddy" width="160" height="160"></p>

Eine kompakte Zentrale für Charaktere, Dungeon-Transmog, Schaden und Heilung, Aktionsleisten-Vorlagen und den Versand von Berufsmaterialien.

**Client:** WoW Forever · **Interface:** 16001 · **Eigenständig:** keine zusätzlichen Addons erforderlich.

## Funktionen

- Charakterübersicht mit vollständigen Namen und den neun Forever-Klassen.
- Dungeon-Transmog und eigene Schadens-/Heilungsanzeige.
- Leistenvorlagen je Klasse einschließlich nativer Klickzauberbelegung.
- Berufspost mit neun Materialgruppen und getrennten Empfängern für Horde und Allianz.

## Installation

Das Installations-ZIP unter [Releases](https://github.com/norushflow/ForeverBuddy/releases) herunterladen und den enthaltenen Ordner `Foreverbuddy` in `Interface/AddOns/` des passenden Spielclients entpacken. Die Datei `Foreverbuddy.toc` muss direkt in diesem Ordner liegen. Anschließend im Spiel aktivieren und `/reload` ausführen.

Für WowUp die [Repository-Adresse](https://github.com/norushflow/ForeverBuddy) importieren und den passenden Spielclient wählen.

## Bedienung

- `/fb` oder `/foreverbuddy`: Zentrale öffnen.
- `/fb chars`, `/fb transmog`, `/fb meter`, `/fb bars`: Bereiche öffnen.
- `/fbbars speichern|laden|an|aus|status`: Leistenvorlagen verwalten.
- `/fb mail` oder `/fbmail`: Empfänger der Berufspost einstellen.
- Minimap-Kompass: Linksklick öffnet die Zentrale, Rechtsklick die Charakterübersicht.

**Berufspost:** Vor- und Nachnamen mit Leerzeichen als Empfänger eintragen. An der Mailbox dockt das Fenster rechts an; erst **Senden** startet den Versand. Weitere Briefe folgen nach Bestätigung, **Stoppen** verhindert weitere Briefe. Gemeinsame Materialien gehen an die zuerst gesendete Gruppe. Gebundene oder gesperrte Gegenstände werden übersprungen; vorhandene Anhänge, Geld oder Nachnahme blockieren den Start. Nach Fehlern verbliebene Anhänge im normalen Briefentwurf prüfen.

Die Materialgruppen richten sich nach Handelswaren-Unterklassen, nicht nach vollständigen Rezepten. Mehrdeutige Zutaten werden nicht automatisch zugeordnet. Alte Spezialisierungsvorlagen bleiben gespeichert; die gewünschte Belegung einmal als Klassenvorlage sichern. Vorlagen ohne Klickzauberdaten verändern die Klickbelegung nicht.

## Änderungen und Entwicklung

Die [Versionshistorie](CHANGELOG.md) enthält ausschließlich Änderungen am Addon.
Prüfungen, Paketbau und noch offene Spieltests stehen in [Entwicklung und Release](DEVELOPMENT.md).
