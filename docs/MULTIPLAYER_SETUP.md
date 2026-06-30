# Multiplayer setup (2–4 player FFA)

Online **FFA lobby** aligned with PRD MVP 3: up to **4 players**, host-authoritative simulation, sends hit **all enemy lanes**.

## Same-PC test (dedicated server + 2 clients)

You need **3 windows**:

1. `Run-Dedicated-Server.bat` — leave it open (dashboard should say **LOBBY**).
2. Launch client 1 → address **`127.0.0.1`** → **JOIN QUEUE** → **JOIN QUEUE** (ready).
3. Launch client 2 → **`127.0.0.1`** → **JOIN QUEUE** → **JOIN QUEUE**.

Do **not** use the public IP on the same PC — most routers block that (no hairpin NAT). v0.2.7+ auto-retries `127.0.0.1` if the public IP fails.

Server dashboard should list both players. Match auto-starts when both are in queue.

**Without a dedicated server:** client 1 **HOST LOBBY**, client 2 joins **`127.0.0.1`**.

## Quick test (same Wi‑Fi / LAN)

### Option A — Peer host (you + friends)

1. Launch the game on both PCs (same build via launcher).
2. **(Recommended)** Run `tools/network/Open-Firewall-Port.bat` as admin on the host — opens **UDP 7777**.
3. **Host:** click **HOST LOBBY** → share your IP (e.g. `192.168.4.24:7777`).
4. **Guests:** enter host IP → **JOIN LOBBY**.
5. Everyone clicks **READY UP**.
6. **Host** clicks **START MATCH** when all players are ready (minimum **2**).

### Option B — Dedicated server (internet)

The default server address is in **`config/network.json`** (public IP for remote players).

1. On the **server PC**, run `tools/network/Run-Dedicated-Server.bat` (opens Windows Firewall for UDP **7777** on first launch).
2. Port-forward **UDP 7777** on your router to the server PC’s LAN IP — see `tools/network/STATIC-SERVER-IP.md`.
3. Dashboard shows **Internet join**, **LAN**, and **127.0.0.1** addresses.
4. Clients launch the game → **JOIN QUEUE** (public IP is pre-filled).

Change `default_server_address` in `config/network.json`, then release a new build so all clients pick it up.

## Lobby rules

| Setting | Value |
|--------|--------|
| Max players | 4 |
| Min to start | 2 |
| Mode | FFA (1 lane per player) |
| Start | Host clicks Start **or** dedicated server auto-starts when all ready |

## Controls (unchanged)

- Build, upgrade, sell, send — each player controls **their lane** only.
- Sends hit **every other human lane** in the match.
- **Tab** scoreboard · **Esc** pause.

## Playing over the internet

LAN uses direct IP. Over the internet:

1. Port-forward **UDP 7777** on the host/router to the server PC.
2. Guests join the **public IP**.

Alternatives: **Tailscale / ZeroTier / Hamachi** (virtual LAN).

## Troubleshooting

| Problem | Try |
|--------|-----|
| Stuck on Connecting | Server running? **Windows Firewall** allows UDP 7777? Router port-forward? Same Wi‑Fi → use **LAN IP** not public IP |
| RPC / checksum errors | **Same build on all PCs** — launcher on everyone, don’t mix F5 with export |
| Guest can’t place towers | Same version; update to latest release |
| Match won’t start | All players must **Ready**; need at least 2 players |
| Dedicated server won’t start | Run from installed `MazeWars.exe` or export; check port 7777 free |

## Roadmap (PRD)

- **Now:** Lobby + 2–4 player FFA + dedicated server entry
- **Next:** Balance tuning per lobby size (4 / 6 / 8 / 10)
- **Later:** Public matchmaking queue (relay + pairing)

## Technical notes

- **Port:** `7777` UDP (ENet)
- **Protocol:** `NET_PROTOCOL_VERSION` in `network_manager.gd` (bump when RPCs change)
- **Scenes:** `lobby.tscn`, `dedicated_server.tscn`, `match.tscn`
- **Autoload:** `NetworkManager`
