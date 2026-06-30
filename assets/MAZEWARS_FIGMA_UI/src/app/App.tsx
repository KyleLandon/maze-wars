import { useState } from "react";
import { Sword, Shield, Zap, Skull, Star, ChevronRight, X, Settings, Volume2, VolumeX, Heart, Coins, Trophy, Flame, Target, Lock, Play, RotateCcw } from "lucide-react";
import brandingImg from "@/imports/mazewars_branding.png";

// ─── Design tokens (pulled from brand palette) ───────────────────────────────
const C = {
  cyBright: "#00c9ff",
  cyDim: "#0078a0",
  cyGlow: "rgba(0,201,255,0.25)",
  cyGlow2: "rgba(0,201,255,0.08)",
  orange: "#ff6b35",
  orangeGlow: "rgba(255,107,53,0.3)",
  red: "#cc2936",
  gold: "#f5c842",
  bg: "#0d0e14",
  surface: "#13151f",
  surface2: "#1a1e2e",
  border: "rgba(0,201,255,0.18)",
  borderDim: "rgba(255,255,255,0.06)",
  text: "#e8eaf0",
  textMid: "#9aa3bd",
  textDim: "#4e5670",
};

// ─── Shared style helpers ─────────────────────────────────────────────────────
const panelStyle = (glow?: string): React.CSSProperties => ({
  background: C.surface,
  border: `1px solid ${glow ? glow : C.border}`,
  borderRadius: 6,
  boxShadow: glow ? `0 0 18px ${glow}, inset 0 0 30px rgba(0,0,0,0.5)` : `inset 0 0 30px rgba(0,0,0,0.5)`,
  position: "relative",
  overflow: "hidden",
});

const cornerAccent = (color = C.cyBright) => (
  <>
    <span style={{ position: "absolute", top: 0, left: 0, width: 12, height: 12, borderTop: `2px solid ${color}`, borderLeft: `2px solid ${color}` }} />
    <span style={{ position: "absolute", top: 0, right: 0, width: 12, height: 12, borderTop: `2px solid ${color}`, borderRight: `2px solid ${color}` }} />
    <span style={{ position: "absolute", bottom: 0, left: 0, width: 12, height: 12, borderBottom: `2px solid ${color}`, borderLeft: `2px solid ${color}` }} />
    <span style={{ position: "absolute", bottom: 0, right: 0, width: 12, height: 12, borderBottom: `2px solid ${color}`, borderRight: `2px solid ${color}` }} />
  </>
);

// ─── Section Label ────────────────────────────────────────────────────────────
function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
      <span style={{ flex: 1, height: 1, background: `linear-gradient(to right, ${C.border}, transparent)` }} />
      <span style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 11, fontWeight: 700, letterSpacing: "0.25em", color: C.cyDim, textTransform: "uppercase" }}>
        {children}
      </span>
      <span style={{ flex: 1, height: 1, background: `linear-gradient(to left, ${C.border}, transparent)` }} />
    </div>
  );
}

