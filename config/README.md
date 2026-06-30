# Balance config

JSON only — loaded by `BalanceConfig` (`scripts/autoload/balance_config.gd`).

| File | Contents |
|------|----------|
| `lane.json` | Grid size, `cell_size` (world units per tile) |
| `towers.json` | Tower base stats; `range` and `splash_radius` in **tiles** |
| `upgrades.json` | Per-tower level upgrades |
| `waves.json` | Creep definitions; `speed` in **tiles per second** |
| `send_packages.json` | Enemy send packs |
| `economy.json` | Starting gold, income, lane layout |
| `damage_table.json` | Damage type vs armor multipliers |

Edit values here to tune the game without changing code.
