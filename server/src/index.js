// Live-Räume für gemeinsame Runden von Parteigesicht.
//
// Jeder Spielcode (10 Zeichen) ist ein eigener Raum (Durable Object). Die Geräte verbinden
// sich per WebSocket mit /room/<CODE>. Der Raum kennt die Mitspielenden, startet die Runde
// für alle zur selben Zeit und führt die Live-Rangliste. Welche Gesichter drankommen,
// rechnet jedes Gerät weiterhin selbst aus dem Code aus; der Server sieht nur Punkte.
//
// Gespeichert werden nur der gewählte Spielname und die Punkte, und nur bis der Raum
// sechs Stunden lang unbenutzt war.

const CODE_RE = /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{10}$/;
const MAX_PLAYERS = 16;
const COUNTDOWN_MS = 4000;
const CLEANUP_AFTER_MS = 6 * 60 * 60 * 1000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("Parteigesicht-Räume laufen.", { headers: { "content-type": "text/plain; charset=utf-8" } });
    }
    const m = /^\/room\/([A-Z0-9]+)$/.exec(url.pathname);
    if (!m || !CODE_RE.test(m[1])) return new Response("Unbekannter Raum", { status: 404 });
    if (request.headers.get("Upgrade") !== "websocket") return new Response("WebSocket erwartet", { status: 426 });
    const origin = request.headers.get("Origin") || "";
    const allowed = (env.ALLOWED_ORIGINS || "").split(",").map(s => s.trim()).filter(Boolean);
    if (allowed.length && !allowed.includes(origin)) {
      return new Response("Nicht erlaubt", { status: 403 });
    }
    const stub = env.ROOMS.get(env.ROOMS.idFromName(m[1]));
    return stub.fetch(request);
  },
};

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.state = null; // { phase, startAt, players: { [id]: {...} }, order: [id] }
  }

  async load() {
    if (!this.state) {
      this.state = (await this.ctx.storage.get("state")) || { phase: "lobby", startAt: 0, round: 0, players: {}, order: [] };
    }
    return this.state;
  }

  async save() {
    await this.ctx.storage.put("state", this.state);
    await this.ctx.storage.setAlarm(Date.now() + CLEANUP_AFTER_MS);
  }

  async fetch(request) {
    const pair = new WebSocketPair();
    this.ctx.acceptWebSocket(pair[1]);
    pair[1].serializeAttachment({ id: null });
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  online(closing = null) {
    const ids = new Set();
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === closing) continue;
      const a = ws.deserializeAttachment();
      if (a && a.id) ids.add(a.id);
    }
    return ids;
  }

  snapshot(closing = null) {
    const on = this.online(closing);
    const s = this.state;
    const host = this.hostId(closing);
    const players = s.order.map(id => {
      const p = s.players[id];
      return { ...p, online: on.has(id), host: id === host, points: p.correct + p.bonus };
    });
    return { t: "state", phase: s.phase, startAt: s.startAt, round: s.round || 0, now: Date.now(), players };
  }

  broadcast(closing = null) {
    const msg = JSON.stringify(this.snapshot(closing));
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === closing) continue;
      try { ws.send(msg); } catch {}
    }
  }

  hostId(closing = null) {
    // Gastgeber ist, wer zuerst im Raum war und noch verbunden ist
    const on = this.online(closing);
    return this.state.order.find(id => on.has(id)) || this.state.order[0];
  }

  async webSocketMessage(ws, raw) {
    if (typeof raw !== "string" || raw.length > 1000) return;
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    const s = await this.load();
    const me = ws.deserializeAttachment() || {};

    if (msg.t === "hello") {
      const id = String(msg.id || "").slice(0, 40);
      const name = String(msg.name || "").replace(/[\u0000-\u001f]/g, "").trim().slice(0, 20) || "Gast";
      if (!/^[a-z0-9-]{8,40}$/i.test(id)) return;
      if (!s.players[id] && s.order.length >= MAX_PLAYERS) {
        ws.send(JSON.stringify({ t: "error", message: `Dieser Raum ist voll (höchstens ${MAX_PLAYERS} Geräte).` }));
        return;
      }
      if (!s.players[id]) {
        s.players[id] = { id, name, answered: 0, correct: 0, bonus: 0, totalMs: 0, done: false };
        s.order.push(id);
      } else {
        s.players[id].name = name;
      }
      ws.serializeAttachment({ id });
      await this.save();
      ws.send(JSON.stringify({ t: "welcome", id }));
      this.broadcast();
      return;
    }

    const id = me.id;
    if (!id || !s.players[id]) return;
    const p = s.players[id];

    if (msg.t === "start") {
      if (id !== this.hostId()) return;
      s.phase = "playing";
      s.startAt = Date.now() + COUNTDOWN_MS;
      s.round = (s.round || 0) + 1; // jede Runde im selben Raum bekommt andere Gesichter
      for (const pid of s.order) Object.assign(s.players[pid], { answered: 0, correct: 0, bonus: 0, totalMs: 0, done: false });
      await this.save();
      this.broadcast();
      return;
    }

    if (msg.t === "progress") {
      // Stand nach jeder Antwort: absolute Werte, damit verlorene Nachrichten nichts verfälschen
      const n = v => Math.max(0, Math.min(1e7, Math.floor(Number(v) || 0)));
      p.answered = Math.min(100, n(msg.answered));
      p.correct = Math.min(p.answered, n(msg.correct));
      p.bonus = Math.min(p.correct, n(msg.bonus));
      p.totalMs = n(msg.totalMs);
      p.done = !!msg.done;
      await this.save();
      this.broadcast();
      return;
    }

    if (msg.t === "lobby") {
      // Gastgeber holt alle zurück in den Warteraum (z. B. vor einer neuen Runde)
      if (id !== this.hostId()) return;
      s.phase = "lobby"; s.startAt = 0;
      await this.save();
      this.broadcast();
    }
  }

  async webSocketClose(ws, code) {
    await this.load();
    try { ws.close(code === 1005 ? 1000 : code); } catch {}
    this.broadcast(ws);
  }

  async webSocketError(ws) {
    await this.load();
    this.broadcast(ws);
  }

  async alarm() {
    // Raum lange unbenutzt: alles löschen
    if (this.ctx.getWebSockets().length) {
      await this.ctx.storage.setAlarm(Date.now() + CLEANUP_AFTER_MS);
      return;
    }
    await this.ctx.storage.deleteAll();
    this.state = null;
  }
}
