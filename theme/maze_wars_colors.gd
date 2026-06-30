extends RefCounted
class_name MazeWarsColors

## Color & style constants from Figma UI kit.

# ── Backgrounds ───────────────────────────────────────────────────────────────
const BG         := Color("#0d0e14")       # page / viewport background
const SURFACE    := Color("#13151f")       # card / panel surface
const SURFACE2   := Color("#1a1e2e")       # elevated surface / input bg
const SURFACE3   := Color("#21263a")       # hover state on surface

# ── Accents ───────────────────────────────────────────────────────────────────
const CYAN       := Color("#00c9ff")       # primary teal/cyan (Blue Tec)
const CYAN_DIM   := Color("#0078a0")       # dimmed cyan for borders
const CYAN_GLOW  := Color(0.0, 0.788, 1.0, 0.25)
const ORANGE     := Color("#ff6b35")       # Ember Orange (warnings, bosses)
const ORANGE_GLOW:= Color(1.0, 0.42, 0.2, 0.3)
const GOLD       := Color("#f5c842")       # upgrade / coin color
const RED        := Color("#cc2936")       # health / danger
const PURPLE     := Color("#a855f7")       # mage towers

# ── Text ──────────────────────────────────────────────────────────────────────
const TEXT       := Color("#e8eaf0")       # primary label text
const TEXT_MID   := Color("#9aa3bd")       # secondary / subheading
const TEXT_DIM   := Color("#4e5670")       # disabled / placeholder

# ── Borders ───────────────────────────────────────────────────────────────────
const BORDER     := Color(0.0, 0.788, 1.0, 0.18)   # default panel border
const BORDER_DIM := Color(1.0, 1.0, 1.0, 0.06)     # subtle divider

# ── Semantic shortcuts ────────────────────────────────────────────────────────
const HP         := RED
const MANA       := PURPLE
const SHIELD     := CYAN
const XP         := GOLD
const COIN       := GOLD
const BOSS       := ORANGE