// ─── Buttons ─────────────────────────────────────────────────────────────────
type BtnVariant = "primary" | "secondary" | "danger" | "ghost" | "gold";
function GameButton({ children, variant = "primary", icon, disabled, size = "md" }: {
  children: React.ReactNode;
  variant?: BtnVariant;
  icon?: React.ReactNode;
  disabled?: boolean;
  size?: "sm" | "md" | "lg";
}) {
  const [hovered, setHovered] = useState(false);

  const configs: Record<BtnVariant, { bg: string; border: string; color: string; shadow: string; hoverBg: string }> = {
    primary: {
      bg: hovered ? "rgba(0,201,255,0.2)" : "rgba(0,201,255,0.1)",
      border: C.cyBright,
      color: C.cyBright,
      shadow: hovered ? `0 0 20px ${C.cyGlow}` : `0 0 8px ${C.cyGlow}`,
      hoverBg: "rgba(0,201,255,0.2)",
    },
    secondary: {
      bg: hovered ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.03)",
      border: "rgba(255,255,255,0.25)",
      color: C.text,
      shadow: "none",
      hoverBg: "",
    },
    danger: {
      bg: hovered ? "rgba(204,41,54,0.3)" : "rgba(204,41,54,0.15)",
      border: C.red,
      color: "#ff4455",
      shadow: hovered ? `0 0 18px rgba(204,41,54,0.5)` : `0 0 6px rgba(204,41,54,0.3)`,
      hoverBg: "",
    },
    ghost: {
      bg: "transparent",
      border: "transparent",
      color: C.textMid,
      shadow: "none",
      hoverBg: "",
    },
    gold: {
      bg: hovered ? "rgba(245,200,66,0.2)" : "rgba(245,200,66,0.1)",
      border: C.gold,
      color: C.gold,
      shadow: hovered ? `0 0 20px rgba(245,200,66,0.4)` : `0 0 8px rgba(245,200,66,0.2)`,
      hoverBg: "",
    },
  };

  const cfg = configs[variant];
  const padding = size === "sm" ? "6px 14px" : size === "lg" ? "14px 36px" : "10px 24px";
  const fontSize = size === "sm" ? 11 : size === "lg" ? 15 : 13;

  return (
    <button
      disabled={disabled}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 8,
        padding,
        background: cfg.bg,
        border: `1px solid ${cfg.border}`,
        borderRadius: 4,
        color: disabled ? C.textDim : cfg.color,
        fontSize,
        fontFamily: "Rajdhani, sans-serif",
        fontWeight: 700,
        letterSpacing: "0.12em",
        textTransform: "uppercase",
        cursor: disabled ? "not-allowed" : "pointer",
        boxShadow: disabled ? "none" : cfg.shadow,
        transition: "all 0.15s ease",
        position: "relative",
        clipPath: "polygon(6px 0%, 100% 0%, calc(100% - 6px) 100%, 0% 100%)",
        opacity: disabled ? 0.4 : 1,
      }}
    >
      {icon && <span style={{ display: "flex" }}>{icon}</span>}
      {children}
    </button>
  );
}

