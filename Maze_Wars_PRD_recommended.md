# PRD.md — Maze Wars

## 0. Document Status

**Status:** Revised PRD  
**Project:** Maze Wars  
**Genre:** Competitive multiplayer tower defense / lane wars  
**Engine:** Godot 4.7, 3D-first, Forward Plus, Jolt Physics  
**Primary Development Tool:** Cursor  
**Current Prototype:** Single-lane 3D greybox MVP in `maze-wars/`

This version tightens the product scope around the fastest playable path: prove that mazing, tower combat, leaks, economy, and send pressure are fun before investing deeply in online multiplayer, ranked systems, heroes, or final art.

---

## 1. Product Vision

Maze Wars is a competitive multiplayer tower defense game inspired by Warcraft III custom maps like Line Tower Wars and Hero Line Wars.

Players build tower mazes in their own lane, defend against natural waves, buy creep send packages that pressure all enemy lanes, grow their recurring income, and try to outlast the lobby.

The core fantasy:

> Build the smartest maze, greed your economy, survive the pressure, and be the last player or duo alive.

---

## 2. Core Design Pillars

### 2.1 Maze Mastery

The player should feel clever when tower placement creates longer, more efficient creep paths. Maze design should be the main skill expression, not just tower spam.

### 2.2 Greed vs Survival

Every major spend should create tension:

- Build or upgrade towers to survive now.
- Buy send packages to increase future income.
- Risk leaking if the player greeds too hard.

### 2.3 Send-to-All Pressure

Creep sends affect every active enemy lane by default. This keeps the game lobby-wide instead of turning it into a direct 1v1 harassment system.

### 2.4 Readable Chaos

Late-game should become intense, but not confusing. Players must understand:

- What leaked.
- Why it leaked.
- What damage type or tower gap caused the leak.
- Whether they lost because of greed, poor mazing, poor tower mix, or send timing.

### 2.5 Fast Replayability

A good match should end with players wanting to queue again immediately. The game should support quick learning, clear mistakes, and satisfying comebacks.

---

## 3. Target Modes

Maze Wars should support two main match formats.

### 3.1 Free For All

**Primary mode.**

- 4–10 players.
- 1 player per lane.
- Each player has their own core, gold, income, towers, builder, and send queue.
- Last active player wins.

Example:

| Lobby Size | Lanes | Players Per Lane |
|---:|---:|---:|
| 4 | 4 | 1 |
| 6 | 6 | 1 |
| 8 | 8 | 1 |
| 10 | 10 | 1 |

### 3.2 Duos

**Secondary mode after FFA works.**

- 4–10 players.
- 2 players per lane.
- 2–5 duo teams.
- Teammates share one lane and one core.
- Each teammate keeps individual gold, income, tower ownership, stats, and send queue.

Example:

| Lobby Size | Teams | Lanes | Players Per Lane |
|---:|---:|---:|---:|
| 4 | 2 | 2 | 2 |
| 6 | 3 | 3 | 2 |
| 8 | 4 | 4 | 2 |
| 10 | 5 | 5 | 2 |

### 3.3 Recommended Mode Priority

Do not build all modes at once.

1. Single-lane solo prototype.
2. Local multi-lane FFA simulation.
3. Online 4-player FFA.
4. Online 8–10 player FFA.
5. Duos.
6. Ranked and long-term progression.

---

## 4. Core Gameplay Loop

1. Match starts.
2. Each player receives a builder, starting gold, starting income, and a core.
3. Players place towers on a grid to create a valid maze.
4. Natural creeps spawn from the north and path south toward the core.
5. Towers attack creeps automatically.
6. Killed creeps grant gold.
7. Players receive recurring income on a timer.
8. Players spend gold on towers, upgrades, or send packages.
9. Send packages increase future income.
10. Queued sends release on a global send timer.
11. Sends spawn in all active enemy lanes.
12. Leaked creeps damage the core.
13. Players or teams are eliminated at 0 core health.
14. Last surviving player or team wins.

---

## 5. MVP Scope Decisions

### 5.1 MVP 1 — Single-Lane 3D Maze Prototype

**Goal:** Prove that tower placement, path validation, creep movement, and combat are fun and readable.

