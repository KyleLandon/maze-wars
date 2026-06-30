# Multiplayer setup (2-player LAN)

Early **2-player LAN** support for testing. The host runs the authoritative simulation; the other player connects and controls their own lane.

## Quick test (same Wi‑Fi / LAN)

### Host (you)

1. Launch the game (`run_game.bat` or Play in Godot).
2. Click **HOST LAN GAME**.
3. Note your PC’s LAN IP (Windows: `ipconfig` → IPv4, e.g. `192.168.1.42`).
4. Allow **UDP port 7777** through Windows Firewall when prompted (or add a rule manually).
5. Wait for “Player connected” — the match starts automatically.

### Guest (your girlfriend)

1. Launch the game on her PC (same build/version).
2. Enter the **host IP** in the address field.
3. Click **JOIN LAN GAME**.
4. The match loads when the host detects the connection.

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
| Join times out | Confirm host IP, same game build, firewall allows UDP 7777 |
| Guest sees desynced creeps | Expected in early build; host is authoritative — report severe desync |
| Host disconnected | Guest returns to main menu automatically |
| Only one player | Solo mode uses **SOLO VS AI** instead |

## Technical notes

- **Port:** `7777` (UDP, ENet)
- **Players:** 2 max (host + 1 guest)
- **Authority:** host simulates combat, economy, waves; client sends build/upgrade/sell/send requests via RPC
- **Autoload:** `NetworkManager` (`scripts/network/network_manager.gd`)

This is an **MVP** for playtesting — not production netcode (no relay server, reconnection, or lobby browser yet).
