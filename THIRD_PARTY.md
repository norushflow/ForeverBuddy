# Quellen und Lizenzhinweise

## Delve Companion

Autor: FunDeliveryGames
Quelle: https://github.com/FunDeliveryGames/wow-delve-companion
Datei: Data/Config.lua, abgerufen am 25.10.2026 vom Branch main.
Lizenz: MIT, vollständig in LICENSE-DelveCompanion.txt enthalten.

Historisch verwendet wurden die Midnight-Karten-/POI-Zuordnungen sowie die zugehörigen
Story-Erfolgs-IDs und Kennungen für Schlüssel, Fragmente und Schatzsucherkarten.
Seit 1.0.2 sind Tiefenübersicht und die verbleibenden Karten-/Ressourcendaten entfernt.
Herkunftshinweis und Lizenz bleiben zur Dokumentation der Historie erhalten.
Die Implementierung von Anzeige, Erkennung, Auswahl und Speicherung ist eigenständig.

## Delves Companion Advisor

Autor: angel100780 / UllivonBoedefeld
Projekt: https://www.curseforge.com/wow/addons/delves-companion-advisor
Beschreibung: https://www.wowinterface.com/downloads/info27226-DelvesCompanionAdvisor.html
Veröffentlichte Version für die technische Recherche: 1.0.3.
Lizenz laut Projektseite: All Rights Reserved.

Inspiration für den Vergleich aktueller und empfohlener Einstellungen.
Kein Lua-Code, keine Übersetzungstabellen und keine Grafiken dieses Projekts
werden mitgeliefert. Spielkennungen und Gegenstandsnamen sind Referenzdaten;
Empfehlungsregeln und technische Umsetzung wurden eigenständig erstellt.

## WoW-Schnittstellen

Abgleich mit Blizzards veröffentlichtem UI-Code, gespiegelt bei:
https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns

- Blizzard_DelvesCompanionConfiguration/Blizzard_DelvesCompanionConfiguration.lua
- Blizzard_APIDocumentationGenerated/DelvesUIDocumentation.lua
- Blizzard_APIDocumentationGenerated/DelvesConstantsDocumentation.lua
- Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua
- Blizzard_APIDocumentationGenerated/AreaPoiInfoDocumentation.lua
- Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua

Nur Schnittstellenreferenz; keine Blizzard-Dateien werden ausgeliefert.
WoW, Valeera und die Spielinhalte gehören ihren jeweiligen Rechteinhabern.

## Inhaltliche Orientierung

Valeera-Guide, Stand 21.10.2026, geprüft am 25.10.2026:
https://www.icy-veins.com/wow/valeera-sanguinar-delve-companion-guide

Orientierung für die Standard-Kuriositäten Viperwindgötze und Dunduns Gunst.
Vorsichtige Varianten und Ersatzreihenfolgen sind eigene Präferenzregeln.
Kein Guide-Text wurde übernommen. Rangunterschiede werden nicht simuliert.


## EUI Damage Meters (Standalone) – Architekturvergleich

Autor laut TOC: Ellesmere. Vom Benutzer lokal bereitgestellte Version 9.7.
Referenzen: EUI_DamageMeters_Window.lua, EUI_DamageMeters_Lifecycle.lua,
EUI_DamageMeters_State.lua und EUIStandaloneDamageMeters.toc.
Prinzip: eigene Fenster lesen C_DamageMeter-Daten bei deaktivierter nativer Anzeige.
Die Buddy-Implementierung ist eigenständig; keine EUI-Dateien, Bibliotheken,
Grafiken oder Profile werden ausgeliefert. Keine EUI-Abhängigkeit.
Schnittstellenabgleich zusätzlich mit Blizzards DamageMeterDocumentation.lua:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua
