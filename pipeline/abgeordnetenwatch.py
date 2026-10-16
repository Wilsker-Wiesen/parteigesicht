"""Schritt 2: Aktuelle Parlamente über die abgeordnetenwatch.de-API (Daten: CC0 1.0).

Wikidata ist bei laufenden Wahlperioden der Landtage oft unvollständig. Abgeordnetenwatch
führt für Bundestag, alle 16 Landtage und das EU-Parlament die aktuellen Mandate
(und die Kandidaturen der letzten Wahl) samt Fraktion bzw. Partei. Viele Einträge haben
eine Wikidata-Kennung; darüber kommen wir an ein freies Foto.

Fotos von abgeordnetenwatch selbst werden NICHT verwendet (nicht frei lizenziert).

Ergebnis: data/abgeordnetenwatch.json

    python3 pipeline/abgeordnetenwatch.py
"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from wd import curl, save_json, CACHE

API = "https://www.abgeordnetenwatch.de/api/v2"


def get(path, cache_name):
    p = os.path.join(CACHE, "aw", cache_name + ".json")
    if os.path.exists(p) and time.time() - os.path.getmtime(p) < 72 * 3600:
        return json.load(open(p))
    d = json.loads(curl(API + path))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(d, open(p, "w"))
    time.sleep(0.3)
    return d


def paged(path, cache_name, page=1000):
    out, start = [], 0
    while True:
        sep = "&" if "?" in path else "?"
        d = get(f"{path}{sep}range_start={start}&range_end={page}", f"{cache_name}_{start}")
        out += d["data"]
        start += page
        if start >= d["meta"]["result"]["total"]:
            return out


def main():
    parliaments = get("/parliaments?range_end=50", "parliaments")["data"]
    entries = []
    for parl in parliaments:
        proj = parl.get("current_project")
        if not proj:
            continue
        rows = paged(f"/candidacies-mandates?parliament_period={proj['id']}", f"cm_{proj['id']}")
        n_m = sum(r["type"] == "mandate" for r in rows)
        print(f"{proj['label']:<34} {n_m:>4} Mandate {len(rows) - n_m:>5} Kandidaturen", flush=True)
        for r in rows:
            fr = r.get("fraction_membership") or []
            current_fr = [f for f in fr if not f.get("valid_until")]
            entries.append({
                "aw_politician": r["politician"]["id"],
                "name": r["politician"]["label"],
                "parliament": parl["label"],
                "period": proj["label"],
                "type": r["type"],
                "ended": bool(r.get("end_date")),
                "fraction": (current_fr or fr or [{}])[-1].get("label"),
            })

    # Politiker-Details (Partei, Wikidata-ID) in Blöcken nachladen
    ids = sorted({e["aw_politician"] for e in entries})
    pol = {}
    for i in range(0, len(ids), 100):
        chunk = ids[i:i + 100]
        d = get("/politicians?id[in]=[" + ",".join(map(str, chunk)) + "]&range_end=100", f"pol_{chunk[0]}_{chunk[-1]}")
        for p in d["data"]:
            pol[p["id"]] = {"party": (p.get("party") or {}).get("label"), "qid": p.get("qid_wikidata"),
                            "sex": p.get("sex"), "birth": p.get("year_of_birth")}
        if i % 2000 == 0:
            print(f"  Politiker {i}/{len(ids)}", flush=True)
    for e in entries:
        e.update(pol.get(e["aw_politician"], {}))
    save_json("data/abgeordnetenwatch.json", {"source": "abgeordnetenwatch.de API v2 (CC0 1.0)", "entries": entries})
    print(f"{len(entries)} Einträge, {len(ids)} Personen, davon {sum(1 for p in pol.values() if p['qid'])} mit Wikidata-ID")


if __name__ == "__main__":
    main()
