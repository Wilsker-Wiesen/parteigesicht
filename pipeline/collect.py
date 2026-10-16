"""Schritt 1: Personen aus Wikidata erheben.

Für jede Partei aus config/parties.json werden alle lebenden Menschen geholt, die
laut Wikidata aktuell (ohne Enddatum) Mitglied sind und ein Foto (P18) haben.
Danach werden ihre aktuellen Ämter (P39) abgefragt und jede Person einer Ebene
aus config/levels.json zugeordnet.

Ergebnis: data/people.json (eine Zeile pro Person, ohne Bilddaten).

    python3 pipeline/collect.py
"""
import re, sys, os, datetime
from urllib.parse import unquote
sys.path.insert(0, os.path.dirname(__file__))
from wd import sparql, load_json, save_json

TODAY = datetime.date.today().isoformat()
MIN_BIRTH_YEAR = 1930  # filtert historische Personen ohne eingetragenes Sterbedatum

PERSONS_Q = """
SELECT ?p ?pLabel ?img ?birth ?sex WHERE {{
  ?p p:P102 ?s . ?s ps:P102 wd:{qid} .
  FILTER NOT EXISTS {{ ?s pq:P582 ?end . }}
  ?p wdt:P31 wd:Q5 ; wdt:P18 ?img .
  FILTER NOT EXISTS {{ ?p wdt:P570 ?death . }}
  OPTIONAL {{ ?p wdt:P569 ?birth . }}
  OPTIONAL {{ ?p wdt:P21 ?sex . }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "de,en". }}
}}"""

# Aktuelle Ämter: Aussage ohne Enddatum; falls eine Wahlperiode angegeben ist,
# darf diese nicht beendet sein.
POSITIONS_Q = """
SELECT ?p ?pos ?posLabel ?start ?term ?termStart ?termEnd WHERE {{
  ?p p:P102 ?s . ?s ps:P102 wd:{qid} . FILTER NOT EXISTS {{ ?s pq:P582 ?end . }}
  ?p wdt:P18 ?img . FILTER NOT EXISTS {{ ?p wdt:P570 ?death . }}
  ?p p:P39 ?st . ?st ps:P39 ?pos .
  FILTER NOT EXISTS {{ ?st pq:P582 ?stEnd . }}
  OPTIONAL {{ ?st pq:P580 ?start . }}
  OPTIONAL {{ ?st pq:P2937 ?term .
             OPTIONAL {{ ?term wdt:P580 ?termStart . }} OPTIONAL {{ ?term wdt:P582 ?termEnd . }} }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "de,en". }}
}}"""



def is_current(r, latest_term):
    """Viele beendete Mandate haben in Wikidata kein Enddatum. Deshalb gilt:
    - Mandat mit Wahlperiode: nur die jüngste begonnene Wahlperiode dieses Amts zählt
      (z. B. 21. Bundestag, nicht 20.), und sie darf nicht beendet sein.
    - Amt ohne Wahlperiode: nur wenn es ab 2018 begonnen hat."""
    if r.get("term"):
        if r.get("termEnd") and r["termEnd"][:10] < TODAY:
            return False
        return r["term"] == latest_term.get(r["pos"])
    return (r.get("start") or "")[:4] >= "2018"


def main():
    parties = load_json("config/parties.json")["parties"]
    levels = load_json("config/levels.json")
    compiled = [(lv, [re.compile(p) for p in lv["patterns"]]) for lv in levels["levels"]]

    people = {}
    conflicts = set()
    all_pos_rows = []
    for party in parties:
        for qid, sub in party["qids"].items():
            rows = sparql(PERSONS_Q.format(qid=qid), cache_key=f"persons_{qid}")
            print(f"{party['label']:<14} {sub:<12} {qid:<11} {len(rows):>6} Personen mit Foto", flush=True)
            for r in rows:
                pid = r["p"]
                birth = r.get("birth", "")[:4]
                if birth.isdigit() and int(birth) < MIN_BIRTH_YEAR:
                    continue
                if re.match(r"Q\d+$", r.get("pLabel", "")):
                    continue  # kein deutscher/englischer Name vorhanden
                rec = people.get(pid)
                if rec and rec["party"] != party["key"]:
                    conflicts.add(pid)
                    continue
                if not rec:
                    rec = people[pid] = {
                        "id": pid, "name": r["pLabel"], "party": party["key"], "sub": sub,
                        "birth": birth or None,
                        "sex": {"Q6581097": "m", "Q6581072": "w"}.get(r.get("sex"), None),
                        "image": r["img"].rsplit("/", 1)[-1], "positions": [],
                    }
            pos_rows = sparql(POSITIONS_Q.format(qid=qid), cache_key=f"positions3_{qid}")
            all_pos_rows.extend(pos_rows)

    # jüngste begonnene Wahlperiode je Amt (über alle Parteien hinweg ermittelt)
    latest_term = {}
    for r in all_pos_rows:
        ts = (r.get("termStart") or "")[:10]
        if r.get("term") and ts and ts <= TODAY and ts > latest_term.get(r["pos"], ("", None))[0]:
            latest_term[r["pos"]] = (ts, r["term"])
    latest_term = {k: v[1] for k, v in latest_term.items()}
    for r in all_pos_rows:
        if r["p"] in people and r.get("posLabel") and is_current(r, latest_term):
            if r["posLabel"] not in people[r["p"]]["positions"]:
                people[r["p"]]["positions"].append(r["posLabel"])

    # Personen mit mehreren aktuellen Parteien sind für ein Ratespiel ungeeignet.
    for pid in conflicts:
        people.pop(pid, None)

    # Personen ohne Geburtsjahr und ohne aktuelles Amt sind häufig historisch.
    for pid in [k for k, v in people.items() if not v["birth"] and not v["positions"]]:
        people.pop(pid)

    for rec in people.values():
        rec["level"] = levels["fallback"]["key"]
        for lv, pats in compiled:
            if any(p.search(pos) for pos in rec["positions"] for p in pats):
                rec["level"] = lv["key"]
                break
        rec["image"] = unquote(rec["image"])

    out = sorted(people.values(), key=lambda r: (r["party"], r["name"]))
    save_json("data/people.json", {"generated": TODAY, "source": "Wikidata (CC0)", "count": len(out), "people": out})
    print(f"\n{len(out)} Personen gespeichert, {len(conflicts)} mit mehreren Parteien verworfen.")


if __name__ == "__main__":
    main()
