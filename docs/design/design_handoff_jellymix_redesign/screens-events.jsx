// Events screen — daily booster wheel

const WHEEL_PRIZES = [
  { id: 'hammer', label: 'Martello', icon: '🔨', color: '#ff6b6b', amount: 1 },
  { id: 'coins',  label: '50 Monete', icon: 'coin', color: '#ffb31a', amount: 50 },
  { id: 'swap',   label: 'Scambio',  icon: '🔄', color: '#3d8cff', amount: 1 },
  { id: 'jelly',  label: 'Jelly Rara', icon: 'jelly-rainbow', color: '#a35bff', amount: 1 },
  { id: 'brush',  label: 'Pennello', icon: '🎨', color: '#c84ad6', amount: 1 },
  { id: 'coins-big', label: '200 Monete', icon: 'coin', color: '#ffce5c', amount: 200 },
  { id: 'life',   label: 'Vita Extra', icon: '❤️', color: '#ff4d80', amount: 1 },
  { id: 'star',   label: 'Stella Bonus', icon: '⭐', color: '#6ec8ff', amount: 1 },
];

const SPIN_KEY = 'jellymix-last-spin';

function getMsUntilNextSpin() {
  const last = parseInt(localStorage.getItem(SPIN_KEY) || '0', 10);
  if (!last) return 0;
  const next = last + 24 * 60 * 60 * 1000;
  return Math.max(0, next - Date.now());
}

