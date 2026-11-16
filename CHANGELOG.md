# Changelog

## 1.1.16

- Preserve rested XP when logging out or switching characters, and ignore incomplete XP data during login.
- Estimate offline rested XP using the last known rest location and sort characters by the displayed estimate. Unknown XP data is shown as a dash; log in once on affected characters to refresh old data. Offline estimates use base rates without special bonuses.
- Improve close-button placement in the main window and character overview, enlarge and right-align the gold total-playtime text in both tabs, and widen the race column.

## 1.1.15

- Sorry for the profession mail bug that could send materials to the wrong character. Profession mail now skips shared recipe materials and checks every attachment before sending. Ruined Leather Scraps are included for Leatherworking.

## 1.1.14

- Show character race and filter the overview by Horde or Alliance.
- Calculate average item level from equipped items.

## 1.1.13

- Match profession mail materials by item ID using a local Forever material database, including shared materials and the reagent bag.
- Offer seven crafting professions and a bank character as recipients while keeping existing supported assignments.
- Enable gathering highlighting by default; retain an explicitly disabled setting.

Material data is based on the ForeverTome client archive (build 1.60.1.70707). Historical and incomplete records may be present; some materials may be missing. Source: https://forevertome.com/professions

## 1.1.12

- Add an opt-in Herbs / Ore switch to the ForeverBuddy panel. It alternates between learned tracking types when the client permits it.
- Add an experimental Highlighting switch for game-provided interaction icons, outlines, and eligible quest-object sparkles. Visibility depends on the object and client settings.

## 1.1.11

- Verify restored native click-casting bindings and report updates rejected by the client.
- Add Wago project metadata and strengthen release package validation.

## 1.1.10

- Fix the damage and healing meter bars overlapping the window border.

## 1.1.9

- Remove the logo from the character overview and align the title and subtitle with the tabs.

## 1.1.8

- Match the Retail design across the hub, character overview, transmog, damage and healing meters, and profession mail.
- Refresh the action bar template panel and wrap longer status messages above the existing role, save, and load controls.
- Use WoW’s native nameplate texture for meter bars and the client font when an optional Expressway file is unavailable.

## 1.1.7

- Run the profession mail update only while a send is in progress.
- Reduce repeated sorting and rested XP calculations in the character overview.
- Reuse the existing frame and tooltip guards in the transmog module.
- Streamline local checks and make release ZIPs reproducible.

## 1.1.6

- Select an action bar template role manually for each character. Automatic role synchronization has been removed.
- Loading and overwriting templates require confirmation.
- Shared role templates include the contents of character macros used by action bars and native click casting.

## 1.1.5

- Aktionsleisten 1–10 und native Klickzauber werden je Charakter und Klasse gesichert, auch unter Stufe 10 und ohne Spezialisierung oder Rolle.
- Vorlagen für Tank, Heiler und Schaden werden nach Klasse getrennt gespeichert. Die optionale Rollensynchronisierung lädt beim Rollenwechsel die passende Belegung.
- Bestehende Klassenvorlagen bleiben manuell ladbar. Automatische Sicherungen werden getrennt gespeichert.

## 1.1.4

- Deutsche und englische Sprachdateien mit gemeinsamer Codebasis; `enUS`/`enGB` und Englisch als Fallback für weitere Sprachen.
- Die Zentrale schließt beim Aufrufen eines Moduls; Aktionsleisten behalten das Menü offen.
- Bei aktivem ForeverBuddyUI übernimmt dessen charakterbezogene Sicherung die Automatik, damit die alte Klassenvorlage nicht beim Login darübergeschrieben wird. Manuelles Speichern/Laden bleibt verfügbar.

## 1.1.3

- CurseForge-Projekt-ID und Paketkonfiguration ergänzt.

## 1.1.2

- Anzeigenamen in der Addonübersicht und den Fenstern auf **ForeverBuddy** vereinheitlicht.

## 1.1.1

- Autorenangabe in der Addonübersicht auf **norushflow** geändert.

## 1.1.0

- Berufspost mit neun Materialgruppen, Empfängern je Fraktion und Versand mehrerer Briefe hinzugefügt.
- Postfenster dockt am normalen Mailfenster an und verwendet klassische Spieltexturen.
- Charakterübersicht zeigt den vollständigen Namen ohne Realm-Spalte.

## 1.0.1

- Aktionsleisten-Vorlagen gelten je Klasse und speichern die native Klickzauberbelegung mit.
- Automatisches Speichern und Laden warten bis zum Kampfende.

## 1.0.0

- Eigenständige Forever-Zentrale mit Charakterübersicht, Dungeon-Transmog, Schadens-/Heilungsanzeige und Leistenvorlagen eingeführt.
- Charakterfilter auf die neun Forever-Klassen begrenzt.
