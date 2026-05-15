// Splash + Map screens

const WORLDS = [
  { id:1, name:'Mondo Fragoloso', sub:'MONDO 1', color:'#ff5567', emoji:'🍓', levels:12, unlocked:true },
  { id:2, name:'Scontri tra Agrumi', sub:'MONDO 2', color:'#ffc83a', emoji:'🍋', levels:12, unlocked:true },
  { id:3, name:'Foresta Gommosa', sub:'MONDO 3', color:'#3dcb5e', emoji:'🌳', levels:12, unlocked:false },
];

function SplashScreen({ theme, font, onReady }) {
  const [phase, setPhase] = React.useState(0);
  React.useEffect(() => {
    const t1 = setTimeout(() => setPhase(1), 350);
    const t2 = setTimeout(() => setPhase(2), 1600);
    const t3 = setTimeout(() => onReady(), 2600);
    return () => { clearTimeout(t1); clearTimeout(t2); clearTimeout(t3); };
  }, []);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: theme.bg,
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      gap: 28, overflow: 'hidden',
    }}>
      {/* Floating jellies background */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        {[
          {c:'pink', x:'10%', y:'14%', s:46, d:0},
          {c:'yellow', x:'80%', y:'10%', s:40, d:0.4},
          {c:'blue', x:'6%', y:'72%', s:54, d:0.8},
          {c:'orange', x:'78%', y:'78%', s:48, d:1.2},
          {c:'green', x:'85%', y:'48%', s:36, d:0.6},
          {c:'purple', x:'8%', y:'44%', s:38, d:1.0},
        ].map((j, i) => (
          <div key={i} style={{
            position: 'absolute', left: j.x, top: j.y,
            animation: `float ${3 + i*0.3}s ${j.d}s ease-in-out infinite`,
            opacity: phase >= 1 ? 1 : 0,
            transition: 'opacity 0.6s ease',
          }}>
            <JellyBlob color={j.c} size={j.s} shape="blob" bob />
          </div>
        ))}
      </div>

      {/* Center stack */}
      <div style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 22,
        opacity: phase >= 1 ? 1 : 0,
        transform: phase >= 1 ? 'scale(1)' : 'scale(0.85)',
        transition: 'all 0.6s cubic-bezier(.2,.9,.3,1.4)',
        zIndex: 1,
      }}>
        {/* Hero jelly cluster */}
        <div style={{ position: 'relative', width: 200, height: 170 }}>
          <div style={{ position: 'absolute', left: 18, top: 28, animation: 'jellyBob 2.4s ease-in-out infinite' }}>
            <JellyBlob color="red" size={82} shape="blob" expression="wow" idle={false} />
          </div>
          <div style={{ position: 'absolute', right: 10, top: 56, animation: 'jellyBob 2.6s 0.3s ease-in-out infinite' }}>
            <JellyBlob color="green" size={76} shape="organic" expression="happy" idle={false} />
          </div>
          <div style={{ position: 'absolute', left: 52, bottom: 0, animation: 'jellyBob 2.2s 0.6s ease-in-out infinite' }}>
            <JellyBlob color="blue" size={80} shape="blob" expression="wink" idle={false} />
          </div>
        </div>

        <div className={`jm-logo alt-${font}`} style={{ fontSize: 56 }}>JELLY MIX</div>

        <div style={{
          color: theme.textMuted, fontSize: 13, letterSpacing: 4, fontWeight: 600,
          opacity: phase >= 2 ? 1 : 0,
          transition: 'opacity 0.6s ease',
        }}>FONDI · COMBINA · COLLEZIONA</div>
      </div>

      {/* Loading dots */}
      <div style={{
        position: 'absolute', bottom: 56,
        display: 'flex', gap: 8,
        opacity: phase >= 2 ? 1 : 0,
        transition: 'opacity 0.4s ease',
      }}>
        {[0,1,2].map(i => (
          <div key={i} style={{
            width: 9, height: 9, borderRadius: 999,
            background: theme.accent2,
            animation: `pop 1s ${i * 0.15}s infinite alternate`,
          }} />
        ))}
      </div>
    </div>
  );
}

function WorldCard({ world, theme, expanded }) {
  return (
    <div style={{
      margin: '0 16px',
      borderRadius: 24,
      background: world.unlocked
        ? `linear-gradient(135deg, ${world.color}, ${shade(world.color, -10)})`
        : theme.surface,
      padding: '18px 20px',
      display: 'flex', alignItems: 'center', gap: 16,
      color: world.unlocked ? '#fff' : theme.textMuted,
      boxShadow: world.unlocked
        ? `0 8px 24px ${world.color}50, inset 0 1px 0 rgba(255,255,255,0.4)`
        : '0 2px 10px rgba(0,0,0,0.04)',
      position: 'relative', overflow: 'hidden',
      transform: expanded ? 'scale(1.02)' : 'scale(1)',
      transition: 'transform 0.2s ease',
    }}>
      {world.unlocked && (
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(120deg, transparent 30%, rgba(255,255,255,0.3) 50%, transparent 70%)',
          animation: 'shine 3.5s infinite',
          pointerEvents: 'none',
        }} />
      )}
      <div style={{
        width: 56, height: 56, borderRadius: 14,
        background: 'rgba(255,255,255,0.25)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 32, flexShrink: 0,
        boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.4)',
      }}>{world.emoji}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 11, opacity: 0.85, letterSpacing: 2, fontWeight: 600 }}>{world.sub}</div>
        <div style={{ fontSize: 22, fontWeight: 700, marginTop: 2 }}>{world.name}</div>
      </div>
      {!world.unlocked && <div style={{ fontSize: 24, opacity: 0.5 }}>🔒</div>}
    </div>
  );
}

function LevelNode({ idx, theme, status, onClick, x, y }) {
  const colors = {
    done: { bg: '#fff', star: '#ffce5c' },
    current: { bg: theme.accentGrad, star: '#fff' },
    locked: { bg: theme.dark ? 'rgba(255,255,255,0.1)' : '#fff', star: theme.dark ? 'rgba(255,255,255,0.25)' : '#d0c8d4' },
  };
  const c = colors[status];
  return (
    <div
      onClick={status !== 'locked' ? onClick : undefined}
      style={{
        position: 'absolute',
        left: x, top: y,
        width: 64, height: 64, borderRadius: '50%',
        background: c.bg,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 4px 14px rgba(0,0,0,0.1), inset 0 -2px 4px rgba(0,0,0,0.06)',
        border: `3px solid ${status === 'current' ? '#fff' : c.bg}`,
        cursor: status !== 'locked' ? 'pointer' : 'default',
        animation: status === 'current' ? 'pulseGlow 2s infinite' : 'none',
        transition: 'transform 0.15s ease',
        zIndex: 2,
      }}
    >
      {status === 'locked' ? (
        <svg width="22" height="24" viewBox="0 0 22 24" fill={c.star}>
          <rect x="5" y="11" width="12" height="9" rx="2" />
          <path d="M8 11V7.5a3 3 0 0 1 6 0V11" fill="none" stroke={c.star} strokeWidth="2" />
        </svg>
      ) : (
        <svg width="30" height="30" viewBox="0 0 24 24" fill={c.star}>
          <path d="M12 2l3 6.5 7 1-5 5 1.2 7L12 18l-6.2 3.5L7 14.5l-5-5 7-1z" />
        </svg>
      )}
      {status === 'current' && (
        <div style={{
          position: 'absolute', top: -28, left: '50%', transform: 'translateX(-50%)',
          background: '#fff', color: theme.text,
          padding: '3px 9px', borderRadius: 999,
          fontSize: 11, fontWeight: 700,
          boxShadow: '0 2px 6px rgba(0,0,0,0.12)',
          whiteSpace: 'nowrap',
        }}>LVL {idx}</div>
      )}
    </div>
  );
}

function MapScreen({ theme, font, onStartLevel, currentLevel }) {
  // Place nodes along a zigzag
  const nodePositions = [
    { x: 40, y: 30 },
    { x: 180, y: 120 },
    { x: 40, y: 220 },
    { x: 180, y: 320 },
    { x: 40, y: 420 },
  ];

  return (
    <div className="screen-fade" style={{
      position: 'absolute', inset: 0,
      background: theme.bg,
      overflow: 'auto',
      paddingBottom: 120,
    }}>
      <div style={{ paddingTop: 64, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 }}>
        <HeartRow theme={theme} />
        <div className={`jm-logo alt-${font}`}>JELLY MIX</div>
      </div>

      <div style={{ marginTop: 28, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <WorldCard world={WORLDS[0]} theme={theme} expanded />
        <WorldCard world={WORLDS[1]} theme={theme} />
      </div>

      {/* Path container */}
      <div style={{ marginTop: 28, position: 'relative', height: 520, padding: '0 60px' }}>
        <svg
          style={{ position: 'absolute', left: 0, top: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
          viewBox="0 0 320 520" preserveAspectRatio="none"
        >
          <path
            d="M 75 60 Q 220 90, 220 160 T 75 260 T 220 360 T 75 460"
            fill="none" stroke={theme.pathColor} strokeWidth="6"
            strokeDasharray="2 14" strokeLinecap="round" opacity="0.75"
          />
        </svg>
        {nodePositions.map((pos, i) => {
          const idx = i + 1;
          const status = idx < currentLevel ? 'done' : (idx === currentLevel ? 'current' : 'locked');
          return (
            <LevelNode
              key={idx} idx={idx} theme={theme} status={status}
              x={pos.x} y={pos.y}
              onClick={() => onStartLevel(idx)}
            />
          );
        })}
      </div>
    </div>
  );
}

Object.assign(window, { SplashScreen, MapScreen, WorldCard, LevelNode });