// ─── Resource Bar ─────────────────────────────────────────────────────────────
function ResourceBar({ label, value, max, color, icon }: {
  label: string; value: number; max: number; color: string; icon?: React.ReactNode;
}) {
  const pct = Math.min(value / max, 1);
  return (
    <div style={{ width: "100%" }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4, alignItems: "center" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          {icon && <span style={{ color, display: "flex" }}>{icon}</span>}
          <span style={{ fontFamily: "Rajdhani, sans-serif", fontWeight: 600, fontSize: 12, letterSpacing: "0.1em", color: C.textMid, textTransform: "uppercase" }}>{label}</span>
        </div>
        <span style={{ fontFamily: "Orbitron, monospace", fontSize: 11, color }}>{value}<span style={{ color: C.textDim }}>/{max}</span></span>
      </div>
      <div style={{ height: 8, background: "rgba(255,255,255,0.05)", borderRadius: 2, position: "relative", overflow: "hidden", border: `1px solid rgba(255,255,255,0.06)` }}>
        <div style={{
          height: "100%",
          width: `${pct * 100}%`,
          background: `linear-gradient(to right, ${color}99, ${color})`,
          boxShadow: `0 0 8px ${color}88`,
          transition: "width 0.4s ease",
          borderRadius: 2,
        }} />
        {[0.25, 0.5, 0.75].map(t => (
          <div key={t} style={{ position: "absolute", top: 0, left: `${t * 100}%`, width: 1, height: "100%", background: "rgba(0,0,0,0.5)" }} />
        ))}
      </div>
    </div>
  );
}

// ─── Tower Card ───────────────────────────────────────────────────────────────
function TowerCard({ name, type, tier, damage, range, cost, locked }: {
  name: string; type: string; tier: number; damage: number; range: number; cost: number; locked?: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  const colors: Record<string, string> = { archer: C.cyBright, mage: "#a855f7", cannon: C.orange, fortress: C.gold };
  const color = colors[type] ?? C.cyBright;

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        ...panelStyle(hovered && !locked ? color + "44" : undefined),
        width: 140,
        cursor: locked ? "not-allowed" : "pointer",
        transform: hovered && !locked ? "translateY(-3px)" : "translateY(0)",
        transition: "all 0.2s ease",
        filter: locked ? "brightness(0.5) saturate(0.3)" : "none",
      }}
    >
      {cornerAccent(color)}
      {/* tier pip row */}
      <div style={{ display: "flex", gap: 3, padding: "8px 10px 0", justifyContent: "flex-end" }}>
        {Array.from({ length: 3 }).map((_, i) => (
          <span key={i} style={{ width: 6, height: 6, borderRadius: 1, background: i < tier ? color : C.borderDim, boxShadow: i < tier ? `0 0 6px ${color}` : "none" }} />
        ))}
      </div>
      {/* icon area */}
      <div style={{ display: "flex", justifyContent: "center", padding: "10px 0 8px" }}>
        <div style={{ width: 60, height: 60, borderRadius: 6, background: `radial-gradient(circle at 40% 40%, ${color}22, transparent 70%)`, border: `1px solid ${color}44`, display: "flex", alignItems: "center", justifyContent: "center", position: "relative" }}>
          <div style={{ fontSize: 28, lineHeight: 1 }}>
            {type === "archer" && "🏹"}
            {type === "mage" && "🔮"}
            {type === "cannon" && "💥"}
            {type === "fortress" && "🏰"}
          </div>
          {locked && <Lock size={20} color={C.textDim} style={{ position: "absolute" }} />}
        </div>
      </div>
      {/* name */}
      <div style={{ textAlign: "center", padding: "0 8px 4px" }}>
        <div style={{ fontFamily: "Cinzel, serif", fontSize: 12, fontWeight: 700, color: C.text, letterSpacing: "0.05em" }}>{name}</div>
        <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 10, color: color, fontWeight: 600, letterSpacing: "0.15em", textTransform: "uppercase" }}>{type}</div>
      </div>
      {/* stats */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 2, padding: "6px 8px" }}>
        {[["DMG", damage], ["RNG", range]].map(([k, v]) => (
          <div key={k as string} style={{ background: "rgba(0,0,0,0.3)", borderRadius: 3, padding: "4px 6px", textAlign: "center" }}>
            <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 9, color: C.textDim, letterSpacing: "0.1em", textTransform: "uppercase" }}>{k}</div>
            <div style={{ fontFamily: "Orbitron, monospace", fontSize: 13, color: C.text, fontWeight: 700 }}>{v}</div>
          </div>
        ))}
      </div>
      {/* cost */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 4, padding: "6px 8px 10px" }}>
        <Coins size={12} color={C.gold} />
        <span style={{ fontFamily: "Orbitron, monospace", fontSize: 13, color: C.gold, fontWeight: 700 }}>{cost}</span>
      </div>
    </div>
  );
}

// ─── HUD Bar ─────────────────────────────────────────────────────────────────
function HUDBar() {
  return (
    <div style={{
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "0 20px", height: 52,
      background: "linear-gradient(to bottom, #0d1020, #0a0c18)",
      border: `1px solid ${C.border}`,
      borderRadius: 6,
      boxShadow: `0 4px 30px rgba(0,0,0,0.8), 0 0 0 1px ${C.cyGlow2}`,
    }}>
      {/* left: wave info */}
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 10, color: C.textDim, letterSpacing: "0.15em", textTransform: "uppercase" }}>Wave</div>
        <div style={{ fontFamily: "Orbitron, monospace", fontSize: 20, color: C.cyBright, fontWeight: 700, textShadow: `0 0 12px ${C.cyBright}` }}>07</div>
        <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 10, color: C.textDim }}>/ 20</div>
      </div>
      {/* center: resources */}
      <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
        {[
          { icon: <Heart size={14} color={C.red} fill={C.red} />, val: "18", label: "Lives", color: C.red },
          { icon: <Coins size={14} color={C.gold} />, val: "1,240", label: "Gold", color: C.gold },
          { icon: <Zap size={14} color={C.cyBright} />, val: "3,450", label: "Score", color: C.cyBright },
        ].map(({ icon, val, label, color }) => (
          <div key={label} style={{ display: "flex", alignItems: "center", gap: 6 }}>
            {icon}
            <div>
              <div style={{ fontFamily: "Orbitron, monospace", fontSize: 13, color, fontWeight: 700, lineHeight: 1 }}>{val}</div>
              <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 9, color: C.textDim, letterSpacing: "0.1em", textTransform: "uppercase" }}>{label}</div>
            </div>
          </div>
        ))}
      </div>
      {/* right: controls */}
      <div style={{ display: "flex", gap: 8 }}>
        <GameButton variant="secondary" size="sm" icon={<Play size={10} />}>Resume</GameButton>
        <GameButton variant="ghost" size="sm" icon={<Settings size={12} />}>{""}</GameButton>
      </div>
    </div>
  );
}

