"""Schritt 3: Wikidata-Personen und aktuelle Parlamente zusammenführen.

- Wer laut abgeordnetenwatch aktuell ein Mandat hat, wird der Ebene des Parlaments
  zugeordnet; Partei und Parlament kommen dann von dort (aktueller als Wikidata).
- Abgeordnete ohne Wikidata-ID bei abgeordnetenwatch werden über den Namen gesucht
  (nur eindeutige Treffer).
- Für alle so gefundenen Personen wird das Foto (P18) aus Wikidata geholt.
- Zusätzliche Personen aus den Commons-Parteikategorien (data/commons_people.json) kommen hinzu.
- Wikidata-Personen, die dort als Bundestags-/Landtags-/EU-Abgeordnete gelten,
  bei abgeordnetenwatch aber kein aktuelles Mandat haben, rutschen nach "weitere".

Ergebnis: data/faces.json — die zentrale Liste aller spielbaren Personen (ohne Bilder).

    python3 pipeline/merge.py
"""
import collections, os, re, sys
from urllib.parse import unquote
sys.path.insert(0, os.path.dirname(__file__))
from wd import sparql, load_json, save_json

AW_PARTY = {
    "CDU": ("UNION", "CDU"), "CSU": ("UNION", "CSU"), "SPD": ("SPD", "SPD"), "AfD": ("AFD", "AfD"),
    "BÜNDNIS 90/­DIE GRÜNEN": ("GRUENE", "Grüne"), "BÜNDNIS 90/DIE GRÜNEN": ("GRUENE", "Grüne"),
    "Die Linke": ("LINKE", "Die Linke"), "DIE LINKE": ("LINKE", "Die Linke"), "FDP": ("FDP", "FDP"),
    "BSW": ("BSW", "BSW"), "FREIE WÄHLER": ("FW", "Freie Wähler"), "SSW": ("SSW", "SSW"),
    "Volt": ("VOLT", "Volt"), "Die PARTEI": ("PARTEI", "Die PARTEI"), "ÖDP": ("OEDP", "ÖDP"),
}
PARLIAMENT_LEVEL = {"Bundestag": "bundestag", "EU-Parlament": "europa"}


def chunks(xs, n):
    for i in range(0, len(xs), n):
        yield xs[i:i + n]


def sparql_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    wd_people = {p["id"]: dict(p, source="wikidata") for p in load_json("data/people.json")["people"]}
    if os.path.exists(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "commons_people.json")):
        for p in load_json("data/commons_people.json")["people"]:
            wd_people.setdefault(p["id"], dict(p, source="commons-kategorie"))
    aw = [e for e in load_json("data/abgeordnetenwatch.json")["entries"] if e["type"] == "mandate" and not e["ended"]]

    # 1. Namen ohne Wikidata-ID auflösen
    missing = sorted({re.sub(r"^(Dr\.|Prof\.)\s+", "", e["name"]) for e in aw if not e.get("qid")})
    name2q = collections.defaultdict(set)
    for i, part in enumerate(chunks(missing, 150)):
        q = ("SELECT ?p ?name WHERE { VALUES ?name { " + " ".join(sparql_str(n) + "@de" for n in part) + " }"
             " ?p rdfs:label ?name ; wdt:P31 wd:Q5 . FILTER NOT EXISTS { ?p wdt:P570 ?d } "
             " { ?p wdt:P27 wd:Q183 } UNION { ?p wdt:P102 ?x } }")
        for r in sparql(q, cache_key=f"names_{i}_{len(part)}_{part[0][:8]}"):
            name2q[r["name"]].add(r["p"])
    resolved = 0
    for e in aw:
        if not e.get("qid"):
            hits = name2q.get(re.sub(r"^(Dr\.|Prof\.)\s+", "", e["name"]), set())
            if len(hits) == 1:
                e["qid"] = next(iter(hits)); e["qid_via"] = "name"; resolved += 1
    print(f"Abgeordnete ohne Wikidata-ID: {len(missing)}, per Name eindeutig gefunden: {resolved}")

    # 2. Fotos für alle Abgeordneten mit Wikidata-ID holen
    qids = sorted({e["qid"] for e in aw if e.get("qid")})
    img, label = {}, {}
    for i, part in enumerate(chunks(qids, 300)):
        q = ("SELECT ?p ?pLabel (SAMPLE(?i) AS ?img) WHERE { VALUES ?p { " + " ".join("wd:" + x for x in part) + " }"
             " ?p wdt:P18 ?i . SERVICE wikibase:label { bd:serviceParam wikibase:language \"de,en\". } } GROUP BY ?p ?pLabel")
        for r in sparql(q, cache_key=f"mpimg_{i}_{part[0]}_{len(part)}"):
            img[r["p"]] = unquote(r["img"].rsplit("/", 1)[-1]); label[r["p"]] = r["pLabel"]

    # 3. Zusammenführen
    faces = {}
    mp_qids = set()
    for e in aw:
        q = e.get("qid")
        mapped = AW_PARTY.get(e.get("party") or "") or AW_PARTY.get((e.get("fraction") or "").split(" seit")[0])
        if not q or q not in img or not mapped:
            continue
        mp_qids.add(q)
        level = PARLIAMENT_LEVEL.get(e["parliament"], "landtag")
        base = wd_people.get(q, {})
        faces[q] = {
            "id": q, "name": base.get("name") or e["name"], "party": mapped[0], "sub": mapped[1],
            "level": level, "body": e["parliament"] if level == "landtag" else None,
            "birth": str(e.get("birth") or base.get("birth") or "") or None,
            "sex": {"f": "w", "m": "m"}.get(e.get("sex")) or base.get("sex"),
            "image": img[q], "positions": base.get("positions", []),
            "source": "abgeordnetenwatch+wikidata",
        }
    demoted = 0
    for q, p in wd_people.items():
        if q in faces:
            continue
        rec = dict(p, body=None)
        if rec["level"] in ("bundestag", "landtag", "europa"):
            rec["level"] = "weitere"; demoted += 1
        faces[q] = rec

    # 4. Kommunale Spitzen: Wikidata führt Bürgermeister und Landräte als
    #    "Leiter der Verwaltung" (P6) an der Gemeinde bzw. dem Kreis.
    heads_q = """SELECT ?p ?placeLabel ?start WHERE {
      ?place p:P6 ?st . ?st ps:P6 ?p . FILTER NOT EXISTS { ?st pq:P582 ?e }
      OPTIONAL { ?st pq:P580 ?start }
      ?place wdt:P17 wd:Q183 . ?p wdt:P31 wd:Q5 . FILTER NOT EXISTS { ?p wdt:P570 ?d }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "de". } }"""
    moved = 0
    for r in sparql(heads_q, cache_key="heads_p6"):
        f = faces.get(r["p"])
        if not f or f["level"] != "weitere":
            continue
        if r.get("start") and r["start"][:4] < "2014":
            continue  # vermutlich nicht mehr im Amt, Enddatum fehlt
        f["level"] = "kommunal"; f["body"] = r.get("placeLabel"); moved += 1
    print(f"{moved} Personen als Bürgermeister/Landrat der kommunalen Ebene zugeordnet")

    out = sorted(faces.values(), key=lambda r: (r["party"], r["level"], r["name"]))
    save_json("data/faces.json", {"count": len(out), "people": out})
    print(f"{len(mp_qids)} aktuelle Abgeordnete mit Foto, {demoted} Wikidata-Mandate ohne aktuelles Mandat nach 'weitere' verschoben")
    print(f"{len(out)} Gesichter insgesamt")


if __name__ == "__main__":
    main()
