# Parteigesicht: Quellen für frei lizenzierte Politikerporträts

Recherche vom 16./17.10.2026. Alle Zahlen wurden per curl gegen die Commons-API, WDQS und Flickr ermittelt (Stichproben, Stand heute).

## Wichtige technische Hinweise vorab

- **WDQS (query.wikidata.org)**: Mit dem User-Agent `Parteigesicht-research/0.1` allein kam **HTTP 429** zurück („Aggressively rate-limiting to 1 req / min – rule created during active wdqs outage“). Mit einem UA, der Kontaktinfo bzw. eine URL enthält (z. B. `Parteigesicht/0.1 (https://…; kontakt@…) curl`), liefen die Abfragen normal. **Im Projekt daher einen UA mit Kontakt-URL/E-Mail setzen** und POST nutzen.
- **commons-query.wikimedia.org (SDC-SPARQL)**: verifiziert, dass ein Login nötig ist (`HTTP 307` → `Special:OAuth/authenticate`). **Alternative ohne Login:** In der normalen Commons-Suche `haswbstatement:P180=Q…` (CirrusSearch). Beispiel: `list=search&srnamespace=6&srsearch=haswbstatement:P180=Q61053` liefert 641 Treffer. Kombinierbar mit `incategory:"Landtagsprojekt Bayern" haswbstatement:P180` (336 Treffer).
- **Commons-API-Rate-Limits**: Bei schnellen Folgeanfragen gibt es gelegentlich leere bzw. fehlerhafte Antworten. Daher Retry mit Backoff einbauen und `continue` sauber durchreichen.

---

## 1. Wikimedia Commons: Kategorien nach Partei („Members of …“)

**Einstieg:** `Category:Politicians of Germany by party` → enthält `Category:Members of <Partei>`.
Die vom Auftrag vermuteten Namen (`Politicians of the Social Democratic Party of Germany`, `Members of the Free Democratic Party (Germany)` u. a.) **existieren nicht**. Die korrekten Namen lauten:

| Kategorie (exakt) | Unterkategorien (≈ Personen) | Dateien direkt |
|---|---|---|
| `Category:Members of the SPD` | 2776 | 53 |
| `Category:Members of the CDU` | 2619 | 34 |
| `Category:Members of Bündnis 90/Die Grünen` | 943 | 35 |
| `Category:Members of the FDP` | 508 | 15 |
| `Category:Members of Die Linke` | 483 | 26 |
| `Category:Members of the CSU` | 365 | 7 |
| `Category:Members of Alternative für Deutschland` | 296 | 23 |
| `Category:Members of Piratenpartei Deutschland` | 121 | 37 |
| `Category:Members of the BSW` | 70 | 1 |
| `Category:Members of Freie Wähler` | 18 | 13 |
| `Category:Members of Ökologisch-Demokratische Partei` | 16 | 13 |
| `Category:Members of Südschleswigscher Wählerverband` | 10 | 0 |
| `Category:Members of Volt Germany` | 9 | 0 |
| `Category:Members of the Bayernpartei` / `Members of Die PARTEI` | je 5 | 3 |

(Historische Parteien wie KPD, NSDAP, SED oder DDP liegen in derselben Oberkategorie und müssen herausgefiltert werden.)

- **Lizenz:** Pro Datei frei (Commons-Policy). Über `prop=imageinfo&iiprop=extmetadata` (`LicenseShortName`, `Artist`, `Credit`) sind Lizenz und Attribution maschinenlesbar.
- **Abgleich mit Wikidata (selbst gemessen):** Von 6157 per `pageprops.wikibase_item` verknüpften Personenkategorien waren 6009 Menschen (Q5). Davon haben 5528 bereits P18, 5881 haben P102. **Rund 480 Personen haben eine Commons-Kategorie mit Fotos, aber kein P18**, und rund 130 haben kein P102. Dazu kommen etwa 3 % Kategorien ganz ohne Wikidata-Verknüpfung.
- **Hauptmehrwert:** Viele zusätzliche Fotos pro Person (Varianz, bessere Porträts, aktuellere Bilder) sowie rund 500 bis 700 zusätzliche Gesichter.
- **Name und Partei:** Der Kategoriename entspricht dem Personennamen, die Partei ergibt sich aus der Elternkategorie. Für Einzelbilder die Dateien der Personenkategorie holen und Gruppenfotos filtern, etwa über `haswbstatement:P180` mit genau einem Wert oder über Heuristiken (Dateiname, „cropped“, Seitenverhältnis).
- **Empfehlung:** **Jetzt nutzen.**

