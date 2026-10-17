"""Schritt 5b: Parteilogos für die Auflösung nach dem Tipp.

Holt für jede Partei aus config/parties.json das Logo (Wikidata P154) von Wikimedia
Commons als PNG und legt es unter app/data/logos/<Name>.png ab. Bei der Union gibt es
zwei Logos (CDU, CSU), bei allen anderen eins pro Partei.

Die Logos sind auf Commons urheberrechtlich gemeinfrei (reine Schrift- und Formlogos),
aber als Marken geschützt. Das Spiel zeigt sie nur zur Kennzeichnung der Partei,
und zwar erst nachdem getippt wurde.

Ergebnis: app/data/logos/*.png und app/data/logos/logos.json (Datei, Lizenz, Commons-Seite)

    python3 pipeline/logos.py
"""
import html, json, os, re, subprocess, sys
from urllib.parse import urlencode, unquote
sys.path.insert(0, os.path.dirname(__file__))
from wd import curl, sparql, load_json, save_json, ROOT, UA

OUT = os.path.join(ROOT, "app", "data", "logos")


def main():
    parties = load_json("config/parties.json")["parties"]
    names = {}  # Wikidata-ID -> Dateiname ohne Endung
    for pt in parties:
        for qid, sub in pt["qids"].items():
            names[qid] = sub if pt["key"] == "UNION" else pt["key"]
    rows = sparql("SELECT ?p (SAMPLE(?l) AS ?logo) WHERE { VALUES ?p { " + " ".join("wd:" + q for q in names)
                  + " } ?p wdt:P154 ?l } GROUP BY ?p", cache_key="party_logos_all")
    files = {r["p"]: unquote(r["logo"].rsplit("/", 1)[-1]) for r in rows}
    q = urlencode({"action": "query", "format": "json", "prop": "imageinfo", "iiprop": "url|extmetadata",
                   "iiurlwidth": 400, "iiextmetadatafilter": "LicenseShortName|Artist",
                   "titles": "|".join("File:" + f for f in files.values())})
    info = json.loads(curl("https://commons.wikimedia.org/w/api.php?" + q))
    norm = {n["to"]: n["from"] for n in info["query"].get("normalized", [])}
    meta = {}
    for pg in info["query"]["pages"].values():
        if "imageinfo" in pg:
            meta[norm.get(pg["title"], pg["title"])[5:]] = pg["imageinfo"][0]
    os.makedirs(OUT, exist_ok=True)
    out = {}
    for qid, f in sorted(files.items()):
        ii = meta.get(f)
        name = names[qid]
        if not ii or name in out:
            continue
        em = ii.get("extmetadata", {})
        lic = em.get("LicenseShortName", {}).get("value", "")
        artist = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html.unescape(em.get("Artist", {}).get("value", "")))).strip()[:100]
        dest = os.path.join(OUT, name + ".png")
        if not os.path.exists(dest):
            subprocess.run(["curl", "-s", "-f", "-A", UA, "-o", dest, ii["thumburl"]], check=True)
        out[name] = {"path": "logos/" + name + ".png", "file": f, "license": lic, "artist": artist, "page": ii["descriptionurl"]}
        print(f"{name:<8} {lic:<16} {f}")
    save_json("app/data/logos/logos.json", out)


if __name__ == "__main__":
    main()
