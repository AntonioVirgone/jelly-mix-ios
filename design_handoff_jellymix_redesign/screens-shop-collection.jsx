// Shop + Collection + BottomNav

function ShopScreen({ theme, font, initialCoins = 350 }) {
  const [coins, setCoins] = React.useState(initialCoins);
  const [packState, setPackState] = React.useState('idle');
  const [revealedCards, setRevealedCards] = React.useState([]);
  const [owned, setOwned] = React.useState({ hammer: 2, swap: 0, brush: 0 });

  const openPack = () => {
    if (coins < 100 || packState !== 'idle') return;
    setCoins(c => c - 100);
    setPackState('shaking');
    setTimeout(() => setPackState('bursting'), 900);
    setTimeout(() => {
      const pool = ['red','blue','green','yellow','orange','purple','pink','rainbow'];
      const cards = [...pool].sort(() => Math.random() - 0.5).slice(0, 3);
      setRevealedCards(cards);
      setPackState('reveal');
    }, 1300);
  };

  const closeReveal = () => {
    setPackState('idle');
    setRevealedCards([]);
  };

  const buyUpgrade = (key, price) => {
    if (coins < price) return;
    setCoins(c => c - price);
    setOwned(o => ({ ...o, [key]: o[key] + 1 }));
  };

  return (
    <div className="screen-fade" style={{
      position: 'absolute', inset: 0,
      background: theme.bg,
      overflow: 'auto', paddingBottom: 120,
    }}>
      <div style={{ paddingTop: 64, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
        <HeartRow theme={theme} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div className={`jm-logo alt-${font}`}>NEGOZIO</div>
          <CoinPill coins={coins} theme={theme} big />
        </div>
      </div>

      {/* Pack card */}
      <div style={{
        margin: '22px 18px 0', padding: '24px 22px 22px',
        borderRadius: 28,
        background: 'linear-gradient(160deg, rgba(255,180,220,0.5), rgba(200,140,255,0.3))',
        border: `1.5px solid ${theme.surfaceBorder}`,
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        boxShadow: '0 8px 28px rgba(180,60,200,0.15)',
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14,
        position: 'relative', overflow: 'hidden',
      }}>
        {/* Sparkle decorations */}
        {packState !== 'reveal' && [
          {x:'8%', y:'15%', s:14, d:0},
          {x:'90%', y:'20%', s:10, d:0.3},
          {x:'12%', y:'78%', s:11, d:0.6},
          {x:'88%', y:'75%', s:13, d:0.2},
        ].map((s, i) => (
          <div key={i} style={{
            position: 'absolute', left: s.x, top: s.y,
            width: s.s, height: s.s, pointerEvents: 'none',
            animation: `pop 1.6s ${s.d}s infinite alternate`,
          }}>
            <svg viewBox="0 0 12 12" width={s.s} height={s.s}>
              <path d="M6 0 L7 5 L12 6 L7 7 L6 12 L5 7 L0 6 L5 5 Z" fill="#fff" opacity="0.9" />
            </svg>
          </div>
        ))}

        {/* Pack visual */}
        <div style={{
          width: 110, height: 130, position: 'relative',
          animation: packState === 'shaking' ? 'packShake 0.18s infinite' : 'float 3s ease-in-out infinite',
        }}>
          <div style={{
            position: 'absolute', inset: 0,
            borderRadius: 22,
            background: theme.accentGrad,
            boxShadow: '0 12px 28px rgba(180,60,200,0.35), inset 0 2px 0 rgba(255,255,255,0.4), inset 0 -4px 8px rgba(0,0,0,0.15)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transform: packState === 'bursting' ? 'scale(1.4)' : 'scale(1)',
            opacity: packState === 'bursting' ? 0 : 1,
            transition: packState === 'bursting' ? 'all 0.4s ease-out' : 'transform 0.2s',
            overflow: 'hidden',
          }}>
            {/* Top wrapper band */}
            <div style={{
              position: 'absolute', top: 0, left: 0, right: 0, height: 30,
              background: 'rgba(255,255,255,0.25)',
              borderBottom: '2px dashed rgba(255,255,255,0.5)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 11, fontWeight: 800, color: 'rgba(255,255,255,0.9)', letterSpacing: 2,
            }}>BUSTINA</div>
            {/* Jelly peek */}
            <div style={{ marginTop: 14 }}>
              <JellyBlob color="pink" size={54} shape="blob" expression="wow" />
            </div>
          </div>
        </div>

        <div style={{
          fontSize: 22, fontWeight: 700,
          background: theme.accentGrad,
          WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent',
        }}>Bustina di Gelatine</div>
        <div style={{ color: theme.textMuted, fontSize: 13.5, textAlign: 'center' }}>
          3 carte casuali, incluse le rare!
        </div>
        <button
          onClick={openPack}
          disabled={coins < 100 || packState !== 'idle'}
          style={{
            width: '100%', padding: '13px',
            borderRadius: 999,
            background: coins >= 100 && packState === 'idle'
              ? 'linear-gradient(135deg, #3d8cff, #a35bff)'
              : (theme.dark ? 'rgba(255,255,255,0.1)' : 'rgba(80,80,90,0.4)'),
            color: '#fff', fontWeight: 700, fontSize: 16,
            border: 'none',
            cursor: coins >= 100 && packState === 'idle' ? 'pointer' : 'default',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: coins >= 100 ? '0 6px 18px rgba(60,140,255,0.35)' : 'none',
          }}>
          Apri Bustina — 100 <Coin size={20} />
        </button>
      </div>

      {/* Power-ups */}
      <div style={{
        margin: '18px 18px 0', padding: '18px 16px',
        borderRadius: 28,
        background: 'linear-gradient(160deg, rgba(255,200,220,0.4), rgba(255,160,200,0.25))',
        border: `1.5px solid ${theme.surfaceBorder}`,
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
      }}>
        <div style={{
          textAlign: 'center', fontSize: 20, fontWeight: 700, marginBottom: 12,
          background: theme.accentGrad,
          WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent',
        }}>Potenziamenti</div>

        {[
          { key:'hammer', icon:'🔨', name:'Martello', sub:'Distruggi una jelly', price:500, color:'#ff6b6b' },
          { key:'swap', icon:'🔄', name:'Scambio', sub:'Cambia il prossimo', price:500, color:'#3d8cff' },
          { key:'brush', icon:'🎨', name:'Pennello', sub:'Cambia colore', price:500, color:'#a35bff' },
        ].map(p => (
          <div key={p.key} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '10px 12px',
            borderRadius: 16,
            background: 'rgba(255,255,255,0.45)',
            marginBottom: 8,
          }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12,
              background: `${p.color}25`,
              border: `1.5px solid ${p.color}45`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 22,
            }}>{p.icon}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 700, color: theme.text, fontSize: 15 }}>{p.name}</div>
              <div style={{ color: theme.textMuted, fontSize: 11 }}>{p.sub} · Posseduti: {owned[p.key]}</div>
            </div>
            <button
              onClick={() => buyUpgrade(p.key, p.price)}
              disabled={coins < p.price}
              style={{
                background: coins >= p.price ? theme.accentGrad : (theme.dark ? 'rgba(255,255,255,0.15)' : 'rgba(120,100,140,0.18)'),
                color: coins >= p.price ? '#fff' : theme.textMuted,
                border: 'none',
                padding: '7px 12px',
                borderRadius: 999,
                fontWeight: 700, fontSize: 13,
                display: 'flex', alignItems: 'center', gap: 5,
                cursor: coins >= p.price ? 'pointer' : 'default',
              }}>
              {p.price} <Coin size={14} />
            </button>
          </div>
        ))}
      </div>

      {/* Pack reveal modal */}
      {packState === 'reveal' && (
        <div onClick={closeReveal} style={{
          position: 'absolute', inset: 0,
          background: 'rgba(20,8,35,0.6)',
          backdropFilter: 'blur(8px)',
          WebkitBackdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          zIndex: 200,
          animation: 'screenIn 0.3s ease',
        }}>
          <Confetti count={40} />
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 22 }}>
            <div style={{ color: '#fff', fontSize: 26, fontWeight: 700,
              animation: 'pop 0.5s 0.2s both' }}>Nuove Jelly!</div>
            <div style={{ display: 'flex', gap: 14 }}>
              {revealedCards.map((color, i) => (
                <div key={i} style={{
                  width: 84, height: 108,
                  borderRadius: 16,
                  background: 'rgba(255,255,255,0.95)',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                  gap: 4,
                  animation: `cardReveal 0.6s ${i * 0.18}s cubic-bezier(.3,1.4,.5,1) both`,
                  boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
                }}>
                  <JellyBlob color={color} size={52} shape="blob" expression={color === 'rainbow' ? 'wow' : 'happy'} />
                  <div style={{ fontSize: 12, fontWeight: 700, color: '#3a2a3e' }}>
                    {JELLY_COLORS[color]?.name}
                  </div>
                </div>
              ))}
            </div>
            <button onClick={closeReveal} style={{
              padding: '11px 24px',
              borderRadius: 999,
              background: theme.accentGrad,
              color: '#fff', fontWeight: 700, fontSize: 15,
              border: 'none', cursor: 'pointer',
            }}>Tocca per continuare</button>
          </div>
        </div>
      )}
    </div>
  );
}

