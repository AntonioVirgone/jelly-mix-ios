// JellyMix screens
// All screens live here. Game logic + interactions inlined.

const { useState, useEffect, useRef, useMemo } = React;

// ─────────────────────────────────────────────────────────────
// Shared UI bits
// ─────────────────────────────────────────────────────────────

function HeartRow({ lives = 5, theme }) {
  return (
    <div style={{
      display: 'inline-flex', gap: 6,
      padding: '8px 18px',
      borderRadius: 999,
      background: theme.surface,
      border: `1px solid ${theme.surfaceBorder}`,
      backdropFilter: 'blur(12px)',
      WebkitBackdropFilter: 'blur(12px)',
      boxShadow: '0 4px 16px rgba(0,0,0,0.06)',
    }}>
      {[0,1,2,3,4].map(i => (
        <svg key={i} width="18" height="16" viewBox="0 0 18 16" style={{
          filter: i < lives ? 'drop-shadow(0 1px 0 rgba(0,0,0,0.1))' : 'grayscale(80%) opacity(0.35)',
        }}>
          <path d="M9 14.5s-7-4.2-7-9A4 4 0 0 1 9 3a4 4 0 0 1 7 2.5c0 4.8-7 9-7 9z" fill={theme.heart} />
        </svg>
      ))}
    </div>
  );
}

function Coin({ size = 18 }) {
  const gid = 'coin-' + size;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24">
      <defs>
        <radialGradient id={gid} cx="35%" cy="30%" r="80%">
          <stop offset="0%" stopColor="#fff7a0" />
          <stop offset="50%" stopColor="#ffc83a" />
          <stop offset="100%" stopColor="#b87900" />
        </radialGradient>
      </defs>
      <circle cx="12" cy="12" r="11" fill={`url(#${gid})`} stroke="#8a5200" strokeWidth="0.8" />
      <text x="12" y="16.5" textAnchor="middle" fontSize="12" fontWeight="900" fill="#8a5200" fontFamily="Fredoka, sans-serif">$</text>
    </svg>
  );
}

function CoinPill({ coins, theme, big = false }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: big ? '8px 14px 8px 16px' : '6px 10px 6px 14px',
      borderRadius: 999,
      background: theme.dark ? 'rgba(255,255,255,0.1)' : 'linear-gradient(135deg, #ffd76b, #ffae3a)',
      color: theme.dark ? theme.text : '#7a4a00',
      fontWeight: 700,
      fontSize: big ? 20 : 16,
      boxShadow: theme.dark ? '0 2px 8px rgba(0,0,0,0.2)' : '0 2px 8px rgba(255,170,0,0.3)',
      border: theme.dark ? `1px solid ${theme.surfaceBorder}` : 'none',
    }}>
      <span>{coins}</span>
      <Coin size={big ? 22 : 18} />
    </div>
  );
}

function Pill({ children, theme, style, gradient }) {
  return (
    <div style={{
      padding: '12px 22px',
      borderRadius: 999,
      background: gradient || theme.surface,
      color: gradient ? '#fff' : theme.text,
      fontWeight: 600,
      fontSize: 16,
      textAlign: 'center',
      boxShadow: gradient ? '0 6px 18px rgba(80,40,180,0.25)' : '0 2px 10px rgba(0,0,0,0.05)',
      border: gradient ? 'none' : `1px solid ${theme.surfaceBorder}`,
      ...style,
    }}>{children}</div>
  );
}

function Confetti({ count = 30 }) {
  const colors = ['#ff4d57','#3d8cff','#3dcb5e','#ffd23a','#a35bff','#ff5fb8'];
  const pieces = useMemo(() => Array.from({length: count}).map((_,i) => ({
    left: Math.random() * 100,
    delay: Math.random() * 0.4,
    color: colors[i % colors.length],
    rot: Math.random() * 360,
    size: 6 + Math.random() * 8,
    dur: 1.5 + Math.random() * 1.2,
  })), [count]);
  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', overflow: 'hidden', zIndex: 100 }}>
      {pieces.map((p, i) => (
        <div key={i} style={{
          position: 'absolute', top: -20, left: `${p.left}%`,
          width: p.size, height: p.size * 0.6,
          background: p.color, transform: `rotate(${p.rot}deg)`,
          animation: `confettiFall ${p.dur}s ${p.delay}s ease-in forwards`,
          borderRadius: 2,
        }} />
      ))}
    </div>
  );
}

function shade(hex, percent) {
  const num = parseInt(hex.slice(1), 16);
  let r = (num >> 16) + percent * 2.5;
  let g = ((num >> 8) & 0xff) + percent * 2.5;
  let b = (num & 0xff) + percent * 2.5;
  r = Math.max(0, Math.min(255, r));
  g = Math.max(0, Math.min(255, g));
  b = Math.max(0, Math.min(255, b));
  return '#' + ((1<<24) + (r<<16) + (g<<8) + b | 0).toString(16).slice(1);
}

Object.assign(window, { HeartRow, CoinPill, Coin, Pill, Confetti, shade });
