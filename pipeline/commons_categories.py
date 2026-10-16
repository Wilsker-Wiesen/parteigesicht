"""Schritt 2b: Zusätzliche Gesichter aus den Commons-Kategorien der Parteien.

Commons sortiert Personen in Kategorien wie "Members of the SPD". Viele dieser
Personen haben ein Foto auf Commons, aber in Wikidata kein Bild (P18) oder keine
Parteimitgliedschaft (P102) eingetragen – sie fehlen deshalb in Schritt 1.

Vorgehen:
1. Personen-Unterkategorien jeder Partei-Kategorie auflisten
2. über die Kategorie-Seite das Wikidata-Item ermitteln
3. nur lebende Menschen, deren aktuelle Partei in Wikidata nicht widerspricht
4. Foto: P18, sonst das erste JPEG der Personenkategorie
   (Gruppenfotos sortiert später pipeline/portrait aus)

Ergebnis: data/commons_people.json — wird von pipeline/merge.py übernommen.

    python3 pipeline/commons_categories.py
"""
import json, os, re, sys, time
from urllib.parse import urlencode, unquote
sys.path.insert(0, os.path.dirname(__file__))
from wd import curl, sparql, load_json, save_json, CACHE

API = "https://commons.wikimedia.org/w/api.php?"


def api(params, cache_name=None):
    path = os.path.join(CACHE, "commons", (cache_name or "") + ".json") if cache_name else None
    if path and os.path.exists(path):
        return json.load(open(path))
    d = json.loads(curl(API + urlencode(dict(params, format="json"))))
    if path:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        json.dump(d, open(path, "w"))
    time.sleep(0.1)
    return d


def members(cat, cmtype, limit=500):
    out, cont, i = [], {}, 0
    while True:
        d = api({"action": "query", "list": "categorymembers", "cmtitle": "Category:" + cat, "cmtype": cmtype,
                 "cmlimit": limit, **cont}, f"cm_{cmtype}_{re.sub(r'[^A-Za-z0-9]', '_', cat)[:80]}_{i}")
        out += [m["title"] for m in d["query"]["categorymembers"]]
        if "continue" not in d:
            return out
        cont = {"cmcontinue": d["continue"]["cmcontinue"]}; i += 1


