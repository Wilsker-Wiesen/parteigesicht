"""Kleine Helfer für Wikidata-SPARQL und die Commons-API.

Alle HTTP-Aufrufe laufen über curl, damit es keine Abhängigkeit von Pythons
Zertifikatsspeicher gibt. Antworten werden in data/cache/ zwischengespeichert,
damit Läufe reproduzierbar und schonend für die Wikimedia-Server sind.
"""
import hashlib, json, os, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "data", "cache")
UA = "Parteigesicht/0.2 (https://github.com/Wilsker-Wiesen/parteigesicht)"


def curl(url, data=None, accept="application/json", retries=5):
    cmd = ["curl", "-s", "-f", "-g", "--compressed", "-A", UA, "-H", f"Accept: {accept}", url]
    if data is not None:
        cmd[1:1] = ["--data-urlencode", data]
    for attempt in range(retries):
        r = subprocess.run(cmd, capture_output=True)
        if r.returncode == 0:
            return r.stdout
        time.sleep(3 * (attempt + 1))
    raise RuntimeError(f"Abruf fehlgeschlagen: {url}")


def sparql(query, cache_key=None, max_age_h=72):
    """Führt eine SPARQL-Abfrage aus und gibt die Bindings als Liste von dicts zurück."""
    key = cache_key or hashlib.sha1(query.encode()).hexdigest()[:16]
    path = os.path.join(CACHE, "sparql", key + ".json")
    if os.path.exists(path) and time.time() - os.path.getmtime(path) < max_age_h * 3600:
        raw = json.load(open(path))
    else:
        raw = json.loads(curl("https://query.wikidata.org/sparql", data="query=" + query,
                              accept="application/sparql-results+json"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        json.dump(raw, open(path, "w"))
    rows = []
    for b in raw["results"]["bindings"]:
        rows.append({k: v["value"].rsplit("/", 1)[-1] if v["value"].startswith("http://www.wikidata.org/entity/") else v["value"]
                     for k, v in b.items()})
    return rows


def load_json(rel):
    return json.load(open(os.path.join(ROOT, rel), encoding="utf-8"))


def save_json(rel, obj, pretty=True):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1 if pretty else None,
                  separators=None if pretty else (",", ":"))
