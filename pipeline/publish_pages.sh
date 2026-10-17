#!/bin/sh
# Veröffentlicht die Web-App (app/) auf GitHub Pages: https://wilsker-wiesen.github.io/parteigesicht/
# Die fertige Seite liegt im Zweig gh-pages; GitHub Pages liefert ihn direkt aus.
#   sh pipeline/publish_pages.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SITE=$(mktemp -d)
trap 'git -C "$ROOT" worktree remove --force "$SITE" 2>/dev/null || rm -rf "$SITE"' EXIT

cd "$ROOT"
git fetch -q origin gh-pages 2>/dev/null || true
if git show-ref -q --verify refs/remotes/origin/gh-pages; then
  git worktree add -q -B gh-pages "$SITE" origin/gh-pages
else
  git worktree add -q --detach "$SITE" && git -C "$SITE" checkout -q --orphan gh-pages && git -C "$SITE" rm -rq . 2>/dev/null || true
fi

# Inhalt ersetzen: app/index.html ist ohne Dokumentrahmen geschrieben (für Claude-Artifacts)
find "$SITE" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R app/data app/favicon.png app/apple-touch-icon.png "$SITE/"
{ printf '<!doctype html>\n<html lang="de">\n'; cat app/index.html; printf '\n</html>\n'; } > "$SITE/index.html"
touch "$SITE/.nojekyll"

cd "$SITE"
git add -A
if git diff --cached --quiet; then echo "Keine Änderungen an der Web-App."; exit 0; fi
git commit -q -m "Web-App aktualisiert ($(git -C "$ROOT" rev-parse --short HEAD))"
git push -q origin gh-pages
echo "Veröffentlicht: https://wilsker-wiesen.github.io/parteigesicht/"
