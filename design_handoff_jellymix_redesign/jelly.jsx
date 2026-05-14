// Jelly blob component — organic, glossy, animated

function JellyBlob({
  color = 'red',         // key in JELLY_COLORS, or full color object
  shape = 'blob',        // 'blob' | 'rounded' | 'organic'
  size = 56,
  expression = 'happy',  // 'happy' | 'sleepy' | 'wow' | 'wink' | 'sad'
  idle = true,
  bob = false,
  locked = false,
  empty = false,
  faded = false,
  style = {},
  onClick,
}) {
  const c = typeof color === 'string' ? window.JELLY_COLORS[color] : color;
  if (!c) return null;

  // Generate unique gradient id
  const idRef = React.useRef('jb' + Math.random().toString(36).slice(2, 9));
  const id = idRef.current;

  // Border-radius for different shapes
  const radii = {
    rounded: '28% / 28%',
    blob: '52% 48% 50% 50% / 54% 50% 50% 46%',
    organic: '60% 40% 55% 45% / 50% 60% 40% 50%',
  };

  // SVG clip path or border-radius
  const radius = radii[shape] || radii.blob;

  const isRainbow = color === 'rainbow';

  // Background
  let bg;
  if (isRainbow) {
    bg = c.base;
  } else {
    bg = `radial-gradient(circle at 30% 25%, ${c.light} 0%, ${c.base} 40%, ${c.dark} 100%)`;
  }

  // Eye positions vary slightly by shape
  const eyeY = size * 0.34;
  const eyeSpacing = size * 0.26;
  const eyeSize = size * 0.18;

  // Expression styles
  const eyeStyle = (side) => {
    const base = {
      position: 'absolute',
      width: eyeSize,
      height: eyeSize,
      borderRadius: '50%',
      background: '#fff',
      top: eyeY,
      [side]: size * 0.22,
      boxShadow: 'inset 0 -1px 1px rgba(0,0,0,0.05)',
      animation: idle ? `blink ${3 + Math.random() * 2}s infinite` : undefined,
      transformOrigin: 'center',
    };
    return base;
  };

  const pupilStyle = (side) => ({
    position: 'absolute',
    width: eyeSize * 0.55,
    height: eyeSize * 0.55,
    borderRadius: '50%',
    background: '#1a1620',
    top: eyeY + eyeSize * 0.22,
    [side]: size * 0.22 + eyeSize * 0.22,
  });

  // Mouth — small smile (SVG for accuracy)
  const mouthWidth = size * 0.32;
  const mouthY = size * 0.62;

  let mouthPath = `M 0,0 Q ${mouthWidth/2},${size*0.1} ${mouthWidth},0`;
  if (expression === 'sad') mouthPath = `M 0,${size*0.08} Q ${mouthWidth/2},-${size*0.04} ${mouthWidth},${size*0.08}`;
  if (expression === 'wow') mouthPath = `M ${mouthWidth/2},0 A ${size*0.07},${size*0.08} 0 1,0 ${mouthWidth/2+0.01},0`;

  const idleAnim = idle ? `jellyIdle ${2.8 + Math.random() * 1.2}s ease-in-out infinite` :
                   bob ? `jellyBob 2.4s ease-in-out infinite` : 'none';

  if (empty) {
    return (
      <div onClick={onClick} style={{
        width: size, height: size,
        borderRadius: radius,
        background: 'rgba(160,140,170,0.12)',
        ...style,
      }} />
    );
  }

  return (
    <div
      onClick={onClick}
      className="no-select"
      style={{
        width: size,
        height: size,
        position: 'relative',
        filter: faded ? 'grayscale(80%) brightness(0.85) opacity(0.55)' : undefined,
        animation: idleAnim,
        transformOrigin: 'center bottom',
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}
    >
      {/* Drop shadow */}
      <div style={{
        position: 'absolute',
        bottom: -size * 0.08,
        left: size * 0.12,
        right: size * 0.12,
        height: size * 0.12,
        borderRadius: '50%',
        background: 'rgba(0,0,0,0.15)',
        filter: 'blur(4px)',
        zIndex: 0,
      }} />

      {/* Body */}
      <div style={{
        position: 'absolute',
        inset: 0,
        borderRadius: radius,
        background: bg,
        boxShadow: `
          inset 0 ${size * 0.08}px ${size * 0.12}px rgba(255,255,255,0.4),
          inset 0 -${size * 0.1}px ${size * 0.1}px rgba(0,0,0,0.12),
          0 ${size * 0.04}px ${size * 0.08}px rgba(0,0,0,0.08)
        `,
        zIndex: 1,
      }}>
        {/* Gloss highlight */}
        <div style={{
          position: 'absolute',
          top: size * 0.08,
          left: size * 0.18,
          width: size * 0.32,
          height: size * 0.2,
          borderRadius: '50%',
          background: 'radial-gradient(ellipse at center, rgba(255,255,255,0.85) 0%, rgba(255,255,255,0) 70%)',
          pointerEvents: 'none',
        }} />
        {/* Small specular dot */}
        <div style={{
          position: 'absolute',
          top: size * 0.13,
          left: size * 0.22,
          width: size * 0.1,
          height: size * 0.06,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.95)',
          filter: 'blur(0.5px)',
          pointerEvents: 'none',
        }} />
      </div>

      {/* Face */}
      {!locked && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 2 }}>
          {expression !== 'sleepy' && (
            <>
              <div style={eyeStyle('left')}>
                <div style={{
                  position: 'absolute', top: '22%', left: '22%',
                  width: '55%', height: '55%',
                  borderRadius: '50%', background: '#1a1620',
                }}>
                  <div style={{
                    position: 'absolute', top: '15%', left: '15%',
                    width: '35%', height: '35%',
                    borderRadius: '50%', background: '#fff',
                  }} />
                </div>
              </div>
              <div style={eyeStyle('right')}>
                <div style={{
                  position: 'absolute', top: '22%', left: '22%',
                  width: '55%', height: '55%',
                  borderRadius: '50%', background: '#1a1620',
                }}>
                  <div style={{
                    position: 'absolute', top: '15%', left: '15%',
                    width: '35%', height: '35%',
                    borderRadius: '50%', background: '#fff',
                  }} />
                </div>
              </div>
            </>
          )}
          {expression === 'sleepy' && (
            <>
              <div style={{
                position: 'absolute', top: eyeY + eyeSize * 0.4,
                left: size * 0.22, width: eyeSize, height: 2,
                background: '#1a1620', borderRadius: 2,
              }} />
              <div style={{
                position: 'absolute', top: eyeY + eyeSize * 0.4,
                right: size * 0.22, width: eyeSize, height: 2,
                background: '#1a1620', borderRadius: 2,
              }} />
            </>
          )}
          {expression === 'wink' && (
            <div style={{
              position: 'absolute', top: eyeY + eyeSize * 0.4,
              right: size * 0.22, width: eyeSize, height: 3,
              background: '#1a1620', borderRadius: 2,
            }} />
          )}

          {/* Mouth */}
          <svg
            width={mouthWidth}
            height={size * 0.15}
            style={{
              position: 'absolute',
              left: '50%',
              top: mouthY,
              transform: 'translateX(-50%)',
            }}
            viewBox={`-2 -2 ${mouthWidth + 4} ${size * 0.15 + 4}`}
            overflow="visible"
          >
            <path
              d={mouthPath}
              fill={expression === 'wow' ? '#3a1a2e' : 'none'}
              stroke="#1a1620"
              strokeWidth={Math.max(1.6, size * 0.038)}
              strokeLinecap="round"
            />
          </svg>

          {/* Cheek blush */}
          <div style={{
            position: 'absolute',
            top: size * 0.55,
            left: size * 0.1,
            width: size * 0.16,
            height: size * 0.1,
            borderRadius: '50%',
            background: 'rgba(255,150,180,0.4)',
            filter: 'blur(2px)',
          }} />
          <div style={{
            position: 'absolute',
            top: size * 0.55,
            right: size * 0.1,
            width: size * 0.16,
            height: size * 0.1,
            borderRadius: '50%',
            background: 'rgba(255,150,180,0.4)',
            filter: 'blur(2px)',
          }} />
        </div>
      )}

      {locked && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 2,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'rgba(0,0,0,0.4)', fontSize: size * 0.32,
        }}>?</div>
      )}
    </div>
  );
}

// Sparkle particle (used during merges)
function Sparkle({ x, y, color = '#fff', delay = 0 }) {
  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      width: 12, height: 12,
      pointerEvents: 'none',
      animation: `sparkle 0.8s ${delay}s ease-out forwards`,
    }}>
      <svg viewBox="0 0 12 12" width="12" height="12">
        <path d="M6 0 L7 5 L12 6 L7 7 L6 12 L5 7 L0 6 L5 5 Z" fill={color} />
      </svg>
    </div>
  );
}

window.JellyBlob = JellyBlob;
window.Sparkle = Sparkle;
