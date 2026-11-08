# Foreverbuddy 1.1.0

Eigenständige Forever-Variante von AzerothBuddy, Zielclient Interface 16001 wie Foreverbuddyui.
Dunkle Flächen und neutrale graue Akzente passend zu Foreverbuddyui; keine Abhängigkeit davon.

Enthalten: Charakterübersicht, Dungeon-Transmog, Schaden und Heilung, Aktionsleisten-Vorlagen und Berufspost.
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

### Berufspost

`/fb mail` oder `/fbmail` öffnet die Empfängeroptionen. Beim Öffnen einer
Mailbox erscheint das Fenster automatisch; erst **Senden** startet die gewählte
Berufsgruppe. Empfänger werden getrennt für Horde und Allianz gespeichert. Als Empfänger
Vorname und Nachname mit Leerzeichen eintragen. Alte gemeinsame Empfänger
werden nicht automatisch zugeordnet; bitte je Fraktion einmal neu eintragen.
Je Brief werden bis zum Anhanglimit ganze Stapel verschickt. Weitere Briefe
folgen nach Versandbestätigung. Stoppen verhindert weitere Briefe.

Vorlagen: Alchemie (Kräuter), Inschriftenkunde (Kräuter/Farbstoffe),
Schmiedekunst (Metall/Stein), Ingenieurskunst (Metall/Stein/Teile),
Juwelierskunst (Metall/Stein/Juweliersmaterial), Lederverarbeitung (Leder),
Schneiderei (Stoff), Verzauberkunst (Verzauberungsmaterial), Kochkunst
(Fleisch/Fisch). Gemeinsame Materialien gehen an die zuerst gesendete Gruppe.
Die Vorlagen verwenden Handelswaren-Unterklassen, keine vollständigen Rezepte;
Elementarstoffe und sonstige mehrdeutige Zutaten werden nicht automatisch zugeordnet.
Gebundene, gesperrte und noch nicht geladene Gegenstände werden übersprungen.
Vorhandene Anhänge, Geld oder Nachnahme blockieren den Start. Fehler brechen ab;
verbliebene Anhänge bitte im normalen Briefentwurf prüfen.

Clientprüfung erforderlich: Empfänger speichern, Brief mit einem Stapel,
mehrere Briefe, voller Empfängerbriefkasten, fehlendes Porto, Abbruch,
Mailbox schließen und Kampf. Der Forever-Client steht den lokalen Tests nicht zur Verfügung.

Bei geöffneter Mailbox dockt die Berufspost rechts am normalen Mailfenster an
und folgt dessen Position und Sichtbarkeit. Rahmen, Eingaben und Schaltflächen
verwenden die klassischen Spieltexturen. Außerhalb der Mailbox bleibt
`/fb mail` als frei verschiebbares Einstellungsfenster verfügbar.

## Version 1.1.0

- Berufspost mit neun Materialgruppen, Empfängern je Fraktion und Mehrbriefversand.
- Postfenster angedockt, klassische Spieloptik und aktuelle Gegenstandsschnittstelle.
- Charakterübersicht mit vollständigem Namen ohne Realm-Spalte.
- Versand im Forever-Client vom Nutzer erfolgreich getestet.
