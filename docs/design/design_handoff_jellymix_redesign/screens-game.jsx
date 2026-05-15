// Game screen — board + drag/merge interactions

const COLOR_KEYS = ['red','blue','green','yellow','orange','purple','pink'];

// Merge rules
const MERGE = {
  red_yellow: 'orange', yellow_red: 'orange',
  blue_yellow: 'green', yellow_blue: 'green',
  red_blue: 'purple', blue_red: 'purple',
  red_white: 'pink',
  // rainbow merges with anything -> matches color
};

const GRID_W = 5;
const GRID_H = 6;

function initialBoard() {
  return [
    [null, null, null, 'red', 'yellow'],
    ['blue', 'blue', 'green', null, null],
    [null, null, 'red', null, 'yellow'],
    [null, 'blue', null, 'yellow', null],
    [null, 'green', 'green', null, null],
    [null, null, null, null, null],
  ];
}

function GameScreen({ theme, font, level, onBack, onWin }) {
  const [board, setBoard] = React.useState(initialBoard);
  const [moves, setMoves] = React.useState(28);
  const [score, setScore] = React.useState(150);
  const [coins, setCoins] = React.useState(0);
  const [next, setNext] = React.useState('rainbow');
  const [hold, setHold] = React.useState('red');
  const [oranges, setOranges] = React.useState(0);
  const [target] = React.useState(3);
  const [dragging, setDragging] = React.useState(null);
  const [draggingFrom, setDraggingFrom] = React.useState(null);
  const [hoveredCell, setHoveredCell] = React.useState(null);
  const [mergeAnim, setMergeAnim] = React.useState(null);
  const [sparkles, setSparkles] = React.useState([]);
  const [floatScore, setFloatScore] = React.useState(null);
  const [showWin, setShowWin] = React.useState(false);
  const [shakeCell, setShakeCell] = React.useState(null);
  const boardRef = React.useRef(null);

  const cellSize = 56;
  const gap = 8;

  const placeAt = (r, c, color) => {
    const existing = board[r][c];
    if (existing) {
      // Rainbow merges with anything to that color
      if (color === 'rainbow' && existing !== 'rainbow') {
        const newBoard = board.map(row => row.slice());
        newBoard[r][c] = existing;
        setBoard(newBoard);
        triggerMerge(r, c, existing);
        return true;
      }
      if (existing === 'rainbow' && color !== 'rainbow') {
        const newBoard = board.map(row => row.slice());
        newBoard[r][c] = color;
        setBoard(newBoard);
        triggerMerge(r, c, color);
        return true;
      }
      const key = `${existing}_${color}`;
      const out = MERGE[key];
      if (out) {
        const newBoard = board.map(row => row.slice());
        newBoard[r][c] = out;
        setBoard(newBoard);
        triggerMerge(r, c, out);
        return true;
      }
      // No merge — shake and reject
      setShakeCell({ r, c });
      setTimeout(() => setShakeCell(null), 400);
      return false;
    } else {
      const newBoard = board.map(row => row.slice());
      newBoard[r][c] = color;
      setBoard(newBoard);
      return true;
    }
  };

  const triggerMerge = (r, c, out) => {
    setMergeAnim({ r, c });
    setScore(s => s + 50);
    setCoins(co => co + 5);
    setFloatScore({ r, c, value: '+50' });

    const baseId = Date.now();
    const newSparks = Array.from({length: 8}).map((_,i) => ({
      id: baseId + i,
      x: c * (cellSize + gap) + cellSize / 2 + (Math.random() - 0.5) * 60,
      y: r * (cellSize + gap) + cellSize / 2 + (Math.random() - 0.5) * 60,
      delay: i * 0.04,
      color: JELLY_COLORS[out]?.light || '#fff',
    }));
    setSparkles(s => [...s, ...newSparks]);

    if (out === 'orange') {
      setOranges(o => {
        const nc = o + 1;
        if (nc >= target) setTimeout(() => setShowWin(true), 600);
        return nc;
      });
    }

    setTimeout(() => { setMergeAnim(null); setFloatScore(null); }, 900);
    setTimeout(() => {
      setSparkles(s => s.filter(sp => !newSparks.find(n => n.id === sp.id)));
    }, 1300);
  };

  const onDragStart = (e, from, color) => {
    e.preventDefault();
    const touch = e.touches ? e.touches[0] : e;
    setDragging({ color, x: touch.clientX, y: touch.clientY });
    setDraggingFrom(from);
  };

  React.useEffect(() => {
    if (!dragging) return;
    const onMove = (e) => {
      const touch = e.touches ? e.touches[0] : e;
      setDragging(d => d ? { ...d, x: touch.clientX, y: touch.clientY } : null);
      if (boardRef.current) {
        const rect = boardRef.current.getBoundingClientRect();
        const localX = touch.clientX - rect.left;
        const localY = touch.clientY - rect.top;
        const innerPad = 14;
        const cc = Math.floor((localX - innerPad) / (cellSize + gap));
        const rr = Math.floor((localY - innerPad) / (cellSize + gap));
        if (rr >= 0 && rr < GRID_H && cc >= 0 && cc < GRID_W) {
          setHoveredCell({ r: rr, c: cc });
        } else {
          setHoveredCell(null);
        }
      }
    };
    const onUp = () => {
      if (hoveredCell && dragging) {
        const placed = placeAt(hoveredCell.r, hoveredCell.c, dragging.color);
        if (placed) {
          if (draggingFrom === 'next') {
            const nextColor = COLOR_KEYS[Math.floor(Math.random() * 5)];
            setNext(nextColor);
          } else if (draggingFrom === 'hold') {
            setHold(null);
          }
          setMoves(m => Math.max(0, m - 1));
        }
      }
      setDragging(null);
      setDraggingFrom(null);
      setHoveredCell(null);
    };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('touchmove', onMove, { passive: false });
    window.addEventListener('mouseup', onUp);
    window.addEventListener('touchend', onUp);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('touchmove', onMove);
      window.removeEventListener('mouseup', onUp);
      window.removeEventListener('touchend', onUp);
    };
  }, [dragging, hoveredCell, draggingFrom, board, hold]);

  const swapHold = () => {
    const oldHold = hold;
    setHold(next);
    setNext(oldHold || COLOR_KEYS[Math.floor(Math.random() * 5)]);
  };

  const progressPct = Math.min(100, (oranges / target) * 100);

  return (
    <div className="screen-fade" style={{
      position: 'absolute', inset: 0,
      background: theme.bg,
      overflow: 'hidden',
    }}>
      {/* Top bar */}
      <div style={{ padding: '56px 14px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
          <button onClick={onBack} style={{
            width: 42, height: 42, borderRadius: '50%',
            background: theme.surface,
            border: `1px solid ${theme.surfaceBorder}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: theme.text,
            backdropFilter: 'blur(12px)',
            WebkitBackdropFilter: 'blur(12px)',
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
            cursor: 'pointer', flexShrink: 0,
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M15 6l-6 6 6 6" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
          <div className={`jm-logo alt-${font}`} style={{ fontSize: 32, flex: 1, textAlign: 'center' }}>JELLY MIX</div>
          <div style={{ width: 42, flexShrink: 0 }} />
        </div>

        <div style={{ marginTop: 12, display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <Pill theme={theme} gradient="linear-gradient(95deg, #ffae3a, #ff7a30)" style={{ fontSize: 14, padding: '8px 18px' }}>
              Mosse: {moves}
            </Pill>
            <Pill theme={theme} gradient={theme.accentGrad} style={{ fontSize: 12.5, padding: '8px 16px' }}>
              LVL {level} · Crea {target} Arancione ({oranges}/{target})
            </Pill>
          </div>
          <CoinPill coins={coins} theme={theme} big />
        </div>
      </div>

      {/* Next / Hold slots */}
      <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center', gap: 22 }}>
        <PieceSlot label="PROSSIMO" theme={theme}>
          {next && (
            <div
              onMouseDown={(e) => onDragStart(e, 'next', next)}
              onTouchStart={(e) => onDragStart(e, 'next', next)}
              className="cursor-grab"
              style={{ touchAction: 'none', opacity: dragging && draggingFrom === 'next' ? 0.3 : 1 }}
            >
              <JellyBlob color={next} size={52} shape="blob" idle />
            </div>
          )}
        </PieceSlot>
        <PieceSlot label="CONSERVA" theme={theme} onClick={!dragging && hold ? swapHold : undefined}>
          {hold && (
            <div
              onMouseDown={(e) => { e.stopPropagation(); onDragStart(e, 'hold', hold); }}
              onTouchStart={(e) => { e.stopPropagation(); onDragStart(e, 'hold', hold); }}
              className="cursor-grab"
              style={{ touchAction: 'none', opacity: dragging && draggingFrom === 'hold' ? 0.3 : 1 }}
            >
              <JellyBlob color={hold} size={52} shape="blob" idle />
            </div>
          )}
        </PieceSlot>
      </div>

      {/* Progress bar */}
      <div style={{ marginTop: 12, padding: '0 22px' }}>
        <div style={{
          height: 11, borderRadius: 999,
          background: theme.dark ? 'rgba(255,255,255,0.1)' : 'rgba(160,140,170,0.18)',
          overflow: 'hidden',
        }}>
          <div style={{
            width: `${progressPct}%`, height: '100%',
            background: theme.accentGrad, borderRadius: 999,
            transition: 'width 0.5s cubic-bezier(.3,1.3,.5,1)',
            boxShadow: '0 0 8px rgba(255,100,200,0.4)',
          }} />
        </div>
        <div style={{
          textAlign: 'center', marginTop: 6, fontSize: 13, fontWeight: 700,
          color: theme.accent1, letterSpacing: 1,
        }}>PUNTI: {score}</div>
      </div>

      {/* Board */}
      <div
        ref={boardRef}
        style={{
          margin: '8px 12px 0', padding: 14,
          borderRadius: 22,
          background: theme.surface,
          border: `1px solid ${theme.surfaceBorder}`,
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          position: 'relative',
        }}
      >
        <div style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${GRID_W}, ${cellSize}px)`,
          gridAutoRows: `${cellSize}px`,
          gap, justifyContent: 'center',
        }}>
          {board.map((row, r) => row.map((cell, c) => {
            const isHovered = hoveredCell && hoveredCell.r === r && hoveredCell.c === c;
            const isMerging = mergeAnim && mergeAnim.r === r && mergeAnim.c === c;
            const isShaking = shakeCell && shakeCell.r === r && shakeCell.c === c;
            return (
              <div
                key={`${r}-${c}`}
                style={{
                  width: cellSize, height: cellSize,
                  borderRadius: 13,
                  background: isHovered ? `${theme.accent1}30` : theme.boardCell,
                  border: isHovered ? `2px dashed ${theme.accent1}` : '2px solid transparent',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  position: 'relative',
                  transition: 'background 0.1s',
                }}
              >
                {cell && (
                  <div style={{
                    animation: isMerging ? 'mergeFlash 0.7s ease-out' :
                              isShaking ? 'shake 0.4s ease' : undefined,
                  }}>
                    <JellyBlob color={cell} size={cellSize - 6} shape="blob" idle />
                  </div>
                )}
                {floatScore && floatScore.r === r && floatScore.c === c && (
                  <div style={{
                    position: 'absolute',
                    fontWeight: 800, fontSize: 18,
                    color: theme.accent1, pointerEvents: 'none',
                    animation: 'rise 0.9s ease-out forwards',
                    textShadow: '0 1px 2px rgba(255,255,255,0.8)',
                  }}>{floatScore.value}</div>
                )}
              </div>
            );
          }))}
        </div>

        {sparkles.map(sp => (
          <Sparkle key={sp.id} x={sp.x + 14} y={sp.y + 14} color={sp.color} delay={sp.delay} />
        ))}

        {/* Power-ups */}
        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center', gap: 12 }}>
          {[
            { icon: '🔨', count: 2, color: '#ff6b6b' },
            { icon: '🔄', count: 0, color: '#3d8cff' },
            { icon: '🎨', count: 0, color: '#a35bff' },
          ].map((p, i) => (
            <button key={i} style={{
              width: 52, height: 56, borderRadius: 14,
              background: `${p.color}${p.count > 0 ? '30' : '15'}`,
              border: `1.5px solid ${p.color}${p.count > 0 ? '60' : '25'}`,
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
              gap: 2, cursor: p.count > 0 ? 'pointer' : 'default',
              opacity: p.count > 0 ? 1 : 0.55,
            }}>
              <div style={{ fontSize: 22 }}>{p.icon}</div>
              <div style={{ fontSize: 10, fontWeight: 700, color: p.color }}>×{p.count}</div>
            </button>
          ))}
        </div>
      </div>

      {/* Drag ghost */}
      {dragging && (
        <div style={{
          position: 'fixed',
          left: dragging.x, top: dragging.y,
          transform: 'translate(-50%, -50%) scale(1.15)',
          pointerEvents: 'none', zIndex: 200,
          filter: 'drop-shadow(0 8px 16px rgba(0,0,0,0.25))',
        }}>
          <JellyBlob color={dragging.color} size={56} shape="blob" idle={false} expression="wow" />
        </div>
      )}

      {showWin && <WinModal theme={theme} onContinue={() => { setShowWin(false); onWin(); }} coins={coins + 50} />}
    </div>
  );
}

function PieceSlot({ label, theme, children, onClick }) {
  return (
    <div onClick={onClick} style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
      cursor: onClick ? 'pointer' : 'default',
    }}>
      <div style={{ fontSize: 11, letterSpacing: 2, fontWeight: 600, color: theme.textMuted }}>{label}</div>
      <div style={{
        width: 76, height: 76,
        borderRadius: 18,
        background: theme.surface,
        border: `1.5px solid ${theme.surfaceBorder}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 4px 12px rgba(0,0,0,0.06), inset 0 1px 0 rgba(255,255,255,0.4)',
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
      }}>{children}</div>
    </div>
  );
}

function WinModal({ theme, onContinue, coins }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: 'rgba(20, 8, 35, 0.5)',
      backdropFilter: 'blur(6px)',
      WebkitBackdropFilter: 'blur(6px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: 150,
      animation: 'screenIn 0.3s ease',
    }}>
      <Confetti count={60} />
      <div style={{
        width: 290, padding: '28px 24px',
        borderRadius: 28,
        background: theme.bg,
        border: `1px solid ${theme.surfaceBorder}`,
        boxShadow: '0 20px 60px rgba(0,0,0,0.25)',
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14,
      }}>
        <div style={{ animation: 'jellyBob 1.5s infinite' }}>
          <JellyBlob color="orange" size={80} shape="blob" expression="wow" idle={false} />
        </div>
        <div className="jm-logo" style={{ fontSize: 32 }}>LIVELLO!</div>
        <div style={{ color: theme.textMuted, fontWeight: 500, fontSize: 14 }}>Hai completato il livello</div>
        <div style={{ display: 'flex', gap: 8 }}>
          {[0,1,2].map(i => (
            <svg key={i} width="38" height="38" viewBox="0 0 24 24" fill="#ffce5c" style={{
              animation: `pop 0.5s ${0.2 + i*0.15}s both`,
              filter: 'drop-shadow(0 2px 4px rgba(255,180,0,0.5))',
            }}>
              <path d="M12 2l3 6.5 7 1-5 5 1.2 7L12 18l-6.2 3.5L7 14.5l-5-5 7-1z" />
            </svg>
          ))}
        </div>
        <CoinPill coins={`+${coins}`} theme={theme} big />
        <button onClick={onContinue} style={{
          width: '100%', padding: '12px',
          borderRadius: 999,
          background: theme.accentGrad,
          color: '#fff', fontWeight: 700, fontSize: 16,
          border: 'none', cursor: 'pointer',
          boxShadow: '0 8px 20px rgba(180,60,200,0.35)',
        }}>Continua</button>
      </div>
    </div>
  );
}

Object.assign(window, { GameScreen, WinModal });