**Already implemented according to the current PRD:**

- Single lane.
- 16 × 26 grid.
- North-to-south creep flow.
- Builder movement.
- 3D grid tower placement.
- Path validation.
- Placement ghost.
- Path preview.
- Natural waves.
- Projectile tower attacks.
- Creeps with HP bars.
- Floating damage numbers.
- Core damage from leaks.
- Gold rewards.
- 4 towers: Arrow, Cannon, Frost, Magic.

**MVP 1 should be considered complete only when these are added:**

- Tower upgrade level 2–3 for all implemented towers.
- Tower sell.
- Income timer.
- Recurring income tick.
- 3–4 send packages in a local test harness.
- Simple post-match / defeat summary.
- Basic debug balance panel.

### 5.2 MVP 2 — Local Multi-Lane FFA Simulation

**Goal:** Prove the Line Tower Wars loop before networking.

Features:

- 4 lanes.
- Local simulated opponents.
- Send-to-all packages.
- Income timer.
- Send release timer.
- 6 towers.
- 6 send packages.
- 10 natural waves.
- Eliminations.
- Last lane alive wins.

### 5.3 MVP 3 — Online FFA Prototype

**Goal:** Prove multiplayer architecture.

Features:

- 4-player FFA.
- Server-authoritative tower placement.
- Server-authoritative economy.
- Networked sends.
- Networked core health.
- Eliminations.
- Match result screen.

### 5.4 MVP 4 — Duos

**Goal:** Prove shared-lane team play.

Features:

- 2 players per lane.
- Shared core.
- Individual economies.
- Individual tower ownership.
- Shared build space.
- Teammate HUD.

### 5.5 Deferred Until After Core Fun Is Proven

These should remain out of early MVP scope:

- Ranked matchmaking.
- Account progression.
- Cosmetics.
- Heroes.
- Final art.
- Large-scale lobby browser.
- Advanced replay system.
- Complex branching tower upgrades.

---

## 6. Lane and Maze System

### 6.1 Coordinate Convention

Maze Wars uses a 3D lane but 2D grid logic.

| Grid Axis | World Axis | Meaning |
|---|---|---|
| Grid X | World X | East-west width |
| Grid Y | World Z | North-south pathing direction |

- Spawn is at the north center of the lane.
- Exit/core is at the south center of the lane.
- Creeps move north → south.
- Creep waypoints are converted from grid coordinates into `Vector3`.
- Gameplay is 3D-first; do not create duplicate 2D gameplay systems.

### 6.2 Placement Rules

A tower placement is valid only if:

- The target cell is buildable.
- The target cell is empty.
- The cell is not spawn, exit, protected path, or reserved space.
- A valid path still exists from spawn to exit.
- The placement does not trap creeps.
- The placement does not block builders or future required movement.
- The placement passes server validation in multiplayer.

### 6.3 Path Validation

Use `AStarGrid2D` for grid logic and output 3D waypoints through `PathManager`.

Placement flow:

1. Player hovers a grid cell.
2. Client previews the placement.
3. Grid temporarily marks the cell as blocked.
4. PathManager checks spawn-to-exit path.
5. Client displays green or red placement feedback.
6. On click, server validates the same placement.
7. If valid, tower is placed and gold is spent.
8. If invalid, placement is denied and a reason is shown.

### 6.4 Anti-Abuse Rules

Prevent:

- Full path blocking.
- Sell/rebuild abuse during active creep movement.
- Rapid path recalculation spam.
- Trapping creeps between towers.
- Placing towers directly under active creeps if it causes path confusion.

Recommended MVP rule:

> Selling or placing towers should trigger a path recalculation, but creeps should keep following their current valid path until the next safe repath point unless the current path becomes impossible.

---

## 7. Tower System

### 7.1 Tower Requirements

Each tower definition should include:

- ID.
- Display name.
- Cost.
- Sell value.
- Upgrade levels.
- Damage.
- Attack speed.
- Range.
- Damage type.
- Targeting rule.
- Projectile definition.
- Build footprint.
- Special effect.
- Hotkey.
- Visual identifier.
- Audio/VFX hooks.

### 7.2 MVP Tower Set

MVP should use 6 towers, not 8. This keeps balance work manageable.