## 2. Commons: Parlaments- und Fotoprojekte (Wikimedianer-Porträtsessions)

| Kategorie (exakt) | Dateien |
|---|---|
| `Category:Landtagsprojekt Hessen 2013` | 1880 |
| `Category:Landtagsprojekt Bayern` (+ `/Olympiaturm` 440, `/BMW Welt` 68) | 1487 |
| `Category:Landtagsprojekt Mecklenburg-Vorpommern 2013` | 1401 |
| `Category:Landtagsprojekt Nordrhein-Westfalen 2013` | 1201 |
| `Category:Landtagsprojekt Baden-Württemberg 2013` | 989 |
| `Category:Landtagsprojekt Schleswig-Holstein 2013` | 866 |
| `Category:Landtagsprojekt Niedersachsen 2013` | 857 |
| `Category:Landtagsprojekt Thüringen` | 826 |
| `Category:Landtagsprojekt Bremen` | 610 |
| `Category:Landtagsprojekt Sachsen-Anhalt` | 476 |
| `Category:Landtagsprojekt Rheinland-Pfalz` | 387 |
| `Category:Landtagsprojekt Sachsen` / `… Sachsen 2016` | 325 / 231 |
| `Category:Landtagsprojekt Berlin 2013` | 131 |
| `Category:Wiki loves parliaments/Bremische Bürgerschaft 2019/Portraits` | – |
| Oberkategorie: `Category:Landtagsprojekt` (enthält auch AT: Salzburg, NÖ, Vorarlberg, die auszuschließen sind) | |

- **Lizenz:** Überwiegend CC BY-SA 3.0, verifiziert an Stichproben aus Hessen 2013. Die Fotos tragen die Vorlage „Personality rights warning“.
- **Name und Partei:** Jede Datei liegt zusätzlich in der Personenkategorie (z. B. `Category:Hugo Klein`), Hessen 2013 sogar mit Partei im Dateinamen (`0051R-Gruene, Marcus Bocklet.jpg`). Viele Dateien haben P180 (depicts).
- **Achtung:** Die Bilder sind 10 bis 13 Jahre alt. Die Partei zum Aufnahmezeitpunkt kann von der heutigen abweichen. Mehrere Fotos pro Person sind vorhanden (Auswahl nötig).
- **Gesichter:** Geschätzt 1000 bis 1500 Landtagsabgeordnete, großteils bereits über P18 abgedeckt. Der Mehrwert liegt in alternativen Bildern.
- **Empfehlung:** **Jetzt nutzen**, als Bildpool für bereits bekannte Personen. Den Weg über die Personenkategorie zu Wikidata gehen.

**Landtagsmitglieder-Kategorien (deutsch benannt)**, als Personenliste mit Wahlperiode:
`Category:Mitglieder des Abgeordnetenhauses von Berlin` (393), `Mitglieder des Bayerischen Landtags` (397), `Mitglieder der Hamburgischen Bürgerschaft` (360), `Mitglieder der Bremischen Bürgerschaft` (182), `Mitglieder des Landtags Nordrhein-Westfalen (18. Wahlperiode)` (138), `Mitglieder des Sächsischen Landtags (8. Wahlperiode)` (106), `Mitglieder des Thüringer Landtags (8. Wahlperiode)` (84), `Mitglieder des Landtags von Baden-Württemberg (17. Wahlperiode)` (80) usw. (Präfixsuche `list=allcategories&acprefix=Mitglieder des`). Die Partei steht hier nicht im Kategoriebaum und kommt über Wikidata.

## 3. Commons: Kommunalebene (Bürgermeister, Landräte, Räte)

