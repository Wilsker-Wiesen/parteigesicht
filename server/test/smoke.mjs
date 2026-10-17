// Rauchtest gegen `wrangler dev`: zwei Geräte betreten einen Raum, der Gastgeber startet,
// beide melden Punkte. Aufruf: npm test  (Server muss auf SERVER laufen)
import WebSocket from "ws";
const SERVER = process.env.SERVER || "ws://127.0.0.1:8787";
const ALPHA = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const CODE = Array.from({ length: 10 }, () => ALPHA[Math.floor(Math.random() * ALPHA.length)]).join(""); // frischer Raum je Lauf
const ORIGIN = "http://localhost:8766";
const open = (id, name) => new Promise((res, rej) => {
  const ws = new WebSocket(`${SERVER}/room/${CODE}`, { headers: { Origin: ORIGIN } });
  ws.last = null;
  ws.on("message", d => { const m = JSON.parse(d); if (m.t === "state") ws.last = m; });
  ws.on("open", () => { ws.send(JSON.stringify({ t: "hello", id, name })); res(ws); });
  ws.on("error", rej);
});
const sleep = ms => new Promise(r => setTimeout(r, ms));
const check = (cond, text) => { console.log((cond ? "OK   " : "FEHL ") + text); if (!cond) process.exitCode = 1; };

const a = await open("aaaaaaaa-1111", "Anna");
const b = await open("bbbbbbbb-2222", "Ben");
await sleep(300);
check(b.last?.players.length === 2, "zwei Spieler im Raum");
check(b.last?.players.find(p => p.name === "Anna")?.host === true, "Anna ist Gastgeberin");
b.send(JSON.stringify({ t: "start" }));
await sleep(200);
check(a.last?.phase === "lobby", "Ben (kein Gastgeber) kann nicht starten");
a.send(JSON.stringify({ t: "start" }));
await sleep(300);
check(b.last?.phase === "playing" && b.last.startAt > b.last.now, "Gastgeberin startet, Countdown liegt in der Zukunft");
a.send(JSON.stringify({ t: "progress", answered: 20, correct: 15, bonus: 9, totalMs: 61000, done: true }));
b.send(JSON.stringify({ t: "progress", answered: 20, correct: 15, bonus: 9, totalMs: 55000, done: true }));
await sleep(300);
const pa = a.last.players.find(p => p.name === "Anna"), pb = a.last.players.find(p => p.name === "Ben");
check(pa.points === 24 && pb.points === 24 && pb.totalMs < pa.totalMs, "Punkte und Zeiten kommen bei allen an");
b.close(); await sleep(300);
check(a.last.players.find(p => p.name === "Ben")?.online === false, "Ben als offline markiert");
const bad = new WebSocket(`${SERVER}/room/${CODE}`, { headers: { Origin: "https://example.com" } });
await new Promise(r => { bad.on("error", r); bad.on("unexpected-response", (req, res) => { check(res.statusCode === 403, "fremde Webseite wird abgewiesen"); r(); }); });
a.close();