// ─── Wave Indicator ───────────────────────────────────────────────────────────
function WaveTimeline({ current = 7, total = 20 }: { current?: number; total?: number }) {
  return (
    <div style={{ ...panelStyle(), padding: "16px 20px" }}>
      {cornerAccent()}
      <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 10, color: C.textDim, letterSpacing: "0.2em", textTransform: "uppercase", marginBottom: 12 }}>Wave Progress</div>
      <div style={{ display: "flex", gap: 3, alignItems: "center", flexWrap: "wrap" }}>
        {Array.from({ length: total }).map((_, i) => {
          const done = i < current - 1;
          const active = i === current - 1;
          const boss = (i + 1) % 5 === 0;
          return (
            <div key={i} style={{
              width: boss ? 18 : 12,
              height: boss ? 18 : 12,
              borderRadius: boss ? 3 : 2,
              background: done ? (boss ? C.orange : C.cyBright + "99") : active ? C.cyBright : "rgba(255,255,255,0.04)",
              border: `1px solid ${done || active ? (boss ? C.orange : C.cyBright) : "rgba(255,255,255,0.08)"}`,
              boxShadow: active ? `0 0 8px ${C.cyBright}` : boss && done ? `0 0 6px ${C.orange}` : "none",
              transition: "all 0.2s",
            }} />
          );
        })}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 10 }}>
        <span style={{ fontFamily: "Orbitron, monospace", fontSize: 11, color: C.textDim }}>Next boss in</span>
        <span style={{ fontFamily: "Orbitron, monospace", fontSize: 13, color: C.orange, fontWeight: 700 }}>3 waves</span>
        <Flame size={12} color={C.orange} />
      </div>
    </div>
  );
}

// ─── Enemy Card ───────────────────────────────────────────────────────────────
function EnemyCard({ name, hp, maxHp, speed, reward, elite }: {
  name: string; hp: number; maxHp: number; speed: number; reward: number; elite?: boolean;
}) {
  return (
    <div style={{ ...panelStyle(elite ? C.orange + "44" : undefined), padding: "12px 14px", width: 180 }}>
      {cornerAccent(elite ? C.orange : C.cyBright)}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 8 }}>
        <div>
          <div style={{ fontFamily: "Cinzel, serif", fontSize: 13, fontWeight: 700, color: elite ? C.orange : C.text }}>{name}</div>
          {elite && <span style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 9, fontWeight: 700, letterSpacing: "0.15em", color: C.orange, textTransform: "uppercase", background: "rgba(255,107,53,0.15)", border: `1px solid ${C.orange}44`, borderRadius: 2, padding: "1px 5px" }}>Elite</span>}
        </div>
        <Skull size={16} color={elite ? C.orange : C.textDim} />
      </div>
      <ResourceBar label="HP" value={hp} max={maxHp} color={C.red} icon={<Heart size={10} />} />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6, marginTop: 10 }}>
        {[["Speed", speed, C.cyBright], ["Gold", reward, C.gold]].map(([label, val, color]) => (
          <div key={label as string} style={{ background: "rgba(0,0,0,0.3)", borderRadius: 3, padding: "4px 8px" }}>
            <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 9, color: C.textDim, letterSpacing: "0.1em", textTransform: "uppercase" }}>{label}</div>
            <div style={{ fontFamily: "Orbitron, monospace", fontSize: 12, color: color as string, fontWeight: 700 }}>{val}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Notification Toast ───────────────────────────────────────────────────────
function Toast({ message, type = "info" }: { message: string; type?: "info" | "warn" | "success" | "danger" }) {
  const configs = {
    info: { color: C.cyBright, icon: <Zap size={14} /> },
    warn: { color: C.orange, icon: <Flame size={14} /> },
    success: { color: "#22c55e", icon: <Star size={14} /> },
    danger: { color: C.red, icon: <Skull size={14} /> },
  };
  const cfg = configs[type];
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 10,
      padding: "10px 14px",
      background: `linear-gradient(to right, ${cfg.color}18, ${C.surface})`,
      border: `1px solid ${cfg.color}44`,
      borderLeft: `3px solid ${cfg.color}`,
      borderRadius: 4,
      boxShadow: `0 4px 20px rgba(0,0,0,0.5)`,
      minWidth: 240,
    }}>
      <span style={{ color: cfg.color }}>{cfg.icon}</span>
      <span style={{ fontFamily: "Rajdhani, sans-serif", fontWeight: 600, fontSize: 13, color: C.text }}>{message}</span>
    </div>
  );
}

