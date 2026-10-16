# Abdeckung

Automatisch erzeugt von `pipeline/report.py` · Datenstand 2026-10-16 · **6.478 spielbare Gesichter**

Spielbar heißt: aktuelle Parteimitgliedschaft bekannt, freies Foto auf Wikimedia Commons, genau ein Gesicht erkannt und Hintergrund weichgezeichnet.

## Gesichter nach Ebene und Partei

| Ebene | Grüne | SPD | Union | AfD | Linke | FDP | BSW | Freie Wähler | Piraten | ÖDP | Volt | Die PARTEI | SSW | Summe |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bundestag | 69 | 103 | 144 | 43 | 38 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | **398** |
| Europaparlament | 12 | 13 | 26 | 13 | 2 | 5 | 4 | 3 | 0 | 1 | 2 | 2 | 0 | **83** |
| Landtage | 155 | 251 | 339 | 114 | 46 | 22 | 16 | 16 | 0 | 0 | 0 | 0 | 2 | **961** |
| Regierungen | 17 | 20 | 25 | 0 | 6 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **71** |
| Kommunal | 13 | 116 | 144 | 1 | 5 | 7 | 2 | 3 | 2 | 0 | 0 | 0 | 0 | **293** |
| Weitere Parteimitglieder | 625 | 1531 | 1521 | 103 | 325 | 425 | 39 | 10 | 72 | 10 | 1 | 6 | 4 | **4672** |
| **Summe** | **891** | **2034** | **2199** | **274** | **422** | **462** | **61** | **32** | **74** | **11** | **3** | **8** | **7** | **6478** |

Parteien mit mindestens 20 Gesichtern in den gewählten Ebenen sind im Spiel wählbar.

## Parlamente: Anteil der aktuellen Abgeordneten mit Foto

Grundlage sind die aktuellen Mandate laut abgeordnetenwatch.de. Fehlt ein Gesicht, gibt es meist kein frei lizenziertes Foto auf Commons. Hier kann man gezielt nachhelfen (siehe README, Abschnitt *Mitmachen*).

| Parlament | Grüne | SPD | Union | AfD | Linke | FDP | BSW | Freie Wähler | gesamt |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bundestag | 69/85 | 103/120 | 144/208 | 43/151 | 38/64 | – | – | – | **398/630** (63 %) |
| EU-Parlament | 12/12 | 13/14 | 26/29 | 13/15 | 2/3 | 5/5 | 4/4 | 3/3 | **83/96** (86 %) |
| Baden-Württemberg | 22/56 | 7/10 | 22/56 | 0/35 | – | – | – | – | **51/157** (32 %) |
| Bayern | 18/32 | 11/17 | 42/85 | 8/32 | – | – | – | 15/37 | **94/203** (46 %) |
| Berlin | 29/33 | 28/36 | 31/52 | 11/16 | 16/20 | – | 1/1 | – | **116/159** (73 %) |
| Brandenburg | – | 22/34 | 9/12 | 8/30 | – | – | 4/8 | – | **43/88** (49 %) |
| Bremen | 6/10 | 17/28 | 20/24 | 0/1 | 7/10 | 3/5 | – | – | **53/87** (61 %) |
| Hamburg | 4/25 | 16/45 | 9/26 | 2/10 | 4/15 | – | – | – | **35/121** (29 %) |
| Hessen | 16/22 | 19/23 | 28/52 | 12/25 | – | 7/8 | – | – | **82/133** (62 %) |
| Mecklenburg-Vorpommern | 5/5 | 19/34 | 10/12 | 8/15 | 6/9 | 0/3 | – | – | **48/79** (61 %) |
| Niedersachsen | 11/24 | 26/57 | 31/47 | 3/17 | – | – | – | – | **71/146** (49 %) |
| Nordrhein-Westfalen | 25/39 | 32/56 | 50/76 | 7/12 | – | 9/12 | – | – | **123/195** (63 %) |
| Rheinland-Pfalz | 6/10 | 16/32 | 8/39 | 2/23 | – | – | – | – | **32/105** (30 %) |
| Saarland | – | 12/29 | 10/19 | 1/3 | – | – | – | – | **23/51** (45 %) |
| Sachsen | 6/7 | 8/10 | 31/41 | 29/40 | 5/6 | – | 9/14 | 1/1 | **89/120** (74 %) |
| Sachsen-Anhalt | 5/8 | 4/8 | 8/15 | 3/39 | 1/8 | – | 0/5 | – | **21/83** (25 %) |
| Schleswig-Holstein | 2/14 | 10/12 | 10/34 | – | – | 3/5 | – | – | **27/69** (39 %) |
| Thüringen | – | 4/6 | 20/23 | 20/32 | 7/12 | – | 2/2 | – | **53/88** (60 %) |

## Aussortierte Fotos

| Grund | Anzahl |
|---|---:|
| mehrere Gesichter | 198 |
| Gesicht zu klein | 60 |
| kein Gesicht | 29 |
| nicht geladen oder unklare Lizenz | 3 |

## Quellen

- Wikidata (Parteimitgliedschaft, Ämter): 4878 Gesichter
- abgeordnetenwatch.de (aktuelle Mandate) + Wikidata (Foto): 1442 Gesichter
- Alle Fotos: Wikimedia Commons, Lizenz und Urheber pro Bild in `app/data/index.json`
