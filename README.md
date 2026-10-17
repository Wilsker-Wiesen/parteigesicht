# Parteigesicht

Ein Ratespiel für iPhone, iPad und Browser: Du siehst das Gesicht einer Politikerin oder eines Politikers und tippst, zu welcher Partei die Person gehört. Am Ende jeder Runde zeigt die Auswertung, wen du mit wem verwechselt hast. Das Spiel soll eigene Vorurteile und voreilige Schlüsse sichtbar machen.

Erfasst sind Politikerinnen und Politiker von der Kommune bis zum Europaparlament.

**Spielen:** https://wilsker-wiesen.github.io/parteigesicht/ (im Browser; auf dem iPhone über „Teilen → Zum Home-Bildschirm“ wie eine App)

## Spielmodi

- **Zuordnen:** Mehrere Parteien sind gewählt. Unter dem Foto stehen farbige Kacheln, eine pro Partei. Jede gewählte Partei kommt in einer Runde gleich oft vor.
- **Ja/Nein (Wischen):** Genau eine Partei ist gewählt. Nach rechts wischen heißt „gehört dazu“, nach links „gehört nicht dazu“, wie bei Tinder. Die Hälfte der Gesichter gehört zur gewählten Partei, die andere Hälfte zu anderen Parteien.
- **Ebenen:** Bundestag, Europaparlament, Landtage, Regierungen, Kommunal (Bürgermeister, Landräte, Räte) und weitere Parteimitglieder. Ebenen lassen sich kombinieren.
- **Zeitlimit:** Optional 5 bis 30 Sekunden pro Gesicht. Läuft die Zeit ab, zählt das Gesicht als falsch, und es geht automatisch weiter.
- **Schnell-Bonus:** Jede richtige Antwort innerhalb von 40 % des Zeitlimits (ohne Limit: unter 3 s) bringt einen Bonuspunkt. Die Auswertung zeigt Punkte, Treffer, Bonus und Gesamtzeit; bei gemeinsamen Runden gewinnen die meisten Punkte, bei Gleichstand die kürzere Gesamtzeit.
- **Gemeinsam spielen:** Ein Gerät erzeugt einen Code (10 Zeichen, z. B. `SPXP2-25ZYH`), die anderen geben ihn ein, öffnen den Link oder scannen den QR-Code. Der Code enthält den Zufalls-Startwert, Parteien, Ebenen und Zeitlimit; jedes Gerät zieht daraus dieselben Gesichter in derselben Reihenfolge.
  - **Live** (mit Server): Warteraum mit Namen, der Gastgeber startet für alle, ein Countdown läuft überall gleichzeitig, eine Live-Rangliste zeigt Punkte und Fortschritt, „Nächste Runde für alle“ startet mit neuen Gesichtern im selben Raum.
  - **Ohne Server** (oder ohne Verbindung): dieselbe Runde, jedes Gerät spielt für sich, am Ende werden die Punkte verglichen.
- **Parteien:** Union, SPD, Grüne, AfD und Linke sind vorausgewählt. FDP, BSW, Freie Wähler, Piraten und andere lassen sich dazuschalten, sobald es in der gewählten Ebene mindestens 20 Gesichter gibt.

Wie viele Gesichter es pro Ebene und Partei gibt und wie vollständig die Parlamente abgedeckt sind, steht in [docs/ABDECKUNG.md](docs/ABDECKUNG.md).

## Parteifarben

Alle Farben stammen aus Wikidata (Eigenschaft P465, `pipeline/colors.py`). Das sind die Farben, mit denen Wahlberichte und Statistikämter Parteien kennzeichnen, und sie sind gut voneinander zu unterscheiden. Die Farben der Logos taugen dafür nicht immer: Die Linke nutzt im Logo reines Rot wie die SPD. Die FDP nutzt seit Mai 2026 wieder Blau und Gelb (Logo blau, Gelb als Kampagnenfarbe). Wir nehmen ihr aktuelles Gelb von fdp.de (#FFE000), festgelegt per `colorOverride` in `config/parties.json`. BSW (#792351) ist mit dem offiziellen Logo abgeglichen. Für die Union gilt die CDU-Farbe Schwarz. Helle Farben bekommen auf den Kacheln dunkle Schrift.

## App-Symbol

„Mosaik-Kopf“: Kopf und Schultern aus kleinen Kacheln, jede Spalte gehört einer Partei. Von links nach rechts Linke, Grüne, SPD, FDP, Union, BSW, AfD in den offiziellen Parteifarben. FDP und BSW haben je zwei Spalten, alle anderen drei; das Raster ist leicht nach rechts versetzt, sodass Grün und BSW im Kopf und Linke und AfD in den Schultern liegen. Frühere Fassungen: `pipeline/appicon <datei> 1024 a|b`, Vergleiche in `docs/brand/`. Erzeugt mit `pipeline/appicon.swift`, Vorlage in `docs/brand/app-symbol-1024.png`. Die Entwürfe der Symbol-Runden liegen als Artifacts vor (Symbol-Werkstatt, Mosaik-Varianten).

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
server/               Live-Räume: Cloudflare Worker + Durable Objects (kostenloser Plan)
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

## Web-App veröffentlichen

Automatisch: Jeder Push auf `main`, der etwas in `app/` ändert, veröffentlicht die Seite über GitHub Actions (`.github/workflows/pages.yml`) unter https://wilsker-wiesen.github.io/parteigesicht/. Ersatzweise von Hand: `sh pipeline/publish_pages.sh` (Zweig `gh-pages`).

## Live-Server (Cloudflare)

`server/` enthält einen Cloudflare Worker. Jeder Spielcode ist ein Raum (Durable Object), die Geräte verbinden sich per WebSocket. Gespeichert werden nur Spielname und Punkte, und nur bis der Raum sechs Stunden unbenutzt war. Läuft im kostenlosen Workers-Plan.

```bash
cd server
npm install
npx wrangler dev        # lokal auf Port 8787, zusammen mit der Web-App auf Port 8766
npm test                # Rauchtest mit zwei Spielern gegen wrangler dev
npx wrangler login      # einmalig, mit dem eigenen Cloudflare-Konto
npx wrangler deploy     # veröffentlichen
```

Die Adresse des veröffentlichten Workers steht in `app/index.html` (`LIVE_SERVER`). Erlaubte Webseiten: `ALLOWED_ORIGINS` in `server/wrangler.toml`.

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
