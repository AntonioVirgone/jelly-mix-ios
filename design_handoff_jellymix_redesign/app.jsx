// Main App — orchestrates screens, theme, tweaks

const { useTweaks, TweaksPanel, TweakSection, TweakRadio, TweakToggle } = window;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "pastel-cream",
  "font": "fredoka",
  "shape": "blob",
  "showTweaks": true
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [screen, setScreen] = React.useState('splash'); // splash | map | game | shop | collection
  const [activeTab, setActiveTab] = React.useState('map');
  const [currentLevel, setCurrentLevel] = React.useState(3);

  const theme = THEMES[t.theme] || THEMES['pastel-cream'];

  // CSS vars on body
  React.useEffect(() => {
    document.body.style.setProperty('--jm-accent1', theme.accent1);
    document.body.style.setProperty('--jm-accent2', theme.accent2);
  }, [theme]);

  const goToTab = (tab) => {
    setActiveTab(tab);
    if (tab === 'map') setScreen('map');
    if (tab === 'events') setScreen('events');
    if (tab === 'shop') setScreen('shop');
    if (tab === 'collection') setScreen('collection');
  };

  const showNav = screen === 'map' || screen === 'events' || screen === 'shop' || screen === 'collection';

  return (
    <PhoneFrame>
      <div style={{ position: 'absolute', inset: 0 }}>
        {screen === 'splash' && (
          <SplashScreen theme={theme} font={t.font} onReady={() => setScreen('map')} />
        )}
        {screen === 'map' && (
          <MapScreen theme={theme} font={t.font} currentLevel={currentLevel}
            onStartLevel={(lvl) => { setCurrentLevel(lvl); setScreen('game'); }}
          />
        )}
        {screen === 'game' && (
          <GameScreen theme={theme} font={t.font} level={currentLevel}
            onBack={() => setScreen('map')}
            onWin={() => { setCurrentLevel(l => l + 1); setScreen('map'); }}
          />
        )}
        {screen === 'events' && (
          <EventsScreen theme={theme} font={t.font} />
        )}
        {screen === 'shop' && (
          <ShopScreen theme={theme} font={t.font} />
        )}
        {screen === 'collection' && (
          <CollectionScreen theme={theme} font={t.font} />
        )}
        {showNav && (
          <BottomNav active={activeTab} onChange={goToTab} theme={theme} />
        )}
      </div>

      {/* Tweaks panel */}
      <TweaksPanel>
        <TweakSection label="Tema visivo" />
        <TweakRadio label="Sfondo / palette" value={t.theme}
          options={[
            { value: 'pastel-cream', label: 'Pastel' },
            { value: 'candy-sky', label: 'Candy Sky' },
            { value: 'berry-night', label: 'Berry Night' },
          ]}
          onChange={(v) => setTweak('theme', v)} />

        <TweakSection label="Tipografia" />
        <TweakRadio label="Font logo" value={t.font}
          options={[
            { value: 'fredoka', label: 'Fredoka' },
            { value: 'baloo', label: 'Baloo' },
            { value: 'sniglet', label: 'Sniglet' },
          ]}
          onChange={(v) => setTweak('font', v)} />

        <TweakSection label="Navigazione rapida" />
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6,
        }}>
          {[
            { id: 'splash', label: 'Splash' },
            { id: 'map', label: 'Mappa' },
            { id: 'game', label: 'Gioco' },
            { id: 'events', label: 'Eventi' },
            { id: 'shop', label: 'Negozio' },
            { id: 'collection', label: 'Coll.' },
          ].map(s => (
            <button key={s.id} onClick={() => {
              setScreen(s.id);
              if (s.id === 'map' || s.id === 'events' || s.id === 'shop' || s.id === 'collection') setActiveTab(s.id);
            }} style={{
              padding: '6px 4px',
              borderRadius: 7,
              border: screen === s.id ? '1.5px solid #a23ad6' : '1px solid rgba(0,0,0,0.1)',
              background: screen === s.id ? 'rgba(162,58,214,0.1)' : 'rgba(255,255,255,0.5)',
              color: screen === s.id ? '#a23ad6' : '#3a2a3e',
              fontWeight: 600,
              fontSize: 11,
              cursor: 'pointer',
            }}>{s.label}</button>
          ))}
        </div>
      </TweaksPanel>
    </PhoneFrame>
  );
}

// Phone frame wrapper — simplified, just gives the device shell
function PhoneFrame({ children }) {
  const W = 390;
  const H = 844;

  // scale to fit viewport
  const [scale, setScale] = React.useState(1);
  React.useEffect(() => {
    const compute = () => {
      const padding = 40;
      const sx = (window.innerWidth - padding) / W;
      const sy = (window.innerHeight - padding) / H;
      setScale(Math.min(1, Math.min(sx, sy)));
    };
    compute();
    window.addEventListener('resize', compute);
    return () => window.removeEventListener('resize', compute);
  }, []);

  return (
    <div style={{
      width: W, height: H,
      position: 'relative',
      borderRadius: 54,
      background: '#0e0a16',
      padding: 10,
      boxShadow: '0 40px 100px rgba(0,0,0,0.25), 0 0 0 1px rgba(0,0,0,0.4)',
      transform: `scale(${scale})`,
      transformOrigin: 'center center',
    }}>
      <div style={{
        width: '100%', height: '100%',
        borderRadius: 44,
        overflow: 'hidden',
        position: 'relative',
        background: '#fff',
      }}>
        {/* Dynamic island */}
        <div style={{
          position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
          width: 120, height: 35, borderRadius: 24, background: '#000', zIndex: 100,
        }} />
        {/* Status bar */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0,
          display: 'flex', justifyContent: 'space-between',
          padding: '18px 32px 0', zIndex: 99,
          pointerEvents: 'none',
        }}>
          <div style={{ fontWeight: 600, fontSize: 16, fontFamily: '-apple-system, system-ui' }}>16:51</div>
          <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
            <svg width="17" height="11" viewBox="0 0 17 11" fill="#000">
              <rect x="0" y="7" width="3" height="4" rx="0.6"/>
              <rect x="4.5" y="5" width="3" height="6" rx="0.6"/>
              <rect x="9" y="2.5" width="3" height="8.5" rx="0.6"/>
              <rect x="13.5" y="0" width="3" height="11" rx="0.6"/>
            </svg>
            <svg width="15" height="11" viewBox="0 0 15 11" fill="#000">
              <path d="M7.5 2.6c2 0 3.9.8 5.2 2.2l1-1c-1.6-1.6-3.8-2.6-6.2-2.6S3 2.2 1.4 3.8l1 1c1.3-1.4 3.2-2.2 5.1-2.2zm0 3.2c1.2 0 2.3.5 3.1 1.2l1-1c-1.1-1.1-2.5-1.7-4.1-1.7s-3 .6-4.1 1.7l1 1c.8-.7 1.9-1.2 3.1-1.2z" />
              <circle cx="7.5" cy="9.5" r="1.3" />
            </svg>
            <svg width="25" height="12" viewBox="0 0 25 12">
              <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="#000" strokeOpacity="0.4" fill="none" />
              <rect x="2" y="2" width="18" height="8" rx="1.8" fill="#000" />
              <path d="M23 4v4c.7-.3 1.3-1.1 1.3-2s-.6-1.7-1.3-2z" fill="#000" opacity="0.5" />
            </svg>
          </div>
        </div>
        {children}
      </div>
    </div>
  );
}

Object.assign(window, { App, PhoneFrame });
