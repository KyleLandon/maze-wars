# Static server IP for dedicated server + clients

## 1. Set your PC to a fixed LAN IP (Windows)

Do this on the machine that runs `Run-Dedicated-Server.bat`.

1. Open **Settings → Network & Internet → Wi‑Fi** (or Ethernet) → your connection → **Hardware properties** or **Edit IP assignment**.
2. Set **Manual** IPv4:
   - **IP address:** `192.168.4.24` (must match `config/network.json`)
   - **Subnet mask:** usually `255.255.255.0`
   - **Gateway:** your router (e.g. `192.168.4.1`)
   - **DNS:** router or `1.1.1.1`
3. Run `Open-Firewall-Port.bat` as admin (UDP **7777**).

Alternatively, reserve this MAC address in your router’s DHCP settings so it always gets `192.168.4.24`.

## 2. Configure the game (already in repo)

Edit `config/network.json`:

```json
{
  "default_server_address": "192.168.4.24",
  "server_port": 7777,
  "server_display_name": "Maze Wars Server"
}
```

- **Dedicated server** dashboard shows: `Players join: 192.168.4.24:7777`
- **Clients** see that address pre-filled — click **JOIN QUEUE** (no typing).

Ship a new build after changing this file so everyone gets the same address.

## 3. Per-PC override (optional)

Without rebuilding, a player can create:

`%APPDATA%\Godot\app_userdata\Maze Wars\network.json`

```json
{
  "default_server_address": "192.168.4.24"
}
```

## 4. Daily use

| Machine | Action |
|---------|--------|
| Server PC | `Run-Dedicated-Server.bat` |
| Clients | `Play-MazeWars.bat` → **JOIN QUEUE** |

Same Wi‑Fi required. For internet play, port-forward UDP **7777** and use your public IP in `network.json` instead.