| Tower | Role | Status |
|---|---|---|
| Arrow | Cheap single-target physical | Implemented |
| Cannon | Slow splash siege | Implemented |
| Frost | Low-damage slow/control | Implemented |
| Magic | Heavy-armor counter | Implemented |
| Poison | High-health DoT counter | Next recommended |
| Sniper | Long-range boss killer | Next recommended |

Defer Support and Anti-Boss until tower upgrade logic is proven.

### 7.3 Upgrade Model

Use simple linear upgrades first.

Recommended MVP:

- Level 1.
- Level 2.
- Level 3.

Do not start with 5 levels. Three levels are enough to test pacing, gold sinks, and UI without creating unnecessary balance complexity.

Future tower trees can branch later after the base game is fun.

---

## 8. Damage and Armor System

### 8.1 Damage Types

MVP damage types:

- Physical.
- Magic.
- Siege.
- Poison.
- Pure.

### 8.2 Armor Types

MVP armor types:

- Light.
- Medium.
- Heavy.
- Fortified.
- Boss.

### 8.3 Design Rule

The damage table should create soft counters, not hard counters.

Bad outcome:

> A player instantly loses because they built the wrong tower type.

Good outcome:

> A player survives poorly or inefficiently because their tower mix is weak against the current wave.

### 8.4 Recommended Readability

The UI should show armor and damage weakness clearly:

- Wave preview includes armor type.
- Tower tooltip explains strong/weak matchups.
- Floating damage numbers can show reduced or bonus damage.
- Post-leak summary shows the main leaked creep armor type.

---

## 9. Creep System

### 9.1 Creep Requirements

Each creep should include:

- ID.
- Display name.
- Health.
- Armor type.
- Movement speed.
- Core damage.
- Gold bounty.
- Spawn source.
- Special traits.
- Visual model.
- HP bar.
- Damage number support.
- Audio/VFX hooks.

### 9.2 Creep Sources

Creeps come from:

1. Natural waves.
2. Player send packages.
3. Boss or special waves.

### 9.3 MVP Creep Archetypes

Use a small set first:

| Creep Type | Purpose |
|---|---|
| Grunt | Baseline creep |
| Runner | Tests maze length and slows |
| Brute | Tests single-target DPS |
| Swarm | Tests splash |
| Armored | Tests damage type mix |
| Boss | Tests focused damage |

---

## 10. Send Package System

### 10.1 Default Send Model

Sends are purchased by one player and released into every active enemy lane.

In FFA:

- Sender does not receive their own sends.
- Eliminated players are removed from send targets.

In Duos:

- Sender's team does not receive their own sends.
- All other active team lanes receive the package.

### 10.2 Send Timing

Recommended MVP timing:

| Timer | Value |
|---|---:|
| Income tick | 10 seconds |
| Send release | 30 seconds |
| Natural wave interval | 45–60 seconds |

### 10.3 Send Queue Flow

1. Player buys a send package.
2. Gold is spent immediately.
3. Income gain is applied immediately.
4. Package enters the player's send queue.
5. On the next global release, packages spawn in all enemy lanes.
6. Queue clears after release.

### 10.4 Send Package Scaling Warning

Because one purchase affects every enemy lane, package balance must account for lobby size.

Recommended formula for early testing:

> Package pressure should scale down slightly as enemy target count increases.

For example, a send package in a 10-player FFA should not simply be 9× as valuable as the same package in a 4-player FFA.

Possible solutions:

- Fixed package per enemy, but higher cost in larger lobbies.
- Same cost, but fewer units per enemy in larger lobbies.
- Income gain tuned by lobby size.
- Separate balance tables for 4-player, 6-player, 8-player, and 10-player FFA.

### 10.5 MVP Send Packages

Start with 6 packages.

| Package | Cost | Income Gain | Contents | Purpose |
|---|---:|---:|---|---|
| Rat Pack | 25 | +1 | 4 weak rats | Early income |
| Wolf Pack | 60 | +2 | 3 fast wolves | Punishes short maze |
| Brute Pack | 140 | +5 | 2 brutes | Punishes low DPS |
| Swarm Pack | 180 | +6 | 10 weak units | Punishes poor splash |
| Shield Pack | 320 | +10 | 3 armored creeps | Punishes physical-only builds |
| Siege Pack | 550 | +18 | 1 siege beast | Late pressure |