| Kategorie (exakt) | Umfang |
|---|---|
| `Category:Mayors of Germany` → `Mayors of <Bundesland>` (z. B. `Mayors of Bavaria`: 111 Unterkategorien), `Mayors of Germany by city` (156) | einige hundert Personen, viele historisch |
| `Category:Landrat of Germany by state` → `Landrat of <Land>` (13 Länder) | klein |
| `Category:Bezirksbürgermeister in Berlin` | 56 |
| `Category:City councillors of Germany` | nur 25, meist historisch |
| `Category:Members of Ratsversammlung (Kiel)` | 70 |
| `Category:Gemeinderat Ulm 2019` (16 Dateien), `Category:2024 inauguration of Ulm City Council members` | Einzelfall |
| `Category:Kommunalwahl Hof (Saale) 2020` | 21 Dateien |
| `Category:Politicians of Germany by city` → `Politicians of <Stadt>` (38 Städte) | gemischt |

- **Fazit:** Systematische Stadtrats-, Kreistags- oder Bezirksverordneten-Kategorien gibt es auf Commons **praktisch nicht**. Präfixe wie „Stadtrat“, „Kreistag“, „Bezirksverordnete“ oder „Mitglieder des Stadtrats“ lieferten keine Personenkategorien.
- **Name und Partei:** Über die Personenkategorie, Wikidata und P102 oder über die Schnittmenge mit `Members of <Partei>`.
- **Empfehlung:** **Später.** Als Ergänzung nutzen, wenn der Kommunal-Modus gebaut wird. Bürgermeister, Landräte und Bezirksbürgermeister lohnen sich, Räte kaum.

## 4. Flickr-Konten von Parteien und Fraktionen

Die Lizenz wurde per curl auf der Profilseite gelesen (`"license":N` im eingebetteten JSON der letzten 25 Fotos). Flickr-Codes: 0 = alle Rechte vorbehalten, 1–3 = NC-Varianten, 4 = CC BY 2.0, 5 = CC BY-SA 2.0, 6 = BY-ND, 11 = CC BY 4.0, 12 = CC BY-SA 4.0, 15 = BY-NC-SA 4.0, 16 = BY-NC-ND 4.0.