def main():
    parties = load_json("config/parties.json")["parties"]
    known = {p["id"] for p in load_json("data/people.json")["people"]}
    qid2party = {}
    for pt in parties:
        for q in pt["qids"]:
            qid2party[q] = pt["key"]

    cand = {}  # Personenkategorie -> Partei
    for pt in parties:
        for cat in pt.get("commons", []):
            subs = members(cat, "subcat")
            print(f"{cat:<48} {len(subs):>5} Unterkategorien", flush=True)
            for s in subs:
                cand.setdefault(s, set()).add(pt["key"])

    # Wikidata-Item der Kategorie-Seiten
    titles = sorted(cand)
    cat2q = {}
    for i in range(0, len(titles), 50):
        part = titles[i:i + 50]
        d = api({"action": "query", "prop": "pageprops", "ppprop": "wikibase_item", "titles": "|".join(part)},
                f"pp_{i}_{len(titles)}")
        norm = {n["to"]: n["from"] for n in d["query"].get("normalized", [])}
        for pg in d["query"]["pages"].values():
            q = pg.get("pageprops", {}).get("wikibase_item")
            if q:
                cat2q[norm.get(pg["title"], pg["title"])] = q
    print(f"{len(titles)} Personenkategorien, {len(cat2q)} mit Wikidata-Item", flush=True)

    # Kategorien zeigen entweder direkt auf das Personen-Item oder auf ein Kategorie-Item;
    # letzteres lösen wir über P301 (Hauptthema der Kategorie) auf.
    new = {c: q for c, q in cat2q.items() if q not in known and len(cand[c]) == 1}
    # a) Kategorie-Items auf die Person umlenken (P301), b) Personendaten holen
    items = sorted(set(new.values()))
    main_of = {}
    for i in range(0, len(items), 200):
        part = items[i:i + 200]
        q = "SELECT ?item ?main WHERE { VALUES ?item { " + " ".join("wd:" + x for x in part) + " } ?item wdt:P301 ?main . }"
        for r in sparql(q, cache_key=f"commonscat_main_{i}_{len(items)}"):
            main_of[r["item"]] = r["main"]
    qs = sorted({main_of.get(x, x) for x in items})
    info_p = {}
    for i in range(0, len(qs), 100):
        part = qs[i:i + 100]
        q = ("SELECT ?p ?pLabel ?img ?birth ?death ?party ?partyEnd ?sex WHERE { VALUES ?p { "
             + " ".join("wd:" + x for x in part) + " } "
             "?p wdt:P31 wd:Q5 . OPTIONAL { ?p wdt:P18 ?img } OPTIONAL { ?p wdt:P569 ?birth } OPTIONAL { ?p wdt:P570 ?death } "
             "OPTIONAL { ?p wdt:P21 ?sex } "
             "OPTIONAL { ?p p:P102 ?ps . ?ps ps:P102 ?party . OPTIONAL { ?ps pq:P582 ?partyEnd } } "
             "SERVICE wikibase:label { bd:serviceParam wikibase:language \"de,en\". } }")
        for r in sparql(q, cache_key=f"commonscat_p_{i}_{len(qs)}"):
            e = info_p.setdefault(r["p"], {"p": r["p"], "name": r.get("pLabel"), "img": r.get("img"), "birth": r.get("birth"),
                                           "death": r.get("death"), "sex": r.get("sex"), "current": set(), "any": set()})
            if r.get("party"):
                e["any"].add(r["party"])
                if not r.get("partyEnd"):
                    e["current"].add(r["party"])
    info = {item: info_p[main_of.get(item, item)] for item in items if main_of.get(item, item) in info_p}

    out, skipped = [], {"verstorben/historisch": 0, "andere Partei aktuell": 0, "kein Foto": 0, "ohne Name": 0, "schon erfasst": 0}
    for cat, item in new.items():
        e = info.get(item)
        if not e:
            continue
        party = next(iter(cand[cat]))
        if e["p"] in known:
            skipped["schon erfasst"] += 1; continue
        if e["death"] or (e["birth"] and e["birth"][:4] < "1930"):
            skipped["verstorben/historisch"] += 1; continue
        cur = {qid2party.get(x, "?") for x in e["current"]}
        if cur and cur != {party}:
            skipped["andere Partei aktuell"] += 1; continue
        if not e["birth"] and not e["current"]:
            skipped["verstorben/historisch"] += 1; continue
        if not e["name"] or re.match(r"Q\d+$", e["name"]):
            skipped["ohne Name"] += 1; continue
        img = unquote(e["img"].rsplit("/", 1)[-1]) if e.get("img") else None
        if not img:
            files = [f[5:] for f in members(cat[9:], "file", 30) if re.search(r"\.jpe?g$", f, re.I)]
            # Dateien bevorzugen, deren Name den Nachnamen enthält
            surname = e["name"].split()[-1].lower()
            files.sort(key=lambda f: (surname not in f.lower(), len(f)))
            img = files[0] if files else None
        if not img:
            skipped["kein Foto"] += 1; continue
        sub = next((v for q, v in next(pt for pt in parties if pt["key"] == party)["qids"].items() if q in e["current"]), None)
        if party == "UNION" and not sub:
            sub = "CSU" if "CSU" in cat else "CDU"
        out.append({"id": e["p"], "name": e["name"], "party": party, "sub": sub, "birth": (e["birth"] or "")[:4] or None,
                    "sex": {"Q6581097": "m", "Q6581072": "w"}.get(e.get("sex")), "image": img, "positions": [],
                    "level": "weitere", "commons_category": cat[9:],
                    "party_basis": "wikidata" if e["current"] else "commons-kategorie"})
        known.add(e["p"])
    save_json("data/commons_people.json", {"count": len(out), "skipped": skipped, "people": out})
    print(f"{len(out)} zusätzliche Personen; übersprungen: {skipped}")


if __name__ == "__main__":
    main()
