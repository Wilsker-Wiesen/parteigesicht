# Parteigesicht

Ein Ratespiel für iPhone, iPad und Browser: Du siehst das Gesicht einer Politikerin oder eines Politikers und tippst, zu welcher Partei die Person gehört. Am Ende jeder Runde zeigt die Auswertung, wen du mit wem verwechselt hast. Das Spiel soll eigene Vorurteile und voreilige Schlüsse sichtbar machen.

Erfasst sind Politikerinnen und Politiker von der Kommune bis zum Europaparlament.

## Spielmodi

- **Zuordnen:** Mehrere Parteien sind gewählt. Unter dem Foto stehen farbige Kacheln, eine pro Partei. Jede gewählte Partei kommt in einer Runde gleich oft vor.
- **Ja/Nein (Wischen):** Genau eine Partei ist gewählt. Nach rechts wischen heißt „gehört dazu“, nach links „gehört nicht dazu“, wie bei Tinder. Die Hälfte der Gesichter gehört zur gewählten Partei, die andere Hälfte zu anderen Parteien.
- **Ebenen:** Bundestag, Europaparlament, Landtage, Regierungen, Kommunal (Bürgermeister, Landräte, Räte) und weitere Parteimitglieder. Ebenen lassen sich kombinieren.
- **Parteien:** Union, SPD, Grüne, AfD und Linke sind vorausgewählt. FDP, BSW, Freie Wähler, Piraten und andere lassen sich dazuschalten, sobald es in der gewählten Ebene mindestens 20 Gesichter gibt.

Wie viele Gesichter es pro Ebene und Partei gibt und wie vollständig die Parlamente abgedeckt sind, steht in [docs/ABDECKUNG.md](docs/ABDECKUNG.md).

## Parteifarben