| Konto | Aktuelle Lizenz (Stichprobe) | Schon auf Commons | Bewertung |
|---|---|---|---|
| flickr.com/photos/**gruenenrw** (Grüne NRW) | **CC BY-SA 4.0** (25/25) | `Category:Files from gruenenrw Flickr stream` (370, CC BY-SA 2.0) | **nutzbar** |
| flickr.com/photos/**spd-sh** (SPD Schleswig-Holstein) | **CC BY-SA 4.0** (25/25) | `Category:Files from SPD Schleswig-Holstein Flickr stream` (81, CC BY 2.0) | **nutzbar** |
| flickr.com/photos/**gruene_bawue** (Grüne BW) | **CC BY-SA 2.0** (25/25) | – | **nutzbar** |
| flickr.com/photos/**gruenefraktionbayern** | **CC BY 2.0** (25/25) | – | **nutzbar** |
| flickr.com/photos/**piratenpartei** | CC BY 2.0 / BY-SA 2.0 | – | nutzbar (kleine Partei) |
| flickr.com/photos/**european_parliament** | **CC BY 4.0** (25/25) | – | nutzbar für deutsche MdEP, aber Namens- und Parteizuordnung nur über die Bildbeschreibung |
| flickr.com/photos/**die_linke** | heute **BY-NC-SA 4.0** | `Category:Files from DIE LINKE Flickr stream` (720, CC BY 2.0) | neue Fotos **nicht** nutzbar; die Commons-Altbestände bleiben CC BY 2.0 (Lizenz unwiderruflich) |
| flickr.com/photos/**linksfraktion** | heute **BY-NC-ND 2.0** | `Category:Files from linksfraktion Flickr stream` (226, CC BY 2.0) | wie oben: nur Commons-Bestand |
| flickr.com/photos/**greensefa** | heute alle Rechte vorbehalten | `Category:Files from the Greens EFA Flickr stream` (161, CC BY 2.0) | nur Commons-Bestand |
| gruene-niedersachsen | BY-ND bzw. alle Rechte vorbehalten | – | nicht nutzbar |
| fdpbayern | BY-NC-SA | – | nicht nutzbar |
| spdde, spdsachsen, jusos, dielinkeberlin | alle Rechte vorbehalten | – | nicht nutzbar |

Nicht gefunden (Slug existiert nicht): gruenebundestag, fdp_bundestag, csu, cdu-sachsen, fwbayern, bswpartei, voltdeutschland u. a.

- **Name und Partei:** Die Partei folgt aus dem Konto, der Name aus Titel oder Beschreibung (unstrukturiert, oft Event-Fotos mit mehreren Personen). Für eine saubere Zuordnung ist manueller Abgleich oder ein Upload nach Commons mit Personenkategorie nötig.
- **Gesichter:** Geschätzt einige hundert Personen, überwiegend Landes- und Kommunalpolitiker aus NRW, SH, BW und Bayern (Grüne/SPD).
- **Empfehlung:** **Später** und halbautomatisch. Am besten nach Commons übertragen (Flickr2Commons) und dort kategorisieren, statt direkt aus Flickr zu ziehen. Für einen Flickr-API-Zugriff (`flickr.photos.search`, `user_id`, `license=4,5,9,10,11,12`) wird ein API-Key benötigt. Lizenzen pro Foto prüfen, weil sie sich ändern können (siehe Linke).

**Hintergrund:** Eine Wikimedia-Deutschland-Erhebung vom Juni 2023 (Karte `File:Landtagsfraktionen_und_Freie_Inhalte.png`, netzpolitik.org 2023) nennt Landtagsfraktionen, die Abgeordnetenfotos frei lizenzieren: Hamburg (Linke), Schleswig-Holstein (SPD), Mecklenburg-Vorpommern (CDU), Sachsen-Anhalt (FDP), NRW (Grüne), Hessen (SPD, Linke), Sachsen (Grüne), Bayern (Grüne), Berlin (FDP). Die konkrete Lizenz auf den jeweiligen Fraktionsseiten ist **nicht einzeln verifiziert**. Leitfaden: `File:Handreichung_Parlamentsfotos_in_Wikimedia_Commons.pdf`.

## 5. Landtage, Bundestag und abgeordnetenwatch

- **Abgeordnetenhaus Berlin** (verifiziert, parlament-berlin.de/…/nutzungsbedingungen): nur Pressenutzung, **gewerbliche Nutzung untersagt**, Social Media nur mit schriftlicher Zustimmung, keine Bearbeitung über Farbkorrektur und Zuschnitt hinaus. **Nicht nutzbar.**
- **Landtag Rheinland-Pfalz** (Nutzungsbedingungen-PDF, 18. WP): nur politische Berichterstattung, Bearbeitungsverbot, Löschpflicht. **Nicht nutzbar.**
- **Bayerischer Landtag** (Nutzungsbedingungen-PDF): einfaches Nutzungsrecht, Weitergabe nur mit Zustimmung. **Nicht nutzbar.**
- **Bundestag-Bilddatenbank:** Nutzung pro Bild eingeschränkt (privat oder politische Bildung, teils kein Social Media), keine CC-Lizenz. **Nicht nutzbar.**
- **Landtag NRW und Hamburgische Bürgerschaft:** Keine frei lizenzierten Abgeordnetenfotos gefunden (nicht abschließend verifiziert). Bisher ist kein Landtag bekannt, der Porträts unter CC BY oder CC BY-SA stellt; freie Porträts kommen von den Fraktionen (siehe oben) oder von Wikimedia-Projekten.
- **abgeordnetenwatch.de API** (`https://www.abgeordnetenwatch.de/api/v2/…`): **Daten CC0 1.0** (verifiziert, steht in `meta.abgeordnetenwatch_api.licence`). 36.568 Politiker (inkl. Kandidierende), 18 Parlamente (Bund, 16 Länder, EU), **keine Kommunalebene**. **Die API liefert keine Fotos.** Die Profilfotos auf der Website stammen von den Kandidierenden (Credit z. B. „Bundesministerium der Finanzen / Photothek / Thomas Koehler“) und sind **nicht frei lizenziert**, daher **nicht nutzbar**.
  - **Nützlich ist das Feld `qid_wikidata`**, z. B. Olaf Scholz → Q61053, sowie `party.label`. Damit lässt sich die aktuelle Parteizugehörigkeit gegen Wikidata prüfen und lassen sich fehlende P102-Angaben ergänzen.
  - Beispiel: `GET /api/v2/politicians?first_name=Olaf&last_name=Scholz`
  - **Empfehlung:** **Jetzt nutzen**, aber nur als Metadaten-Quelle (Partei-Validierung), nicht für Bilder.

## 6. Wikidata: Modellierung der Kommunalebene (alle Abfragen live gegen WDQS ausgeführt)

**Baseline:** Menschen mit P18 und P102 = SPD 3514, CDU 3003, Grüne 1016, FDP 727, Linke 535, CSU 443, AfD 327, Piraten 95, BSW (Q123121346; das Label lautet inzwischen „Bündnis Soziale Gerechtigkeit und Wirtschaftliche Vernunft“) 67, Freie Wähler (Q327389) 31 plus FW Bayern (Q1231839) 3, ÖDP (Q294989) 18, SSW (Q161545) 9, Volt (Q106205950) 6, Die PARTEI 10.

**Ratsmitglieder:** Die generische Klasse ist `Q96208019` („member of municipal council“, council member in Germany), dazu `Q108563985` („district deputy“, Kreistag) und `Q113885691` (Bezirksverordneter). Stadtspezifische Positionen werden als `P279` dieser Klassen angelegt: Stadtrat Frankfurt Q131928077, Stadtverordnete Frankfurt Q132048874, Rat Hannover Q133871680, Rostocker Bürgerschaft Q61874573, Freising Q107466947, Schwerin Q137757333, Kreistag Kleve Q20080811 u. a. **Achtung:** Abgeordnetenhaus Berlin, Hamburgische und Bremische Bürgerschaft hängen ebenfalls unter Q96208019 und müssen ausgeschlossen werden.

Personen mit `P39` = Position (gemessen):
Q96208019 direkt: 227 (davon 72 mit Bild) · Stadtverordnete Frankfurt: 154 (58) · Freising: 73 (2) · Rostock: 66 (4) · Kreistag generisch: 49 (30) · Schwerin: 46 (6) · Stadtrat Frankfurt: 24 (18) · Hannover: 10 (8). **Insgesamt nur rund 200 kommunale Ratsmitglieder mit Bild. Wikidata ist hier sehr dünn.**

```sparql
# Ratsmitglieder (P39) – Positionen per VALUES, mit Bild-Zählung
SELECT ?pos (COUNT(DISTINCT ?p) AS ?n) (COUNT(DISTINCT ?pi) AS ?withImg) WHERE {
  VALUES ?pos { wd:Q96208019 wd:Q108563985 wd:Q113885691 wd:Q131928077 wd:Q132048874
                wd:Q133871680 wd:Q61874573 wd:Q107466947 wd:Q137757333 wd:Q20080811 }
  ?p wdt:P39 ?pos .
  OPTIONAL { ?p wdt:P18 ?img . BIND(?p AS ?pi) }
} GROUP BY ?pos ORDER BY DESC(?n)

# Unterklassen finden (neue Städte kommen laufend dazu)
SELECT ?pos ?posLabel WHERE {
  VALUES ?cls { wd:Q96208019 wd:Q108563985 wd:Q113885691 }
  { ?pos wdt:P279 ?cls } UNION { ?pos wdt:P31 ?cls }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en". } }
```
(Eine Variante mit `wdt:P279*` und `GROUP BY` lief in einen Timeout. Daher besser zweistufig vorgehen: erst Positionen holen, dann Personen per VALUES.)

**Bürgermeister über P6 am Gemeinde-Item** (Gemeinden über `P439` Gemeindeschlüssel):
→ 2214 Gemeinden mit aktuellem P6 (ohne P582), 2332 Amtsinhaber, davon 279 mit Bild, 763 mit Partei, **231 mit Bild und Partei**.
```sparql
SELECT ?gem ?hog ?img ?party WHERE {
  ?gem wdt:P439 [] ; p:P6 ?st .
  ?st ps:P6 ?hog . FILTER NOT EXISTS { ?st pq:P582 [] }
  ?hog wdt:P18 ?img ; wdt:P102 ?party . }
```

**Bürgermeister über P39** (generisch `Q30185` mayor oder `Q109862464` Oberbürgermeister, Bürger mit `P27 Q183`):
→ Q30185: 5146 Personen, **820 mit Bild und Partei**; Q109862464: 402 Personen, **178 mit Bild und Partei** (teils historisch, zur Abgrenzung P580/P582 auswerten). Ortsspezifische Positionen (`?pos wdt:P279 wd:Q30185 ; wdt:P1001 ?gem . ?gem wdt:P439 []`) gibt es nur 35, mit 225 Personen.
```sparql
SELECT ?pos (COUNT(DISTINCT ?p) AS ?n) (COUNT(DISTINCT ?pip) AS ?withImgParty) WHERE {
  VALUES ?pos { wd:Q514725 wd:Q30185 wd:Q109862464 }
  ?p p:P39 ?st . ?st ps:P39 ?pos . ?p wdt:P27 wd:Q183 .
  OPTIONAL { ?p wdt:P18 [] ; wdt:P102 [] . BIND(?p AS ?pip) }
} GROUP BY ?pos
```
Für den Ort am P39-Statement die Qualifier `pq:P642` (of) bzw. `pq:P1001` auswerten (nicht gezählt).

**Landräte:** P39 `Q514725` (Landrat): 1437 Personen, **271 mit Bild und Partei**. Alternativ P6 an Kreisen (`P440` Kreisschlüssel): 373 Kreise mit aktuellem Kopf, **157 mit Bild und Partei**.
```sparql
SELECT ?kreis ?hog ?img ?party WHERE {
  ?kreis wdt:P440 [] ; p:P6 ?st . ?st ps:P6 ?hog . FILTER NOT EXISTS { ?st pq:P582 [] }
  ?hog wdt:P18 ?img ; wdt:P102 ?party . }
```
**Hinweis:** Alle diese Personen haben P18 und P102 und sind damit **bereits in der bestehenden P18+P102-Abfrage enthalten**. Der Mehrwert liegt in der Ebenen-Zuordnung (Bürgermeister, Landrat, Rat), etwa für Spielmodi oder Filter, nicht in neuen Gesichtern.

---

## Gesamtbewertung

| # | Quelle | Lizenz | Zusätzliche Gesichter | Empfehlung |
|---|---|---|---|---|
| 1 | Commons `Members of <Partei>`-Bäume | frei (pro Datei, verifiziert über extmetadata) | ca. 500–700 neue Personen plus viele Alternativbilder | **jetzt** |
| 2 | Commons `Landtagsprojekt *` | CC BY-SA 3.0 (Stichprobe) | wenige neue, ca. 13.000 Alternativbilder | **jetzt** (Bildpool) |
| 3 | Wikidata P39/P6 Kommunal (Bürgermeister, Landrat) | CC0 (Daten), Bilder über P18 | kaum neue, aber Ebenen-Metadaten (ca. 1000+) | **jetzt** (Metadaten) |
| 4 | abgeordnetenwatch API | Daten CC0, **Bilder nicht frei** | 0 Bilder; Partei-Validierung über `qid_wikidata` | **jetzt** (nur Metadaten) |
| 5 | Flickr gruenenrw, spd-sh, gruene_bawue, gruenefraktionbayern, piratenpartei, european_parliament | CC BY / BY-SA (verifiziert an Stichprobe) | einige hundert, unstrukturiert | **später** (über Commons importieren) |
| 6 | Flickr-Altbestände Linke/Linksfraktion/Greens-EFA auf Commons | CC BY 2.0 auf Commons | ca. 1100 Dateien, meist schon in Personenkategorien | **jetzt** (läuft über #1 mit) |
| 7 | Commons kommunal (Mayors, Landrat, Bezirksbürgermeister in Berlin, Ratsversammlung Kiel) | frei | ca. 100–300 | **später** |
| 8 | Landtags- und Bundestags-Bilddatenbanken, abgeordnetenwatch-Fotos, Partei-Pressebilder | nicht frei | – | **nicht nutzbar** |