function CollectionScreen({ theme, font, owned = ['red','blue','yellow'] }) {
  const all = ['rainbow','red','blue','green','yellow','orange','purple','pink'];
  return (
    <div className="screen-fade" style={{
      position: 'absolute', inset: 0,
      background: theme.bg,
      overflow: 'auto', paddingBottom: 120,
    }}>
      <div style={{ paddingTop: 64, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
        <HeartRow theme={theme} />
        <div className={`jm-logo alt-${font}`}>COLLEZIONE</div>
        <div style={{ color: theme.textMuted, fontSize: 13, fontWeight: 500 }}>
          {owned.length} / {all.length} sbloccate
        </div>
      </div>

      <div style={{
        margin: '22px 20px 0',
        display: 'grid',
        gridTemplateColumns: 'repeat(3, 1fr)',
        gap: 16,
      }}>
        {all.map((c) => {
          const isOwned = owned.includes(c);
          return (
            <div key={c} style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
            }}>
              <div style={{
                width: 86, height: 86,
                borderRadius: 22,
                background: isOwned ? theme.surface : (theme.dark ? 'rgba(255,255,255,0.05)' : 'rgba(160,140,170,0.1)'),
                border: `1.5px solid ${theme.surfaceBorder}`,
                backdropFilter: 'blur(8px)',
                WebkitBackdropFilter: 'blur(8px)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: isOwned ? '0 6px 18px rgba(0,0,0,0.08)' : 'none',
                position: 'relative',
              }}>
                <JellyBlob color={c} size={58} shape="blob" faded={!isOwned} idle={isOwned} expression="happy" />
                {!isOwned && (
                  <div style={{
                    position: 'absolute', bottom: 6, right: 6,
                    width: 22, height: 22, borderRadius: '50%',
                    background: 'rgba(80,60,100,0.55)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <svg width="11" height="13" viewBox="0 0 12 14" fill="#fff">
                      <rect x="1.5" y="6" width="9" height="7" rx="1.5" />
                      <path d="M3 6V3.8A3 3 0 0 1 9 3.8V6" fill="none" stroke="#fff" strokeWidth="1.4" />
                    </svg>
                  </div>
                )}
              </div>
              <div style={{
                fontSize: 12.5, fontWeight: 700,
                color: isOwned ? theme.accent1 : theme.textMuted,
              }}>{isOwned ? JELLY_COLORS[c]?.name : '???'}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function BottomNav({ active, onChange, theme }) {
  const tabs = [
    { id:'map', label:'MAPPA', icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <path d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2-6-2z" opacity="0.85" />
        <path d="M9 4v14M15 6v14" stroke="rgba(0,0,0,0.15)" strokeWidth="1" />
      </svg>
    )},
    { id:'events', label:'EVENTI', icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="2"/>
        <path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M5.6 18.4L18.4 5.6" stroke="currentColor" strokeWidth="1.4" opacity="0.7"/>
        <circle cx="12" cy="12" r="2.5" fill="currentColor"/>
      </svg>
    )},
    { id:'shop', label:'NEGOZIO', icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <path d="M5 9h14l-1 11H6L5 9z" />
        <path d="M9 9V6a3 3 0 016 0v3" fill="none" stroke="currentColor" strokeWidth="2" />
      </svg>
    )},
    { id:'collection', label:'COLLEZIONE', icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <path d="M4 4h7v16H5a1 1 0 01-1-1V4zM13 4h7v15a1 1 0 01-1 1h-6V4z" />
      </svg>
    )},
  ];

  return (
    <div style={{
      position: 'absolute', bottom: 16, left: 16, right: 16,
      zIndex: 50,
      padding: 6,
      borderRadius: 999,
      background: theme.navBg,
      border: `1px solid ${theme.surfaceBorder}`,
      backdropFilter: 'blur(20px) saturate(180%)',
      WebkitBackdropFilter: 'blur(20px) saturate(180%)',
      boxShadow: '0 10px 30px rgba(0,0,0,0.12), inset 0 1px 0 rgba(255,255,255,0.5)',
      display: 'flex', gap: 4,
    }}>
      {tabs.map(t => {
        const isActive = t.id === active;
        return (
          <button key={t.id} onClick={() => onChange(t.id)} style={{
            flex: 1,
            padding: '11px 4px',
            borderRadius: 999,
            background: isActive ? theme.accentGrad : 'transparent',
            color: isActive ? '#fff' : theme.textMuted,
            border: 'none',
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            gap: 3, cursor: 'pointer',
            transition: 'all 0.2s',
            boxShadow: isActive ? '0 6px 16px rgba(180,60,200,0.35)' : 'none',
            transform: isActive ? 'scale(1)' : 'scale(0.96)',
            minWidth: 0,
          }}>
            {t.icon}
            <span style={{ fontSize: 8.5, fontWeight: 800, letterSpacing: 0.6, whiteSpace: 'nowrap' }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

Object.assign(window, { ShopScreen, CollectionScreen, BottomNav });
