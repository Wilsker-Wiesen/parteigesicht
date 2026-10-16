"""Schritt 6: Abdeckungsbericht docs/ABDECKUNG.md erzeugen.

Zeigt für jede Ebene und Partei, wie viele Gesichter spielbar sind, und für die
Parlamente zusätzlich, wie viele der aktuellen Abgeordneten das sind (Abdeckung).

    python3 pipeline/report.py
"""
import collections, json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from wd import load_json, ROOT
from merge import AW_PARTY


def main():
    ix = load_json("app/data/index.json")
    parties = [p["key"] for p in ix["parties"]]
    plabel = {p["key"]: p["label"] for p in ix["parties"]}
    levels = ix["levels"]
    people = ix["people"]
    playable = collections.Counter((r[1], r[3]) for r in people)
    by_body = collections.Counter((r[4] or "", r[1]) for r in people if r[3] == "landtag")
    faces = load_json("data/faces.json")["people"]
    report = json.load(open(os.path.join(ROOT, "data", "cache", "portraits", "report.json")))
    aw = [e for e in load_json("data/abgeordnetenwatch.json")["entries"] if e["type"] == "mandate" and not e["ended"]]

    L = []
    L.append("# Abdeckung\n")
    L.append(f"Automatisch erzeugt von `pipeline/report.py` · Datenstand {ix['generated']} · **{len(people):,} spielbare Gesichter**\n".replace(",", "."))
    L.append("Spielbar heißt: aktuelle Parteimitgliedschaft bekannt, freies Foto auf Wikimedia Commons, "
             "genau ein Gesicht erkannt und Hintergrund weichgezeichnet.\n")

    L.append("## Gesichter nach Ebene und Partei\n")
    shown = [p for p in parties if sum(playable[(p, l["key"])] for l in levels) > 0]
    L.append("| Ebene | " + " | ".join(plabel[p] for p in shown) + " | Summe |")
    L.append("|---|" + "---:|" * (len(shown) + 1))
    for l in levels:
        row = [playable[(p, l["key"])] for p in shown]
        L.append(f"| {l['label']} | " + " | ".join(str(v) for v in row) + f" | **{sum(row)}** |")
    tot = [sum(playable[(p, l['key'])] for l in levels) for p in shown]
    L.append("| **Summe** | " + " | ".join(f"**{v}**" for v in tot) + f" | **{sum(tot)}** |\n")
    L.append(f"Parteien mit mindestens {ix['minFaces']} Gesichtern in den gewählten Ebenen sind im Spiel wählbar.\n")

    L.append("## Parlamente: Anteil der aktuellen Abgeordneten mit Foto\n")
    L.append("Grundlage sind die aktuellen Mandate laut abgeordnetenwatch.de. "
             "Fehlt ein Gesicht, gibt es meist kein frei lizenziertes Foto auf Commons. "
             "Hier kann man gezielt nachhelfen (siehe README, Abschnitt *Mitmachen*).\n")
    mandates = collections.Counter()
    for e in aw:
        m = AW_PARTY.get(e.get("party") or "") or AW_PARTY.get((e.get("fraction") or "").split(" seit")[0])
        mandates[(e["parliament"], m[0] if m else "SONST")] += 1
    have = collections.Counter()
    for r in people:
        if r[3] == "bundestag": have[("Bundestag", r[1])] += 1
        elif r[3] == "europa": have[("EU-Parlament", r[1])] += 1
        elif r[3] == "landtag": have[(r[4], r[1])] += 1
    parls = sorted({k[0] for k in mandates}, key=lambda x: (x not in ("Bundestag", "EU-Parlament"), x))
    core = ["GRUENE", "SPD", "UNION", "AFD", "LINKE", "FDP", "BSW", "FW"]
    L.append("| Parlament | " + " | ".join(plabel[p] for p in core) + " | gesamt |")
    L.append("|---|" + "---:|" * (len(core) + 1))
    for parl in parls:
        cells = []
        for p in core:
            m, h = mandates[(parl, p)], have[(parl, p)]
            cells.append(f"{h}/{m}" if m else "–")
        m_all = sum(v for k, v in mandates.items() if k[0] == parl)
        h_all = sum(v for k, v in have.items() if k[0] == parl)
        cells.append(f"**{h_all}/{m_all}** ({round(100 * h_all / m_all)} %)")
        L.append(f"| {parl} | " + " | ".join(cells) + " |")
    L.append("")

    L.append("## Aussortierte Fotos\n")
    rej = collections.Counter(v for v in report.values() if not v.startswith("ok"))
    L.append("| Grund | Anzahl |\n|---|---:|")
    for k, v in rej.most_common():
        L.append(f"| {k} | {v} |")
    L.append(f"| nicht geladen oder unklare Lizenz | {len(faces) - len(report)} |\n")

    L.append("## Quellen\n")
    src = collections.Counter(f.get("source") for f in faces if report.get(f["id"], "").startswith("ok"))
    L.append(f"- Wikidata (Parteimitgliedschaft, Ämter): {src.get('wikidata', 0)} Gesichter")
    L.append(f"- abgeordnetenwatch.de (aktuelle Mandate) + Wikidata (Foto): {src.get('abgeordnetenwatch+wikidata', 0)} Gesichter")
    L.append("- Alle Fotos: Wikimedia Commons, Lizenz und Urheber pro Bild in `app/data/index.json`\n")
    open(os.path.join(ROOT, "docs", "ABDECKUNG.md"), "w", encoding="utf-8").write("\n".join(L))
    print("docs/ABDECKUNG.md geschrieben")


if __name__ == "__main__":
    main()
