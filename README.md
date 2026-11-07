# Foreverbuddy 1.0.1

Eigenständige Forever-Variante von AzerothBuddy, Zielclient Interface 16001 wie Foreverbuddyui.
Dunkle Flächen und neutrale graue Akzente passend zu Foreverbuddyui; keine Abhängigkeit davon.

Enthalten: Charakterübersicht, Dungeon-Transmog, Schaden und Heilung, Aktionsleisten-Vorlagen.
Tiefen/Valeera und Omnium/Runen sind vollständig aus dem Laufzeitumfang entfernt.
Eigene Daten: `ForeverbuddyDB` und `ForeverbuddyCharDB`; keine Übernahme der Retail-Daten.

## Bedienung

- `/fb` oder `/foreverbuddy`: Zentrale.
- `/fb chars`, `/fb transmog`, `/fb meter`, `/fb bars`: Bereiche öffnen.
- `/fbbars speichern|laden|an|aus|status`: Aktionsleisten-Vorlagen.
- Minimap-Kompass: Linksklick Zentrale, Rechtsklick Charakterübersicht.

## Installation und Prüfung

`./tools/check.sh` prüft Syntax, TOC und Funktionstests.
`./tools/package.sh` erstellt ein Installations-ZIP in `dist/`.
Den Ordner `Foreverbuddy` im Forever-Client unter `Interface/AddOns/` installieren.
Die Module behalten die vorhandenen API-Prüfungen der Ausgangsversion.
Die Interface-Kennung allein garantiert keine API-Kompatibilität: Prüfung von Login,
Charakteren, Transmog, Metern, Leisten, Kampf und Darstellung im Forever-Client steht aus.
Privates Repository: https://github.com/norushflow/Foreverbuddy
Ein Versions-Tag passend zur TOC erstellt über GitHub Actions ein WowUp-Release.

Die Charakterfilter enthalten nur die neun Forever-Klassen. Veraltete Retail-Klassenfilter
werden zurückgesetzt; gespeicherte Charakterdaten bleiben erhalten.

Die Leistenvorlage gilt je Klasse, ohne Spezialisierung. „Vorlage speichern“
sichert die Aktionsleisten und die native Klickzauberbelegung; „Vorlage laden“
stellt beide wieder her. Bei aktiver Automatik werden auch Änderungen der
Klickzauber gespeichert. Automatisches Speichern und Laden warten im Kampf.
Alte Spezialisierungsvorlagen bleiben in den gespeicherten Daten erhalten;
bitte einmal die gewünschte aktuelle Belegung als neue Vorlage speichern.
Vorlagen ohne Klickzauberdaten lassen die aktuelle Klickbelegung unverändert.

API-Referenz: [Blizzards Klickzauber-Oberfläche](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ClickBindingUI/Blizzard_ClickBindingUI.lua).
Die tatsächlichen API-Berechtigungen und Taintfreiheit müssen im Forever-Client geprüft werden.