function formatCountdown(ms) {
  if (ms <= 0) return null;
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function PrizeIcon({ icon, color, size = 32 }) {
  if (icon === 'coin') {
    return <div style={{ fontSize: 0 }}><Coin size={size} /></div>;
  }
  if (icon === 'jelly-rainbow') {
    return <JellyBlob color="rainbow" size={size} shape="blob" idle={false} />;
  }
  return <div style={{ fontSize: size * 0.9 }}>{icon}</div>;
}

function Wheel({ rotation, theme, spinning }) {
  // 8 segments, 45deg each
  const segs = WHEEL_PRIZES.length;
  const seg = 360 / segs;
  const r = 130;
  const cx = 140;
  const cy = 140;
  const SIZE = 280; // svg viewBox / coord space

  // alternating fills
  const fillA = theme.dark ? '#3a1a4e' : '#ffe0ec';
  const fillB = theme.dark ? '#52206a' : '#ffd4ad';
  const stroke = theme.dark ? 'rgba(255,255,255,0.15)' : 'rgba(255,255,255,0.85)';

  // Helpers (return % of SIZE so positions are container-relative)
  const polarPct = (a, dist) => {
    const rad = (a - 90) * Math.PI / 180;
    return [
      ((cx + dist * Math.cos(rad)) / SIZE) * 100,
      ((cy + dist * Math.sin(rad)) / SIZE) * 100,
    ];
  };

  const polar = (a, dist) => {
    const rad = (a - 90) * Math.PI / 180;
    return [cx + dist * Math.cos(rad), cy + dist * Math.sin(rad)];
  };

  const arcPath = (i) => {
    const a0 = i * seg;
    const a1 = (i + 1) * seg;
    const [x0, y0] = polar(a0, r);
    const [x1, y1] = polar(a1, r);
    return `M ${cx} ${cy} L ${x0} ${y0} A ${r} ${r} 0 0 1 ${x1} ${y1} Z`;
  };

  return (
    <div style={{
      position: 'relative',
      width: 290, height: 290,
      filter: 'drop-shadow(0 12px 30px rgba(180,60,200,0.3))',
    }}>
      {/* Outer ring with bulbs */}
      <div style={{
        position: 'absolute', inset: 0,
        borderRadius: '50%',
        background: `conic-gradient(from 0deg,
          ${theme.accent1}, ${theme.accent2}, ${theme.accent1})`,
        padding: 8,
      }}>
        <div style={{
          width: '100%', height: '100%',
          borderRadius: '50%',
          background: theme.dark ? '#1a0d2e' : '#fff',
          padding: 6,
          position: 'relative',
          boxShadow: 'inset 0 0 0 2px rgba(255,255,255,0.5)',
        }}>
          {/* Bulbs around the ring */}
          {Array.from({length: 16}).map((_,i) => {
            const ang = (i / 16) * 360;
            const [xp, yp] = polarPct(ang, r - 4);
            return (
              <div key={i} style={{
                position: 'absolute',
                left: `${xp}%`, top: `${yp}%`,
                transform: 'translate(-50%, -50%)',
                width: 8, height: 8, borderRadius: '50%',
                background: i % 2 === 0 ? '#fff' : '#ffe35c',
                boxShadow: i % 2 === 0
                  ? '0 0 6px rgba(255,255,255,0.9)'
                  : '0 0 8px rgba(255,200,60,0.9)',
                animation: `pulseGlow 1.4s ${i*0.08}s infinite`,
              }} />
            );
          })}

          {/* Wheel itself */}
          <div style={{
            position: 'relative', width: '100%', height: '100%',
            transform: `rotate(${rotation}deg)`,
            transition: spinning
              ? 'transform 0.05s linear'
              : 'transform 4.5s cubic-bezier(.15,.85,.25,1)',
          }}>
            <svg viewBox="0 0 280 280" width="100%" height="100%">
              {WHEEL_PRIZES.map((p, i) => (
                <path
                  key={i}
                  d={arcPath(i)}
                  fill={i % 2 === 0 ? fillA : fillB}
                  stroke={stroke}
                  strokeWidth="2"
                />
              ))}
              {/* Inner ring */}
              <circle cx={cx} cy={cy} r={42} fill={theme.dark ? '#1a0d2e' : '#fff'} stroke={stroke} strokeWidth="2" />
            </svg>

            {/* Prize icons positioned over each segment */}
            {WHEEL_PRIZES.map((p, i) => {
              const angle = i * seg + seg / 2;
              const dist = 88;
              const [xp, yp] = polarPct(angle, dist);
              return (
                <div key={i} style={{
                  position: 'absolute',
                  left: `${xp}%`, top: `${yp}%`,
                  transform: `translate(-50%, -50%) rotate(${angle}deg)`,
                  width: 48, height: 48,
                  borderRadius: '50%',
                  background: theme.dark ? 'rgba(255,255,255,0.95)' : '#fff',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: `0 3px 8px rgba(0,0,0,0.15), inset 0 0 0 2px ${p.color}`,
                }}>
                  <div style={{ transform: `rotate(${-angle}deg)`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <PrizeIcon icon={p.icon} color={p.color} size={p.icon === 'coin' ? 24 : 28} />
                  </div>
                </div>
              );
            })}
          </div>

          {/* Center hub — sun/star */}
          <div style={{
            position: 'absolute',
            left: '50%', top: '50%',
            transform: 'translate(-50%, -50%)',
            width: 60, height: 60,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 4,
          }}>
            <div style={{
              width: 50, height: 50, borderRadius: '50%',
              background: 'radial-gradient(circle at 35% 30%, #fff7a0, #ffae3a 60%, #c97a00)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 4px 12px rgba(180,100,0,0.4), inset 0 -3px 6px rgba(150,80,0,0.4)',
              animation: spinning ? 'jellyIdle 0.5s infinite' : 'none',
            }}>
              <svg width="28" height="28" viewBox="0 0 24 24" fill="#fff">
                <path d="M12 1l2.5 7.5L22 9l-6 5.5L18 22l-6-4-6 4 2-7.5L2 9l7.5-.5z" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* Pointer (fixed at top) */}
      <div style={{
        position: 'absolute',
        top: -4, left: '50%',
        transform: 'translateX(-50%)',
        width: 28, height: 36,
        zIndex: 10,
        filter: 'drop-shadow(0 3px 4px rgba(0,0,0,0.25))',
      }}>
        <svg viewBox="0 0 28 36" width="28" height="36">
          <path d="M14 36 L4 8 Q4 0 14 0 Q24 0 24 8 Z" fill={theme.accent1} stroke="#fff" strokeWidth="2" />
          <circle cx="14" cy="9" r="4" fill="#fff" />
        </svg>
      </div>
    </div>
  );
}

function EventsScreen({ theme, font }) {
  const [rotation, setRotation] = React.useState(0);
  const [spinning, setSpinning] = React.useState(false);
  const [phase, setPhase] = React.useState('idle'); // idle | spinning | revealing
  const [prize, setPrize] = React.useState(null);
  const [cooldown, setCooldown] = React.useState(getMsUntilNextSpin());
  const [tick, setTick] = React.useState(0);
  const spinSpeedRef = React.useRef(0);
  const animRef = React.useRef(null);

  // Cooldown tick
  React.useEffect(() => {
    if (cooldown <= 0) return;
    const id = setInterval(() => {
      const remaining = getMsUntilNextSpin();
      setCooldown(remaining);
    }, 1000);
    return () => clearInterval(id);
  }, [cooldown]);

  // Spinning animation (fast continuous rotation while phase === 'spinning')
  React.useEffect(() => {
    if (phase !== 'spinning') return;
    let lastT = performance.now();
    const tick = (t) => {
      const dt = t - lastT;
      lastT = t;
      setRotation(r => r + spinSpeedRef.current * dt);
      animRef.current = requestAnimationFrame(tick);
    };
    spinSpeedRef.current = 1.4; // deg per ms = ~1400 deg/s
    animRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(animRef.current);
  }, [phase]);

  const startSpin = () => {
    if (cooldown > 0 || phase !== 'idle') return;
    setPhase('spinning');
    setSpinning(true);
  };

  const stopSpin = () => {
    if (phase !== 'spinning') return;
    cancelAnimationFrame(animRef.current);

    // Pick a random prize
    const idx = Math.floor(Math.random() * WHEEL_PRIZES.length);
    const seg = 360 / WHEEL_PRIZES.length;
    // We want the pointer (at 0° / top) to land on segment idx's center.
    // Segment idx center is at angle = idx * seg + seg/2 in wheel-local coords (0 = top).
    // To bring that to the top, we need rotation = -targetAngle (mod 360) + multiples of 360.
    const targetLocal = idx * seg + seg / 2;
    // current rotation mod 360
    const cur = ((rotation % 360) + 360) % 360;
    // we want final rotation such that (final mod 360) === (360 - targetLocal) mod 360
    const wantedMod = (360 - targetLocal + 360) % 360;
    const delta = (wantedMod - cur + 360) % 360;
    const extraSpins = 4 * 360; // 4 full spins more
    const finalRotation = rotation + extraSpins + delta;

    setRotation(finalRotation);
    setSpinning(false); // triggers slow easeOut transition

    // After easeOut completes, reveal
    setTimeout(() => {
      setPrize(WHEEL_PRIZES[idx]);
      setPhase('revealing');
      localStorage.setItem(SPIN_KEY, Date.now().toString());
      setCooldown(24 * 60 * 60 * 1000);
    }, 4600);
  };

  const closeReveal = () => {
    setPrize(null);
    setPhase('idle');
  };

  // Dev reset
  const resetCooldown = () => {
    localStorage.removeItem(SPIN_KEY);
    setCooldown(0);
  };

  const canSpin = cooldown <= 0 && phase === 'idle';
  const countdownStr = formatCountdown(cooldown);

  return (
    <div className="screen-fade" style={{
      position: 'absolute', inset: 0,
      background: theme.bg,
      overflow: 'auto', paddingBottom: 120,
    }}>
      {/* Decorative confetti dots background */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', opacity: 0.5 }}>
        {Array.from({length: 18}).map((_, i) => {
          const x = (i * 53) % 100;
          const y = (i * 31) % 100;
          const size = 4 + (i % 4) * 2;
          const colors = ['#ff5fa2','#ffb31a','#3d8cff','#3dcb5e','#a35bff'];
          return (
            <div key={i} style={{
              position: 'absolute',
              left: `${x}%`, top: `${y}%`,
              width: size, height: size, borderRadius: '50%',
              background: colors[i % colors.length],
              animation: `float ${3 + i * 0.2}s ${i * 0.1}s infinite ease-in-out`,
            }} />
          );
        })}
      </div>

      <div style={{ paddingTop: 64, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
        <HeartRow theme={theme} />
        <div className={`jm-logo alt-${font}`}>EVENTI</div>
      </div>

      {/* Event card */}
      <div style={{
        margin: '20px 16px 0', padding: '22px 18px 20px',
        borderRadius: 28,
        background: 'linear-gradient(160deg, rgba(255,180,220,0.55), rgba(255,200,140,0.35))',
        border: `1.5px solid ${theme.surfaceBorder}`,
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        boxShadow: '0 8px 28px rgba(180,60,200,0.18)',
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        position: 'relative',
      }}>
        {/* Title */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4,
        }}>
          <div style={{
            fontSize: 24, fontWeight: 700,
            background: theme.accentGrad,
            WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent',
          }}>Ruota Fortunata</div>
        </div>
        <div style={{
          color: theme.textMuted, fontSize: 13, textAlign: 'center', marginBottom: 16,
          maxWidth: 280,
        }}>Gira una volta al giorno per vincere un potenziamento gratis</div>

        {/* Wheel */}
        <Wheel rotation={rotation} theme={theme} spinning={spinning} />

        {/* Status / button */}
        <div style={{ marginTop: 22, width: '100%' }}>
          {canSpin && phase === 'idle' && (
            <button onClick={startSpin} style={{
              width: '100%', padding: '15px',
              borderRadius: 999,
              background: theme.accentGrad,
              color: '#fff', fontWeight: 800, fontSize: 18,
              letterSpacing: 0.5,
              border: 'none', cursor: 'pointer',
              boxShadow: '0 8px 22px rgba(180,60,200,0.4), inset 0 1px 0 rgba(255,255,255,0.3)',
              animation: 'pulseGlow 2s infinite',
            }}>GIRA LA RUOTA!</button>
          )}
          {phase === 'spinning' && (
            <button onClick={stopSpin} style={{
              width: '100%', padding: '15px',
              borderRadius: 999,
              background: 'linear-gradient(135deg, #ff5567, #ff3088)',
              color: '#fff', fontWeight: 800, fontSize: 18,
              letterSpacing: 0.5,
              border: 'none', cursor: 'pointer',
              boxShadow: '0 8px 22px rgba(255,80,120,0.4)',
              animation: 'pulseGlow 0.6s infinite',
            }}>STOP!</button>
          )}
          {!canSpin && phase === 'idle' && (
            <div style={{
              padding: '12px 18px',
              borderRadius: 999,
              background: theme.dark ? 'rgba(255,255,255,0.08)' : 'rgba(160,140,170,0.18)',
              color: theme.text,
              textAlign: 'center',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
            }}>
              <div style={{ fontSize: 11, color: theme.textMuted, letterSpacing: 1.5, fontWeight: 600 }}>PROSSIMO GIRO</div>
              <div style={{ fontSize: 22, fontWeight: 800, color: theme.accent1, fontVariantNumeric: 'tabular-nums' }}>
                {countdownStr}
              </div>
              <button onClick={resetCooldown} style={{
                marginTop: 4,
                background: 'transparent',
                border: 'none',
                color: theme.textMuted,
                fontSize: 10,
                textDecoration: 'underline',
                cursor: 'pointer',
                opacity: 0.6,
              }}>(Dev: reset)</button>
            </div>
          )}
        </div>
      </div>

      {/* Other events teasers */}
      <div style={{
        margin: '14px 16px 0',
        padding: '14px 16px',
        borderRadius: 22,
        background: theme.surface,
        border: `1px solid ${theme.surfaceBorder}`,
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
      }}>
        <div style={{ fontSize: 12, fontWeight: 700, color: theme.textMuted, letterSpacing: 1.5, marginBottom: 10 }}>PROSSIMI EVENTI</div>
        {[
          { name: 'Sfida Settimanale', sub: 'Termina tra 4 giorni', icon: '🏆', color: '#ffce5c' },
          { name: 'Mondo Bonus', sub: 'Disponibile sabato', icon: '✨', color: '#a35bff' },
        ].map((e, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '10px 4px',
            borderTop: i > 0 ? `1px solid ${theme.dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'}` : 'none',
          }}>
            <div style={{
              width: 38, height: 38, borderRadius: 11,
              background: `${e.color}25`,
              border: `1.5px solid ${e.color}55`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 20,
            }}>{e.icon}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, color: theme.text, fontSize: 14 }}>{e.name}</div>
              <div style={{ color: theme.textMuted, fontSize: 11.5 }}>{e.sub}</div>
            </div>
            <div style={{
              padding: '4px 10px', borderRadius: 999,
              background: 'rgba(180,140,200,0.18)',
              color: theme.textMuted,
              fontSize: 10, fontWeight: 700, letterSpacing: 1,
            }}>PRESTO</div>
          </div>
        ))}
      </div>

      {/* Prize reveal modal */}
      {phase === 'revealing' && prize && (
        <PrizeReveal prize={prize} theme={theme} onClose={closeReveal} />
      )}
    </div>
  );
}

