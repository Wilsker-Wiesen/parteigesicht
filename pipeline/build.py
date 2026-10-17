"""Schritt 5: Spieldaten bauen.

1. Porträts aufbereiten (pipeline/portrait: Gesicht zuschneiden, Hintergrund weichzeichnen)
2. Pro Partei und Ebene Bildbögen mit je 25 Gesichtern erzeugen (pipeline/sprites)
3. app/data/index.json schreiben: Parteien, Ebenen, Bögen und alle Personen

    python3 pipeline/build.py
"""
import collections, json, os, random, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
from wd import load_json, save_json, ROOT

RAW = os.path.join(ROOT, "data", "cache", "raw")
PORTRAITS = os.path.join(ROOT, "data", "cache", "portraits")
OUT = os.path.join(ROOT, "app", "data")
CELL_W, CELL_H, COLS, PER_SHEET = 288, 360, 5, 25


def main():
    os.makedirs(PORTRAITS, exist_ok=True)
    subprocess.run([os.path.join(ROOT, "pipeline", "portrait"), RAW, PORTRAITS, "360"], check=True)
    report = json.load(open(os.path.join(PORTRAITS, "report.json")))

    parties = load_json("config/parties.json")
    levels = load_json("config/levels.json")
    level_keys = [l["key"] for l in levels["levels"]] + [levels["fallback"]["key"]]
    commons = load_json("data/commons.json")
    faces = load_json("data/faces.json")["people"]

    usable = [p for p in faces if report.get(p["id"], "").startswith("ok")]
    rejected = collections.Counter(report.get(p["id"], "nicht geladen") for p in faces if p not in usable)
    print(f"{len(usable)} spielbare Gesichter; aussortiert: {dict(rejected)}")

    groups = collections.defaultdict(list)
    for p in usable:
        groups[(p["party"], p["level"])].append(p)

    rng = random.Random(42)  # feste Mischung: gleiche Eingabe ergibt gleiche Bögen
    os.makedirs(os.path.join(OUT, "sheets"), exist_ok=True)
    for f in os.listdir(os.path.join(OUT, "sheets")):
        os.remove(os.path.join(OUT, "sheets", f))
    sheets, manifest, people = [], [], []
    for (party, level), members in sorted(groups.items()):
        rng.shuffle(members)
        for i in range(0, len(members), PER_SHEET):
            part = members[i:i + PER_SHEET]
            idx = len(sheets)
            name = f"{party.lower()}-{level}-{i // PER_SHEET + 1}.jpg"
            sheets.append({"file": "sheets/" + name, "party": party, "level": level, "n": len(part)})
            manifest.append({"out": os.path.join(OUT, "sheets", name),
                             "cells": [os.path.join(PORTRAITS, p["id"] + ".jpg") for p in part]})
            for cell, p in enumerate(part):
                m = commons.get(p["image"], {})
                people.append([p["name"], party, p.get("sub"), level, p.get("body"), idx, cell,
                               m.get("artist") or "unbekannt", m.get("license", ""), p["image"], p["id"]])

    mpath = os.path.join(ROOT, "data", "cache", "sprites.json")
    json.dump({"cellW": CELL_W, "cellH": CELL_H, "cols": COLS, "quality": 0.58, "sheets": manifest}, open(mpath, "w"))
    subprocess.run([os.path.join(ROOT, "pipeline", "sprites"), mpath], check=True)

    counts = collections.Counter((p[1], p[3]) for p in people)
    index = {
        "generated": load_json("data/people.json")["generated"],
        "cell": {"w": CELL_W, "h": CELL_H, "cols": COLS},
        "minFaces": parties["min_faces"],
        "parties": [{k: v for k, v in pt.items() if k != "qids"} | {"counts": {l: counts[(pt["key"], l)] for l in level_keys}}
                    for pt in parties["parties"]],
        "levels": [{"key": l["key"], "label": l["label"]} for l in levels["levels"]]
                  + [{"key": levels["fallback"]["key"], "label": levels["fallback"]["label"]}],
        "sheets": sheets,
        # Parteilogos für die Auflösung (pipeline/logos.py); Schlüssel: Partei, bei der Union CDU/CSU
        "logos": load_json("app/data/logos/logos.json") if os.path.exists(os.path.join(OUT, "logos", "logos.json")) else {},
        "fields": ["name", "party", "sub", "level", "body", "sheet", "cell", "artist", "license", "file", "wikidata"],
        "people": people,
    }
    save_json("app/data/index.json", index, pretty=False)
    size = sum(os.path.getsize(os.path.join(OUT, "sheets", f)) for f in os.listdir(os.path.join(OUT, "sheets")))
    print(f"{len(people)} Personen auf {len(sheets)} Bögen ({size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
