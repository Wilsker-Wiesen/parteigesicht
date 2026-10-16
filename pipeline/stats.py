"""Gibt eine Tabelle Partei × Ebene für data/people.json aus."""
import collections, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from wd import load_json
d = load_json(sys.argv[1] if len(sys.argv) > 1 else "data/faces.json")["people"]
lv = [l["key"] for l in load_json("config/levels.json")["levels"]] + ["weitere"]
pa = [x["key"] for x in load_json("config/parties.json")["parties"]]
c = collections.Counter((p["party"], p["level"]) for p in d)
print("Partei".ljust(9), *[l[:9].rjust(9) for l in lv], "gesamt".rjust(7))
for k in pa:
    print(k.ljust(9), *[str(c[(k, l)]).rjust(9) for l in lv], str(sum(c[(k, l)] for l in lv)).rjust(7))
