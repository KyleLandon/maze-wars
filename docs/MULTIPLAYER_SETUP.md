# Multiplayer setup (2–4 player FFA)

Online **FFA queue** on a **dedicated server**: up to **4 players**, server-authoritative simulation, sends hit **all enemy lanes**.

## Daily use

| Machine | Action |
|---------|--------|
| Server PC | `tools/network/Run-Dedicated-Server.bat` |
| Players | `Play-MazeWars.bat` → **JOIN QUEUE** |

Default server address is in **`config/network.json`**. Change it and ship a new build so all clients match.

## Same-PC test (server + 2 clients)

You need **3 windows**:

1. `Run-Dedicated-Server.bat` — leave the dashboard open (**LOBBY**).
2. Client 1 → **`127.0.0.1`** → connect → **VOTE TO START**.
3. Client 2 → **`127.0.0.1`** → connect → **VOTE TO START**.

Do **not** use the public IP on the same PC — most routers block hairpin NAT. The client auto-retries `127.0.0.1` if the public IP fails.

Match **auto-starts** when **≥50%** have voted (2 players → 1 vote is enough).

## Internet play

1. On the **server PC**, run `Run-Dedicated-Server.bat` (opens Windows Firewall for UDP **7777** on first launch).
2. Port-forward **UDP 7777** on your router to the server PC’s LAN IP — see `tools/network/STATIC-SERVER-IP.md`.
3. Dashboard shows **Internet**, **LAN**, and **127.0.0.1** join addresses.
4. Remote players use the **public IP** from `config/network.json`.

Alternatives: **Tailscale / ZeroTier / Hamachi** (virtual LAN).

## Queue rules

| Setting | Value |
|--------|--------|
| Max players | 4 |
| Min to start | 2 |
| Start votes | **≥50%** of players in queue (e.g. 1/2, 2/3, 2/4) |
| Mode | FFA (1 lane per player) |
| Start | Auto when vote threshold met |

See **`docs/SERVER_ARCHITECTURE.md`** for scaling beyond one match per server.

## Controls

- Build, upgrade, sell, send — each player controls **their lane** only.
- Sends hit **every other human lane** in the match.
- **Tab** scoreboard · **Esc** pause.

## Troubleshooting

| Problem | Try |
|--------|-----|
| Stuck on Connecting | Server running? Firewall allows UDP 7777? Port-forward? Same PC → **127.0.0.1** |
| RPC / checksum errors | **Same build on all PCs** — launcher on everyone, don’t mix F5 with export |
| Can’t place towers | Same version; update to latest release |
| Match won’t start | Need min **2** players and **≥50%** votes to start |
| Server won’t start | Run from installed `MazeWars.exe`; check port 7777 is free |

## Technical notes

- **Port:** `7777` UDP (ENet)
- **Protocol:** `NET_PROTOCOL_VERSION` in `network_manager.gd` (bump when RPCs change)
- **Scenes:** `lobby.tscn`, `dedicated_server.tscn`, `match.tscn`
- **Autoload:** `NetworkManager`
