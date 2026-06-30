# Multiplayer setup (2-player LAN)

Early **2-player LAN** support for testing. The host runs the authoritative simulation; the other player connects and controls their own lane.

## Quick test (same Wi‑Fi / LAN)

### Host (you)

1. Launch the game.
2. **(Recommended)** Run `tools/network/Open-Firewall-Port.bat` as admin once — opens **UDP 7777**.
3. Click **HOST LAN GAME**.
4. Read the status line — it shows **your IP** (e.g. `192.168.1.42:7777`). Text or Discord that IP to your guest.
5. Wait for “Guest connected” — the match starts automatically.

**You must host first**, then she joins.

### Guest (your girlfriend)

1. Launch the game (same build as host).
2. Type the **host’s IP** in the box.
   - **Same PC test (two windows):** use `127.0.0.1`
   - **Two PCs on Wi‑Fi:** use the host’s `192.168.x.x` IP (not your own)
3. Click **JOIN LAN GAME**.
4. Should change to “Connected” then load the match within a few seconds.

If it says **Connecting** for more than ~20 seconds, the PCs are not reaching each other (wrong IP, firewall, or not on same network).

## Controls (unchanged)

- Build towers, upgrade, sell, send creeps — each player only controls **their lane**.
- Sends hit the **opponent’s lane** (no AI in 2-player mode).
- **Tab** scoreboard, **Esc** pause menu.

## Playing over the internet (not same LAN)

LAN uses a direct IP connection. Over the internet you typically need one of:

1. **Port forwarding** on the host router: forward **UDP 7777** to the host PC’s LAN IP.
2. Host gives their **public IP** (search “what is my ip”) to the guest.
3. Guest enters that public IP and joins.

Alternatives if port forwarding is awkward:

- **Hamachi / ZeroTier / Tailscale** — virtual LAN; guest joins the host’s virtual IP.
- **Steam Remote Play Together** — shares one screen; not true 2-keyboard multiplayer.

## Troubleshooting

| Problem | Try |
|--------|-----|
| Stuck on “Hosting” / “Connecting” | Host runs firewall script; guest uses host’s `192.168.x.x` IP; host clicks **HOST** before guest joins |
| Join times out | Confirm host IP, same Wi‑Fi, firewall allows UDP 7777 |
| RPC / checksum errors in console | **Same build on both PCs** — do not mix Godot F5 with launcher; run `Play-MazeWars.bat` on both, or F5 on both |
| Guest can’t place towers | Same build on both; guest joins `127.0.0.1` for same-PC test |
| Creeps look stuttery on guest | Expected to improve in v0.1.4+ (smoothed movement); host view is always smoothest |
| Host disconnected | Guest returns to main menu automatically |
| Only one player | Solo mode uses **SOLO VS AI** instead |

## Technical notes

- **Port:** `7777` (UDP, ENet)
- **Players:** 2 max (host + 1 guest)
- **Authority:** host simulates combat, economy, waves; client sends build/upgrade/sell/send requests via RPC
- **Autoload:** `NetworkManager` (`scripts/network/network_manager.gd`)

This is an **MVP** for playtesting — not production netcode (no relay server, reconnection, or lobby browser yet).