// ─── Modal ────────────────────────────────────────────────────────────────────
function GameModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  if (!open) return null;
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.75)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 50, backdropFilter: "blur(4px)" }}>
      <div style={{ ...panelStyle(C.cyGlow), padding: "28px 32px", maxWidth: 380, width: "100%", position: "relative" }}>
        {cornerAccent()}
        <button onClick={onClose} style={{ position: "absolute", top: 12, right: 12, background: "transparent", border: "none", cursor: "pointer", color: C.textDim }}>
          <X size={16} />
        </button>
        <div style={{ textAlign: "center", marginBottom: 20 }}>
          <div style={{ fontFamily: "Cinzel, serif", fontSize: 22, fontWeight: 900, color: C.text, letterSpacing: "0.1em", textTransform: "uppercase", textShadow: `0 0 30px ${C.cyBright}44` }}>Wave Complete</div>
          <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 13, color: C.textMid, marginTop: 4 }}>All enemies defeated</div>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10, marginBottom: 20 }}>
          {[{ label: "Score", val: "+850", color: C.cyBright }, { label: "Gold", val: "+120", color: C.gold }, { label: "Lives", val: "+2", color: C.red }].map(({ label, val, color }) => (
            <div key={label} style={{ textAlign: "center", background: "rgba(0,0,0,0.3)", borderRadius: 4, padding: "10px 8px", border: `1px solid ${color}22` }}>
              <div style={{ fontFamily: "Orbitron, monospace", fontSize: 18, color, fontWeight: 700 }}>{val}</div>
              <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 10, color: C.textDim, letterSpacing: "0.1em", textTransform: "uppercase" }}>{label}</div>
            </div>
          ))}
        </div>
        <div style={{ display: "flex", gap: 10, justifyContent: "center" }}>
          <GameButton variant="secondary" icon={<RotateCcw size={12} />}>Retry</GameButton>
          <GameButton variant="primary" size="md" icon={<ChevronRight size={14} />}>Next Wave</GameButton>
        </div>
      </div>
    </div>
  );
}

// ─── Settings Panel ───────────────────────────────────────────────────────────
function SettingsPanel() {
  const [sfx, setSfx] = useState(75);
  const [music, setMusic] = useState(50);
  const [muted, setMuted] = useState(false);

  return (
    <div style={{ ...panelStyle(), padding: "20px 24px", width: 280 }}>
      {cornerAccent()}
      <div style={{ fontFamily: "Cinzel, serif", fontSize: 14, fontWeight: 700, color: C.text, letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 18, display: "flex", alignItems: "center", gap: 8 }}>
        <Settings size={14} color={C.cyBright} /> Settings
      </div>
      {[{ label: "SFX Volume", val: sfx, set: setSfx }, { label: "Music Volume", val: music, set: setMusic }].map(({ label, val, set }) => (
        <div key={label} style={{ marginBottom: 16 }}>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
            <span style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 12, fontWeight: 600, letterSpacing: "0.08em", color: C.textMid, textTransform: "uppercase" }}>{label}</span>
            <span style={{ fontFamily: "Orbitron, monospace", fontSize: 11, color: C.cyBright }}>{val}%</span>
          </div>
          <input
            type="range" min={0} max={100} value={val}
            onChange={(e) => set(Number(e.target.value))}
            style={{ width: "100%", accentColor: C.cyBright, cursor: "pointer" }}
          />
        </div>
      ))}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "10px 0", borderTop: `1px solid ${C.borderDim}` }}>
        <span style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 12, fontWeight: 600, letterSpacing: "0.08em", color: C.textMid, textTransform: "uppercase" }}>Mute All</span>
        <button onClick={() => setMuted(m => !m)} style={{ background: "transparent", border: "none", cursor: "pointer", color: muted ? C.red : C.textDim }}>
          {muted ? <VolumeX size={18} /> : <Volume2 size={18} />}
        </button>
      </div>
    </div>
  );
}

