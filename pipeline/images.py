"""Schritt 4: Lizenzangaben und Fotos von Wikimedia Commons laden.

1. Für jede Datei: Urheber, Lizenz, Link zur Dateiseite (Commons-API, 50 Dateien je Abruf)
   -> data/commons.json
2. Vorschaubild in 500 px Breite (eine Standardgröße von Commons, die zwischengespeichert
   ist) -> data/cache/raw/<QID>.jpg   (nicht im Git-Repository)

Danach: pipeline/portrait (Zuschnitt + Hintergrund-Weichzeichnung).

    python3 pipeline/images.py
"""
import json, os, re, subprocess, sys, time, html
from urllib.parse import urlencode
sys.path.insert(0, os.path.dirname(__file__))
from wd import curl, load_json, save_json, ROOT, UA

FREE = re.compile(r"^(CC0|CC BY(-SA)? ?[\d.]*( \w+)?|Public domain|PD.*|GFDL.*|Attribution.*|FAL|Free Art License|European Parliament|Copyrighted free use)", re.I)
RAW = os.path.join(ROOT, "data", "cache", "raw")
WIDTH = 500


def strip(s):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html.unescape(s or ""))).strip()


def fetch_meta(files):
    path = os.path.join(ROOT, "data", "commons.json")
    meta = load_json("data/commons.json") if os.path.exists(path) else {}
    todo = [f for f in files if f not in meta]
    for i in range(0, len(todo), 50):
        part = todo[i:i + 50]
        q = urlencode({"action": "query", "format": "json", "prop": "imageinfo", "iiprop": "url|extmetadata|size",
                       "iiurlwidth": WIDTH, "iiextmetadatafilter": "Artist|LicenseShortName|Credit",
                       "titles": "|".join("File:" + f for f in part)})
        r = json.loads(curl("https://commons.wikimedia.org/w/api.php?" + q))
        norm = {n["to"]: n["from"] for n in r["query"].get("normalized", [])}
        for pg in r["query"]["pages"].values():
            title = norm.get(pg["title"], pg["title"])[5:]
            if "imageinfo" not in pg:
                meta[title] = {"missing": True}
                continue
            ii = pg["imageinfo"][0]; em = ii.get("extmetadata", {})
            meta[title] = {
                "thumb": ii.get("thumburl"), "page": ii["descriptionurl"],
                "w": ii.get("width"), "h": ii.get("height"),
                "artist": strip(em.get("Artist", {}).get("value"))[:120],
                "license": em.get("LicenseShortName", {}).get("value", ""),
            }
        if i % 1000 == 0:
            print(f"  Lizenzen {i}/{len(todo)}", flush=True)
            save_json("data/commons.json", meta)
        time.sleep(0.2)
    save_json("data/commons.json", meta)
    return meta


def _get(job):
    q, url = job
    dest = os.path.join(RAW, q + ".jpg")
    r = subprocess.run(["curl", "-s", "-f", "-A", UA, "-o", dest + ".part", url])
    if r.returncode == 0:
        os.replace(dest + ".part", dest)
        time.sleep(0.15)
        return True
    time.sleep(4)  # vermutlich gedrosselt (HTTP 429): Verbindung bremst sich selbst
    return False


def download(jobs):
    """Lädt Bilder mit 3 parallelen Verbindungen; Fehlschläge kommen in die nächste Runde."""
    from concurrent.futures import ThreadPoolExecutor
    os.makedirs(RAW, exist_ok=True)
    for rnd in range(6):
        pending = [j for j in jobs if not os.path.exists(os.path.join(RAW, j[0] + ".jpg"))]
        if not pending:
            break
        print(f"  Download-Runde {rnd + 1}: {len(pending)} Bilder offen", flush=True)
        with ThreadPoolExecutor(3) as ex:
            for i, _ in enumerate(ex.map(_get, pending)):
                if i % 500 == 499:
                    print(f"    {i + 1}/{len(pending)}", flush=True)
        time.sleep(20)
    return [j for j in jobs if not os.path.exists(os.path.join(RAW, j[0] + ".jpg"))]


def main():
    faces = load_json("data/faces.json")["people"]
    meta = fetch_meta(sorted({p["image"] for p in faces}))
    jobs, nonfree = [], 0
    for p in faces:
        m = meta.get(p["image"], {})
        if not m.get("thumb"):
            continue
        if not FREE.match(m.get("license", "")):
            nonfree += 1
            continue
        jobs.append((p["id"], m["thumb"]))
    print(f"{len(jobs)} Bilder mit freier Lizenz, {nonfree} mit unklarer Lizenz übersprungen")
    left = download(jobs)
    print(f"Fertig. Nicht geladen: {len(left)}")


if __name__ == "__main__":
    main()
