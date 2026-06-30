# Server architecture & scale roadmap

## Where we are today (v0.3.x)

| Piece | Implementation |
|-------|----------------|
| Lobby | One Godot process, ENet UDP **7777**, up to **4** players per queue |
| Match sim | Full **3D scene** in the same process (`/root/Match`, hidden on server) |
| Authority | Server simulates lanes, towers, creeps; clients mirror via RPC |
| Start rule | **≥50%** of queued players vote to start (min **2** players) |

**Hard limit:** one match per dedicated-server process. This is fine for friends/testing, not for thousands of concurrent players.

---

## Why the current server cannot scale to thousands

1. **One match per process** — each game loads lanes, towers, creep AI, wave coordinator, and physics-style movement.
2. **Godot as game host** — even headless, a full `match.tscn` per game is heavy compared to a thin simulation service.
3. **Single ENet listener** — one UDP port, one lobby, one match at a time.
4. **RPC + scene paths** — Godot multiplayer is built for small P2P/dedicated sessions, not datacenter fleet orchestration.
5. **No matchmaking** — clients connect to a fixed IP; no queue pairing, regions, or skill buckets.

Rough order of magnitude for **current** stack: **1 match, 2–4 players** per server instance.

---

## Target: thousands concurrent

Assume **4-player FFA** → **~250–500 active matches** for 1,000–2,000 players (not all in-match at once).

You need **separation of concerns**:

```
                    ┌─────────────────┐
   Clients ────────►│  API / Lobby    │  auth, queue, vote, version, regions
                    └────────┬────────┘
                             │ assign match_id + connect token
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        Match worker   Match worker   Match worker  …
        (headless)     (headless)     (headless)
```

### Recommended phases

#### Phase 1 — Now (shipping fixes)
- [x] Dedicated server only (no peer host)
- [x] Creep spawn RPCs from match root (not dashboard scene)
- [x] Majority vote to start (≥50%)
- [ ] Stress-test one match with 4 clients; profile server CPU/RAM

#### Phase 2 — Multi-match on one machine (10–50 concurrent matches)
- **Lobby service** (lightweight): HTTP/WebSocket or separate Godot lobby-only binary
  - Player joins queue, votes, gets `match_endpoint` when start threshold met
- **Match worker pool**: spawn **N headless Godot** processes (or one process per match via `--match-id`)
  - Strip UI, cameras, VFX from server build export preset
  - Dynamic port per match **or** relay through lobby
- **Process supervisor**: systemd / Docker / k8s restarts crashed workers

#### Phase 3 — Regional scale (hundreds–thousands of players)
- **Matchmaking service** (Nakama, custom Rust/Go, or Agones + game servers)
  - Accounts, parties, MMR later, region selection
- **Authoritative sim outside Godot** (optional but best for cost)
  - Grid + path + tower logic in a fast server language
  - Godot clients become **thin** — only render + input
- **State sync**: snapshot + delta (not per-creep reliable RPC) at 10–20 Hz
- **Redis/Postgres** for lobby state, match records, leaderboards

#### Phase 4 — Production ops
- CDN for builds, regional deploys, DDoS on lobby API (not game UDP directly)
- Metrics: matches/min, player-minutes, worker CPU, disconnect rate
- Auto-scale workers on queue depth

---

## Technology options (honest tradeoffs)

| Approach | Pros | Cons |
|----------|------|------|
| **Keep Godot headless workers** | Reuse `match.gd` sim, fastest path to multi-match | RAM per process, harder to hit 500+ matches/box |
| **Nakama + Godot** | Battle-tested lobby/matchmaker, hooks | Learning curve, hosting cost |
| **Custom Go/Rust sim** | Cheapest per match at scale | Rewrite sim logic; longest build time |
| **Photon / Edgegap** | Managed infra | Monthly cost, less control |

**Pragmatic path for Maze Wars:** Phase 2 with **one headless Godot match per process** + a **thin lobby coordinator** (can still be Godot or a small web service). Revisit custom sim when you have metrics showing Godot workers are the bottleneck.

---

## Client changes already aligned with scale

- **Vote to start (≥50%)** — works with partial lobbies; same rule can live on a future lobby API.
- **Dedicated server only** — clients never host; they only `join_game(address)`.
- **`config/network.json`** — default server address; later becomes region gateway URL.

---

## Next engineering tasks (suggested priority)

1. **Verify creep sync** on clients after spawn-path fix (v0.3.1).
2. **Dedicated server export preset** — `Dedicated Server` template: no UI assets, no audio, `--headless` CI build.
3. **Spawner script** — `Run-Match-Worker.bat --port=7778 --match-id=...` for local multi-match dev.
4. **Lobby coordinator prototype** — HTTP `POST /queue/join`, WebSocket for vote updates.
5. **Load test** — 4 bots in one match; then 4 matches × 4 bots on one PC.

---

## Vote-to-start rule (implemented)

- Each player toggles **VOTE TO START** in the queue UI.
- Match begins when:
  - `players >= MIN_PLAYERS_TO_START` (2), and
  - `votes >= ceil(players × 0.5)` (≥50%).

Examples: 2 players → 1 vote; 3 players → 2 votes; 4 players → 2 votes.