// ─── Leaderboard Row ──────────────────────────────────────────────────────────
function LeaderboardRow({ rank, name, score, highlight }: { rank: number; name: string; score: string; highlight?: boolean }) {
  const rankColor = rank === 1 ? C.gold : rank === 2 ? "#a0aec0" : rank === 3 ? "#cd7f32" : C.textDim;
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 14,
      padding: "9px 14px",
      background: highlight ? `linear-gradient(to right, ${C.cyBright}12, transparent)` : "transparent",
      borderRadius: 4,
      borderLeft: highlight ? `2px solid ${C.cyBright}` : "2px solid transparent",
    }}>
      <span style={{ fontFamily: "Orbitron, monospace", fontSize: 13, color: rankColor, fontWeight: 700, width: 20, textAlign: "center" }}>
        {rank <= 3 ? ["🥇", "🥈", "🥉"][rank - 1] : rank}
      </span>
      <span style={{ fontFamily: "Rajdhani, sans-serif", fontWeight: 600, fontSize: 14, color: highlight ? C.text : C.textMid, flex: 1 }}>{name}</span>
      <span style={{ fontFamily: "Orbitron, monospace", fontSize: 12, color: highlight ? C.cyBright : C.textDim }}>{score}</span>
    </div>
  );
}

// ─── Main App ─────────────────────────────────────────────────────────────────
export default function App() {
  const [modalOpen, setModalOpen] = useState(false);

  return (
    <div style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "Rajdhani, sans-serif", overflowX: "hidden" }}>
      {/* subtle hex grid background */}
      <div style={{
        position: "fixed", inset: 0, zIndex: 0, opacity: 0.035, pointerEvents: "none",
        backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='60' height='52' viewBox='0 0 60 52'%3E%3Cpolygon points='30,2 58,17 58,35 30,50 2,35 2,17' fill='none' stroke='%2300c9ff' stroke-width='1'/%3E%3C/svg%3E")`,
        backgroundSize: "60px 52px",
      }} />

      <div style={{ position: "relative", zIndex: 1, maxWidth: 1100, margin: "0 auto", padding: "40px 24px" }}>

        {/* ── Header ── */}
        <div style={{ textAlign: "center", marginBottom: 48 }}>
          <div style={{ fontFamily: "Cinzel, serif", fontSize: 36, fontWeight: 900, letterSpacing: "0.2em", textTransform: "uppercase", color: C.text, textShadow: `0 0 40px ${C.cyBright}55, 0 0 80px ${C.cyBright}22` }}>
            MAZE WARS
          </div>
          <div style={{ fontFamily: "Rajdhani, sans-serif", fontSize: 13, letterSpacing: "0.35em", color: C.cyBright, textTransform: "uppercase", marginTop: 4 }}>
            UI Component Library
          </div>
          <div style={{ width: 120, height: 1, background: `linear-gradient(to right, transparent, ${C.cyBright}, transparent)`, margin: "12px auto 0" }} />
        </div>

        {/* ── HUD Bar ── */}
        <SectionLabel>HUD Bar</SectionLabel>
        <div style={{ marginBottom: 40 }}>
          <HUDBar />
        </div>

        {/* ── Buttons ── */}
        <SectionLabel>Buttons</SectionLabel>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 12, alignItems: "center", marginBottom: 40 }}>
          <GameButton variant="primary" size="lg" icon={<Play size={14} />}>Start Battle</GameButton>
          <GameButton variant="primary" icon={<Sword size={13} />}>Deploy Tower</GameButton>
          <GameButton variant="gold" icon={<Star size={13} />}>Upgrade</GameButton>
          <GameButton variant="secondary" icon={<Shield size={13} />}>Defend</GameButton>
          <GameButton variant="danger" icon={<Skull size={13} />}>Forfeit</GameButton>
          <GameButton variant="ghost" icon={<Settings size={13} />}>Settings</GameButton>
          <GameButton variant="primary" size="sm">Small</GameButton>
          <GameButton variant="primary" disabled icon={<Lock size={12} />}>Locked</GameButton>
        </div>

        {/* ── Resource Bars ── */}
        <SectionLabel>Resource Bars</SectionLabel>
        <div style={{ ...panelStyle(), padding: "20px 24px", marginBottom: 40, maxWidth: 500 }}>
          {cornerAccent()}
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <ResourceBar label="Health" value={75} max={100} color={C.red} icon={<Heart size={12} />} />
            <ResourceBar label="Mana" value={60} max={100} color="#8b5cf6" icon={<Zap size={12} />} />
            <ResourceBar label="Shield" value={40} max={100} color={C.cyBright} icon={<Shield size={12} />} />
            <ResourceBar label="XP" value={88} max={100} color={C.gold} icon={<Star size={12} />} />
          </div>
        </div>

        {/* ── Tower Cards ── */}
        <SectionLabel>Tower Cards</SectionLabel>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 16, marginBottom: 40 }}>
          <TowerCard name="Sentinel" type="archer" tier={2} damage={45} range={8} cost={120} />
          <TowerCard name="Arcane Spire" type="mage" tier={3} damage={90} range={6} cost={280} />
          <TowerCard name="Iron Bastion" type="cannon" tier={1} damage={130} range={4} cost={200} />
          <TowerCard name="High Keep" type="fortress" tier={3} damage={60} range={10} cost={450} />
          <TowerCard name="Shadow Gate" type="mage" tier={1} damage={55} range={7} cost={160} locked />
        </div>

        {/* ── Wave + Enemy ── */}
        <SectionLabel>Wave & Enemy Info</SectionLabel>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 20, marginBottom: 40, alignItems: "flex-start" }}>
          <WaveTimeline current={7} total={20} />
          <EnemyCard name="Ironclad Brute" hp={320} maxHp={400} speed={2} reward={18} />
          <EnemyCard name="Vortex Wraith" hp={150} maxHp={150} speed={6} reward={30} elite />
        </div>

        {/* ── Notifications ── */}
        <SectionLabel>Notifications</SectionLabel>
        <div style={{ display: "flex", flexDirection: "column", gap: 8, marginBottom: 40, maxWidth: 320 }}>
          <Toast message="Wave 8 incoming — prepare defenses!" type="warn" />
          <Toast message="Tower upgraded to Tier 3" type="success" />
          <Toast message="Enemy reached the gate!" type="danger" />
          <Toast message="New tower unlocked: Arcane Spire" type="info" />
        </div>

        {/* ── Settings + Leaderboard ── */}
        <SectionLabel>Settings & Leaderboard</SectionLabel>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 24, marginBottom: 40, alignItems: "flex-start" }}>
          <SettingsPanel />
          <div style={{ ...panelStyle(), padding: "20px 0", flex: 1, minWidth: 240 }}>
            {cornerAccent()}
            <div style={{ padding: "0 14px 14px", fontFamily: "Cinzel, serif", fontSize: 14, fontWeight: 700, letterSpacing: "0.1em", textTransform: "uppercase", display: "flex", alignItems: "center", gap: 8 }}>
              <Trophy size={14} color={C.gold} /> Leaderboard
            </div>
            <div style={{ borderTop: `1px solid ${C.borderDim}` }} />
            {[
              { rank: 1, name: "ShadowMancer", score: "48,320" },
              { rank: 2, name: "IronVeil", score: "41,200" },
              { rank: 3, name: "CryptWarden", score: "38,750" },
              { rank: 4, name: "You", score: "33,450", highlight: true },
              { rank: 5, name: "VoidStalker", score: "29,100" },
            ].map(row => <LeaderboardRow key={row.rank} {...row} />)}
          </div>
        </div>

        {/* ── Modal trigger ── */}
        <SectionLabel>Modal</SectionLabel>
        <div style={{ marginBottom: 60 }}>
          <GameButton variant="primary" icon={<Target size={13} />} onClick={() => setModalOpen(true)}>
            Preview Wave Complete Modal
          </GameButton>
        </div>

        <GameModal open={modalOpen} onClose={() => setModalOpen(false)} />
      </div>
    </div>
  );
}
