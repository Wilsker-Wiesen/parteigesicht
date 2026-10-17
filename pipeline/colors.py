"""Parteifarben aus Wikidata übernehmen (Eigenschaft P465, sRGB-Farbe).

Das sind die Farben, mit denen Wahlberichterstattung und Statistikämter Parteien
kennzeichnen. Sie sind bewusst gut unterscheidbar. Logofarben eignen sich dafür nicht
immer: Die Linke nutzt im Logo reines Rot (wie die SPD), die FDP seit 2026 Marineblau.

Mit "colorOverride" in config/parties.json lässt sich eine Farbe festlegen, die Vorrang
vor Wikidata hat (FDP: neues Logo vom Mai 2026, in Wikidata noch das alte Gelb).

Für die Union zählt die Farbe der CDU. Ist eine Partei ohne Wikidata-Farbe, bleibt der
Wert in config/parties.json stehen. Helle Farben bekommen dunkle Schrift (textDark).

    python3 pipeline/colors.py        # zeigt Änderungen und schreibt config/parties.json
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from wd import sparql, load_json, save_json


def luminance(hex_):
    r, g, b = (int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def main():
    cfg = load_json("config/parties.json")
    qids = [q for p in cfg["parties"] for q in p["qids"]]
    rows = sparql("SELECT ?p ?c WHERE { VALUES ?p { " + " ".join("wd:" + q for q in qids) + " } ?p wdt:P465 ?c }",
                  cache_key="party_colors_p465_cfg")
    color = {r["p"]: "#" + r["c"].upper() for r in rows}
    for p in cfg["parties"]:
        main_qid = next(iter(p["qids"]))  # erste ID = Hauptpartei (bei der Union: CDU)
        new = color.get(main_qid)
        if p.get("colorOverride"):  # bewusst gesetzte Farbe, z. B. nach einem neuen Logo
            new = p["colorOverride"]["color"]
        if new and new.lower() != p["color"].lower():
            print(f"{p['key']:<8} {p['color']} -> {new}")
            p["color"] = new
        # Weiß auf der Kachel braucht genug Kontrast (WCAG 3:1 für große Schrift)
        p["textDark"] = (1.05 / (luminance(p["color"]) + 0.05)) < 3
        p["colorSource"] = p["colorOverride"]["source"] if p.get("colorOverride") else ("Wikidata P465" if new else "eigene Wahl")
    save_json("config/parties.json", cfg)


if __name__ == "__main__":
    main()
