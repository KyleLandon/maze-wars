# Multiplayer setup (2–4 player FFA)

Online **FFA lobby** aligned with PRD MVP 3: up to **4 players**, host-authoritative simulation, sends hit **all enemy lanes**.

## Quick test (same Wi‑Fi / LAN)

### Option A — Peer host (you + friends)

1. Launch the game on both PCs (same build via launcher).
2. **(Recommended)** Run `tools/network/Open-Firewall-Port.bat` as admin on the host — opens **UDP 7777**.
3. **Host:** click **HOST LOBBY** → share your IP (e.g. `192.168.4.24:7777`).
4. **Guests:** enter host IP → **JOIN LOBBY**.
5. Everyone clicks **READY UP**.
6. **Host** clicks **START MATCH** when all players are ready (minimum **2**).

### Option B — Dedicated server on your PC

1. Run `tools/network/Run-Dedicated-Server.bat` (or `MazeWars.exe --dedicated-server`).
2. A **server dashboard** window opens (not the 3D game). It shows IP, connected players, and live match stats.
3. Players **JOIN LOBBY** with that IP from the normal game client.
4. When **all connected players are ready**, the server auto-starts the match in the background.

Use a cheap VPS the same way if you port-forward **UDP 7777** (or run on the VPS public IP).

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
| Stuck on Connecting | Correct host IP, same network, firewall allows UDP 7777 |
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