Alle Farben stammen aus Wikidata (Eigenschaft P465, `pipeline/colors.py`). Das sind die Farben, mit denen Wahlberichte und Statistikämter Parteien kennzeichnen, und sie sind gut voneinander zu unterscheiden. Die Farben der Logos taugen dafür nicht immer: Die Linke nutzt im Logo reines Rot wie die SPD, die FDP seit 2026 Marineblau ähnlich der AfD. BSW (#792351) ist mit dem offiziellen Logo abgeglichen. Für die Union gilt die CDU-Farbe Schwarz. Helle Farben bekommen auf den Kacheln dunkle Schrift.

## App-Symbol

„Spektrum-Kopf“: Kopf und Schultern aus sieben gleich breiten Streifen, von links nach rechts Linke, Grüne, SPD, FDP, Union, BSW, AfD. Grün ist noch im Kopf zu sehen, das AfD-Blau ganz rechts liegt nur in den Schultern, die Linke ganz links ebenfalls. Erzeugt mit `pipeline/appicon.swift`, Vorlage in `docs/brand/app-symbol-1024.png`.

## Herkunft der Daten

| Was | Quelle | Lizenz |
|---|---|---|
| Fotos | [Wikimedia Commons](https://commons.wikimedia.org) | frei (CC BY, CC BY-SA, CC0, gemeinfrei u. a.), Urheber unter jedem Bild |
| Parteimitgliedschaft, Ämter, Bürgermeister/Landräte | [Wikidata](https://www.wikidata.org) | CC0 |
| Aktuelle Mandate in Bundestag, Landtagen und EU-Parlament | [abgeordnetenwatch.de API](https://www.abgeordnetenwatch.de/api) | CC0 |
| Zusätzliche Personen | Commons-Kategorien „Members of …“ je Partei | frei |

Fotos von Parlaments- oder Parteiwebseiten werden **nicht** verwendet, weil sie urheberrechtlich geschützt sind. Die Recherche zu weiteren Quellen steht in [docs/QUELLEN-RECHERCHE.md](docs/QUELLEN-RECHERCHE.md).

Nach jedem Tipp erscheint klein das Logo der Partei (von Commons; urheberrechtlich gemeinfrei bzw. CC BY/CC BY-SA mit Urhebernennung, aber als Marken geschützt). Auf den Kacheln selbst stehen nur Farbe und Name, damit das Logo nicht beim Raten hilft.

Jedes Foto wird auf das Gesicht zugeschnitten. Der Hintergrund wird mit Apples Vision-Framework freigestellt, stark weichgezeichnet und entsättigt. So verraten Parteilogos, Plakate oder Parteifarben im Hintergrund nichts.

## Aufbau

```
config/
  parties.json        Parteien: Wikidata-IDs, Farben, Commons-Kategorien, Mindestzahl
  levels.json         Ebenen und Regeln, welche Ämter zu welcher Ebene gehören
pipeline/             Datenerhebung, in dieser Reihenfolge:
  collect.py          1  Wikidata: lebende Parteimitglieder mit Foto und aktuellen Ämtern
  abgeordnetenwatch.py 2 aktuelle Mandate aller 18 Parlamente
  commons_categories.py 2b zusätzliche Personen aus Commons-Parteikategorien
  merge.py            3  alles zusammenführen, Ebenen festlegen → data/faces.json
  images.py           4  Lizenzangaben und Fotos von Commons laden
  logos.py            5a Parteilogos von Commons für die Auflösung → app/data/logos/
  colors.py           Parteifarben aus Wikidata (P465) → config/parties.json
  build.py            5  Porträts aufbereiten, Bildbögen bauen → app/data/
  report.py           6  Abdeckungsbericht → docs/ABDECKUNG.md
  portrait.swift      Gesicht finden, zuschneiden, Hintergrund weichzeichnen (Vision)
  sprites.swift       25 Porträts je Bildbogen zusammensetzen
  appicon.swift       App-Symbol „Spektrum-Kopf“ zeichnen (iOS, Web)
  stats.py            Kurzübersicht Partei × Ebene
data/
  people.json         Ergebnis Schritt 1
  abgeordnetenwatch.json  Ergebnis Schritt 2
  commons_people.json Ergebnis Schritt 2b
  faces.json          alle spielbaren Personen (ohne Bilder)
  commons.json        Urheber und Lizenz jedes Fotos
app/                  Web-App (eine HTML-Datei) + data/ (index.json, Bildbögen)
ios/                  native SwiftUI-App für iPhone und iPad
docs/                 Abdeckung, Quellenrecherche, brand/ (App-Symbol)
```

## Daten neu erzeugen

Voraussetzungen: macOS (für das Vision-Framework), Python 3, curl, die Xcode-Kommandozeilenwerkzeuge.

```bash
swiftc -O pipeline/portrait.swift -o pipeline/portrait
swiftc -O pipeline/sprites.swift -o pipeline/sprites
python3 pipeline/collect.py
python3 pipeline/abgeordnetenwatch.py
python3 pipeline/commons_categories.py
python3 pipeline/merge.py
python3 pipeline/images.py      # lädt ~6.800 Fotos, dauert ca. 30 Minuten
python3 pipeline/logos.py
python3 pipeline/build.py       # Porträts aufbereiten: ca. 45 Minuten
python3 pipeline/report.py
```

Abfragen und Downloads landen in `data/cache/` (nicht im Repository). Ein zweiter Lauf lädt nur, was fehlt.

## Web-App lokal starten

```bash
python3 -m http.server 8765 -d app
```

Dann http://localhost:8765 öffnen. Auf iPhone oder iPad kann man die Seite über „Teilen → Zum Home-Bildschirm“ wie eine App ablegen.

## iOS-App bauen

Benötigt Xcode (aus dem App Store) und [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cd ios
xcodegen
open Parteigesicht.xcodeproj
```

In Xcode ein Team unter *Signing & Capabilities* wählen, dann auf einem Simulator oder dem eigenen Gerät starten. Die App enthält alle Bildbögen (~100 MB) und funktioniert offline.

## Bekannte Grenzen

- **Aktualität:** Parteiwechsel und Amtsenden werden in Wikidata nicht immer eingetragen. Für Bundestag, Landtage und EU-Parlament gilt deshalb abgeordnetenwatch. Bei allen anderen Personen kann die Partei veraltet sein.
- **Ungleiche Abdeckung:** Für viele Abgeordnete, besonders der AfD und neu gewählter Landtage, gibt es kein freies Foto. Die Gewichtung pro Runde gleicht das aus: Jede Partei kommt gleich oft vor.
- **Kommunalebene:** Für Gemeinderäte gibt es kaum freie Fotos mit Namen. Erfasst sind vor allem Bürgermeister und Landräte.
- **Abgleich über den Namen:** Abgeordnete ohne Wikidata-Kennung bei abgeordnetenwatch werden über den Namen gesucht. Es zählen nur eindeutige Treffer, Verwechslungen sind aber nicht ganz ausgeschlossen.

## Mitmachen

Die wirksamste Hilfe sind mehr freie Fotos:

1. Ein eigenes Foto einer Kommunalpolitikerin oder eines Kommunalpolitikers (mit Einverständnis) auf Wikimedia Commons unter CC BY-SA hochladen.
2. In Wikidata beim Personeneintrag das Bild (P18) und die Partei (P102) eintragen.
3. Die Pipeline neu laufen lassen.