Defer Shaman and Wraith until buff/debuff systems are stable.

---

## 11. Economy System

### 11.1 Resources

MVP resources:

- Gold.
- Income.

### 11.2 Gold Sources

Gold comes from:

- Starting gold.
- Creep kills.
- Income ticks.
- Wave rewards, if enabled.

### 11.3 Gold Sinks

Gold is spent on:

- Tower placement.
- Tower upgrades.
- Send packages.

### 11.4 MVP Values

Initial test values:

| Value | Starting Point |
|---|---:|
| Starting gold | 100 |
| Starting income | 10 |
| Income tick | 10 seconds |
| Starting core health | 100 |

### 11.5 Economy Success Criteria

The economy works when players repeatedly ask:

> Can I afford to send one more time, or will I leak if I do?

---

## 12. Wave System

### 12.1 MVP Wave Count

Reduce MVP wave count from 20 to 10 for faster testing.

Recommended MVP 2 wave plan:

- 10 waves.
- Boss waves at 5 and 10.
- Endless scaling only after multiplayer is fun.

### 12.2 Wave Types

MVP wave types:

- Normal.
- Fast.
- Swarm.
- Tank.
- Armored.
- Boss.

### 12.3 Wave Preview

Before a wave starts, show:

- Wave number.
- Creep type.
- Armor type.
- Expected threat.
- Countdown.

---

## 13. Builder System

Each player controls one builder.

### 13.1 Builder Rules

- Builders do not fight in MVP.
- Builders cannot block creep paths.
- Builders are used for tower placement, upgrade, and sell.
- Builders should have clear movement feedback.
- In duos, each teammate has their own builder.

### 13.2 Tower Ownership

Tower ownership remains individual.

Rules:

- Players can sell only their own towers.
- Players can upgrade only their own towers.
- Duo teammates can build in the same lane but cannot delete each other's towers.

This avoids griefing and keeps responsibility clear.

---

## 14. User Interface

### 14.1 Required In-Match HUD

MVP HUD should show:

- Gold.
- Income.
- Income timer.
- Send timer.
- Current wave.
- Next wave preview.
- Core health.
- Tower build menu.
- Selected tower info.
- Send menu.
- Incoming send warning.
- Leak messages.

### 14.2 Tower UI

Selecting a tower should show:

- Name.
- Level.
- Damage.
- Attack speed.
- Range.
- Damage type.
- Targeting mode.
- Upgrade cost.
- Sell value.
- Owner.
- Special effects.

### 14.3 Send UI

The send menu should show:

- Package name.
- Cost.
- Income gain.
- Unlock wave/time.
- Creep contents.
- Queued sends.
- Next release timer.

### 14.4 Post-Match Summary

Even in early MVP, show a simple summary:

- Match duration.
- Final wave.
- Total leaks.
- Gold earned.
- Gold spent on towers.
- Gold spent on sends.
- Final income.
- Highest damage tower.
- Main leaked creep type.

---

## 15. Technical Direction

### 15.1 Architecture

Use modular 3D-first systems.

Current script/scene structure should remain close to:

| Layer | Scripts / Scenes |
|---|---|
| Match | `scripts/match/match.gd`, `scenes/match/match.tscn` |
| Camera | `scripts/match/camera_rig.gd` |
| Lane | `scripts/systems/build_grid.gd` |
| Pathing | `scripts/systems/path_manager.gd`, `path_preview.gd`, `placement_preview.gd` |
| Combat | `scripts/entities/tower.gd`, `projectile.gd`, `creep.gd` |
| Managers | `tower_manager.gd`, `creep_spawner.gd`, `wave_manager.gd`, `economy_manager.gd` |
| Entities | `builder.gd`, `core.gd` |
| UI / VFX | `scripts/ui/hud.gd`, `health_bar.gd`, `scripts/vfx/floating_damage_number.gd` |
| Core Utils | `scripts/core/lane_coords.gd`, `scripts/systems/lane_grid.gd`, `scripts/util/data_loader.gd` |

### 15.2 Autoloads

Recommended autoloads:

- `BrandColors`.
- `BalanceConfig`.
- `GameConfig`.
- `DamageNumbers`.

### 15.3 Data-Driven Config

Current and recommended config files:

| File | Purpose |
|---|---|
| `config/lane.json` | Lane dimensions and coordinate settings |
| `config/towers.json` | Tower definitions and damage table |
| `config/waves.json` | Creep definitions and natural waves |
| `config/economy.json` | Starting gold, income, core HP, income timing |
| `config/send_packages.json` | Recommended separate file for sends |
| `config/upgrades.json` | Recommended separate file for tower upgrades |

Recommendation:

> Split send packages out of `economy.json` before MVP 2. Sends are central enough to deserve their own file.

### 15.4 Server Authority

For online play, the server must own:

- Tower placement validation.
- Gold and income.
- Send purchases.
- Send release timing.
- Wave spawning.
- Creep health.
- Creep pathing.
- Damage calculations.
- Core health.
- Eliminations.
- Match result.

Clients should send commands. They should not decide final outcomes.

### 15.5 Networking Risk

A 10-player match with many creeps can become network-heavy.

Early mitigation:

- Prototype with 4-player FFA first.
- Keep server authoritative.
- Replicate important state only.
- Do not replicate cosmetic VFX.
- Batch creep updates where possible.
- Use client-side interpolation.
- Stress test creep counts before adding ranked.

---

## 16. Art Direction

### 16.1 MVP Art

MVP uses greybox primitives and clear colors.

Prioritize:

- Readable towers.
- Readable creeps.
- Clear damage numbers.
- Clear path preview.
- Clear placement feedback.
- Smooth camera controls.

### 16.2 Final Art Direction

Recommended final direction:

- Stylized fantasy.
- WC3-inspired readability.
- Low-poly or mid-poly.
- Strong silhouettes.
- Bright readable creep/tower categories.
- Performance-friendly assets.
- Branded dark sci-fantasy UI.

---

## 17. Roadmap

### Phase 1 — Current Foundation

- [x] Godot 4.7 project setup.
- [x] Camera controls.
- [x] 3D lane grid.
- [x] Mouse tile selection.
- [x] Builder movement.
- [x] Tower placement.
- [x] Path validation.
- [x] Creep pathing.
- [x] Projectile combat.
- [x] HP bars.
- [x] Floating damage numbers.
- [x] Core damage.

### Phase 2 — Complete MVP 1

- [ ] Tower sell.
- [ ] Tower upgrades, levels 1–3.
- [ ] Income timer.
- [ ] Recurring income.
- [ ] Basic send packages in test mode.
- [ ] Post-match summary.
- [ ] Debug balance controls.

### Phase 3 — Local FFA Simulation

- [ ] Multiple local lanes.
- [ ] Player state per lane.
- [ ] Send-to-all release.
- [ ] Eliminations.
- [ ] Placement tracking.
- [ ] Local match result screen.

### Phase 4 — Online FFA

- [ ] Lobby.
- [ ] Player assignment.
- [ ] Server-authoritative commands.
- [ ] Networked economy.
- [ ] Networked sends.
- [ ] Disconnect handling.
- [ ] 4-player FFA test.

### Phase 5 — Duos

- [ ] Shared lane.
- [ ] Two builders per lane.
- [ ] Shared core.
- [ ] Individual economies.
- [ ] Teammate HUD.
- [ ] Team stats.

### Phase 6 — Competitive Foundation

- [ ] Accounts.
- [ ] Match history.
- [ ] Placement-based rating.
- [ ] Leaderboards.
- [ ] Ranked FFA.
- [ ] Ranked Duos.

---

## 18. Cursor Build Prompt

Use this updated Cursor prompt for the next development pass:

```text
We are building Maze Wars, a Godot 4.7 3D-first competitive tower defense / lane wars prototype inspired by Warcraft III Line Tower Wars.

Current state:
- Single-lane 3D greybox prototype exists in maze-wars/.
- Gameplay runs on the XZ plane.
- Creeps spawn north and move south toward the core.
- BuildGrid and PathManager handle grid state and path validation.
- Towers, projectiles, creeps, HP bars, floating damage numbers, core damage, and basic waves already exist.
- Current implemented towers: Arrow, Cannon, Frost, Magic.

Next goal:
Complete MVP 1 before moving to multiplayer.

Implement in this order:
1. Tower sell.
2. Tower upgrades, levels 1–3.
3. Income timer and recurring income tick.
4. Separate send package config file.
5. Basic send queue with 3–4 test packages.
6. Local send release test that spawns sends into the current lane for solo testing.
7. Simple post-match summary panel.
8. Debug balance controls for gold, income, wave start, send release, and spawn test.

Rules:
- Keep gameplay 3D-first. Do not create parallel 2D gameplay systems.
- Use LaneCoords for all grid-to-world and world-to-grid conversion.
- Use AStarGrid2D only for logical pathfinding.
- PathManager should emit Vector3 waypoints.
- Keep balance data in config/*.json.
- Keep systems modular for future multi-lane FFA, duos, and server-authoritative multiplayer.
- Avoid ranked, heroes, final art, cosmetics, or account systems until the core loop is fun.
```

---

## 19. Major Design Risks

### 19.1 Send-to-All Balance

Risk:

Send-to-all may become too punishing in large lobbies or too weak in small lobbies.

Mitigation:

- Test 4-player FFA first.
- Add lobby-size balance modifiers.
- Track leak rate after send releases.
- Tune income gain separately from creep pressure.

### 19.2 Network Load

Risk:

Many creeps across 10 lanes may be expensive to simulate and replicate.

Mitigation:

- Build local 4-lane simulation before online.
- Stress test creep counts.
- Replicate only necessary state.
- Avoid syncing cosmetic-only effects.

### 19.3 Duo Griefing

Risk:

Shared build spaces can let one teammate ruin the lane.

Mitigation:

- Individual tower ownership.
- No teammate selling by default.
- Optional teammate build permissions later.
- Pings and warnings for coordination.

### 19.4 Maze Abuse

Risk:

Players may exploit building and selling to confuse creep pathing.

Mitigation:

- Server-side placement validation.
- Sell cooldowns during active waves if needed.
- Safe repath windows.
- No full path blocking.

### 19.5 Scope Creep

Risk:

Heroes, ranked, cosmetics, and final art could delay finding the fun.

Mitigation:

- Finish MVP 1 and MVP 2 first.
- Treat heroes and ranked as post-core-loop systems.
- Keep the early test ugly but playable.

---

## 20. Open Questions

These are not blockers for MVP 1.

1. Should players be able to view enemy lanes freely?
2. Should sends increase income immediately or on the next income tick?
3. Should defenders see exact incoming sends or only threat level?
4. Should ranked FFA require a fixed lobby size?
5. Should duos allow teammates to upgrade each other's towers?
6. Should tower placement during active waves have stricter rules?
7. Should sudden death be boss-based, income-based, or send-based?
8. Should natural waves remain a major threat late game, or should player sends dominate?

---

## 21. Locked Decisions

- Game name: Maze Wars.
- Core inspiration: Line Tower Wars and Hero Line Wars.
- Main modes: FFA and Duos.
- FFA: 1 player per lane.
- Duos: 2 players per shared lane.
- 10-player FFA: 10 lanes.
- 10-player Duos: 5 lanes.
- Tower mazing is core.
- Towers are grid-placed.
- Tower placement must preserve a valid creep path.
- Creeps spawn north and exit south.
- Gameplay uses a 3D lane with 2D grid logic.
- No parallel 2D gameplay implementation.
- Sends use send-to-all enemy lanes by default.
- Sends are packages.
- Sending increases income.
- Duo teammates share lane and core.
- Duo economy is individual by default.
- Duo tower ownership is individual.
- Heroes are future scope, not MVP 1.
- Ranked is future scope, not MVP 1.
- Current camera is north-up and readable, not a WC3 diagonal orbit.

---

## 22. Success Criteria

Maze Wars is on the right track if:

- Building mazes feels satisfying.
- Path validation is reliable.
- Creeps move clearly from north to south.
- Tower attacks are readable.
- Leaks feel fair.
- Players understand why they leaked.
- Gold/income/send decisions feel tense.
- Send packages create meaningful pressure.
- FFA placement feels competitive.
- Players want another match immediately after losing.