function PrizeReveal({ prize, theme, onClose }) {
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0,
      background: 'rgba(20,8,35,0.6)',
      backdropFilter: 'blur(8px)',
      WebkitBackdropFilter: 'blur(8px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: 200,
      animation: 'screenIn 0.3s ease',
    }}>
      <Confetti count={50} />
      <div style={{
        width: 280, padding: '28px 24px',
        borderRadius: 28,
        background: theme.bg,
        border: `1.5px solid ${theme.surfaceBorder}`,
        boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14,
        position: 'relative',
      }}>
        <div style={{
          fontSize: 13, fontWeight: 700, letterSpacing: 2,
          color: theme.textMuted,
        }}>HAI VINTO</div>

        {/* Prize icon big */}
        <div style={{
          width: 110, height: 110, borderRadius: '50%',
          background: `radial-gradient(circle, ${prize.color}40, transparent 70%)`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          animation: 'pop 0.6s cubic-bezier(.3,1.6,.5,1) both',
        }}>
          <div style={{
            width: 84, height: 84, borderRadius: '50%',
            background: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 6px 20px ${prize.color}66, inset 0 0 0 3px ${prize.color}`,
            animation: 'jellyBob 1.4s ease-in-out infinite',
          }}>
            <PrizeIcon icon={prize.icon} color={prize.color} size={prize.icon === 'coin' ? 50 : 50} />
          </div>
        </div>

        <div className="jm-logo" style={{ fontSize: 28 }}>{prize.label}</div>

        <div style={{
          padding: '8px 16px',
          borderRadius: 999,
          background: `${prize.color}20`,
          color: prize.color,
          fontWeight: 700,
          fontSize: 13,
        }}>+{prize.amount} {prize.id === 'coins' || prize.id === 'coins-big' ? 'Monete' : prize.id === 'life' ? 'Vita' : 'Bonus'}</div>

        <button onClick={onClose} style={{
          width: '100%', padding: '12px',
          borderRadius: 999,
          background: theme.accentGrad,
          color: '#fff', fontWeight: 700, fontSize: 16,
          border: 'none', cursor: 'pointer',
          boxShadow: '0 8px 20px rgba(180,60,200,0.35)',
          marginTop: 4,
        }}>Fantastico!</button>
      </div>
    </div>
  );
}

Object.assign(window, { EventsScreen, Wheel, PrizeReveal });
