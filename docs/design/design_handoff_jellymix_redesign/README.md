# Handoff: JellyMix Redesign

## Overview

This handoff documents a complete visual redesign + new feature ("Ruota Fortunata" / Daily Booster Wheel) for the **JellyMix** iOS game. It covers the existing screens (Splash, Mappa, Gioco, Negozio, Collezione) refreshed with a more polished candy aesthetic, plus one new screen (Eventi) with a spinning wheel mechanic.

## About the Design Files

The files in this bundle are **HTML design references** — React/JSX prototypes built to show the intended look, motion, and interactions. They are NOT production code to port directly.

The target app is built in **SwiftUI**. Your task is to **recreate these designs in SwiftUI** using the app's existing patterns (views, view models, design tokens, animation helpers). Treat the HTML as the source of truth for visuals/behavior, but implement everything natively. Reuse existing components where they already cover the spec; build new ones only where needed.

## Fidelity

**High-fidelity.** Final colors, typography, spacing, shadows, gradients, and motion timings are all defined. The prototype includes:

- 3 visual themes (Pastel Cream / Candy Sky / Berry Night) — Pastel Cream is the default and matches the current app most closely. Ship Pastel as the baseline; the other two can be skipped or implemented later as user-selectable themes.
- Working drag-and-drop on the game board
- Merge animations (flash + sparkles + floating score)
- Booster pack opening sequence
- Spinning wheel with easeOut + reveal modal
- Confetti, idle wobble, screen transitions

Replicate pixel-perfectly using Pastel Cream values unless explicitly told otherwise.

---

## Design Tokens

### Colors (Pastel Cream — default theme)

| Token | Hex | Use |
|---|---|---|
| `bg.start` | `#fff4e6` | Top of vertical gradient background |
| `bg.mid1` | `#ffe9ee` | 35% stop |
| `bg.mid2` | `#f7d9ec` | 70% stop |
| `bg.end` | `#f0e6f7` | Bottom of gradient |
| `surface` | `rgba(255,255,255,0.55)` | Glass card fill |
| `surfaceBorder` | `rgba(255,255,255,0.70)` | Glass card stroke |
| `navBg` | `rgba(255,255,255,0.70)` | Bottom-nav fill |
| `text` | `#3a2a3e` | Primary text |
| `textMuted` | `#8a7a8e` | Secondary text |
| `accent1` | `#a23ad6` (purple) | Logo gradient start, active states |
| `accent2` | `#ef3f6e` (pink) | Logo gradient end |
| `accentGrad` | `linear-gradient(95deg, #a23ad6, #ef3f6e)` | Primary CTA, active nav pill |
| `heart` | `#ef4458` | Lives indicator |
| `coin` | `#f4b13a` | Coin highlight |
| `pathColor` | `#f4a8b8` | Dotted map path |
| `boardCell` | `rgba(160,140,170,0.12)` | Empty game-board cell |

Background is applied as a vertical linear gradient across the four stops above.

### Jelly Colors

Each jelly has `base / light / dark / glow` for radial-gradient body, gloss highlight, and sparkle particles.

| Jelly | base | light | dark | glow |
|---|---|---|---|---|
| red | `#ff4d57` | `#ff8a91` | `#c91a26` | `#ffd1d5` |
| blue | `#3d8cff` | `#7eb3ff` | `#0d4fc7` | `#cfe1ff` |
| green | `#3dcb5e` | `#79e896` | `#168a32` | `#cfeed8` |
| yellow | `#ffd23a` | `#ffe27a` | `#c79a00` | `#fff1bf` |
| orange | `#ff8a2e` | `#ffb070` | `#c25800` | `#ffe0c2` |
| purple | `#a35bff` | `#c596ff` | `#6a23c9` | `#e2d2ff` |
| pink | `#ff5fb8` | `#ff96d1` | `#c92e85` | `#ffd2ec` |
| rainbow | conic-gradient(all hues) | `#fff` | `#888` | `#fff` |

Italian names (shown in Collezione): Rossa, Blu, Verde, Gialla, Arancione, Viola, Rosa, Arcobaleno.

### Typography

- **Primary / display**: `Fredoka`, weight 700 (logo, titles). Falls back to system rounded. Alternates exposed: `Baloo 2` and `Sniglet`.
- **UI text**: `Fredoka` 500/600 for buttons and labels, 400 for body.
- The logo "JELLY MIX" uses a 95° gradient text fill from `accent1` → `accent2` with a subtle 0 4px 0 rgba(0,0,0,0.04) drop shadow.
- Sizes: logo 42–56pt (varies per screen), titles 22–24pt, body 14–15pt, captions/labels 11–13pt, micro labels 9–11pt with 1–2pt letter spacing in UPPERCASE.

### Spacing

8-pt grid. Common values: 4, 6, 8, 10, 12, 14, 16, 18, 22, 28.

Card paddings: 18–22pt horizontal, 18–28pt vertical.
Card margins from screen edge: 14–18pt.
Section gaps: 16–22pt.

### Radii

| Element | Radius |
|---|---|
| Pills / CTAs | 999 (capsule) |
| Small chips | 8–12 |
| Power-up squares | 14 |
| Jelly thumbnails | 22 |
| Cards | 22–28 |
| Phone bezel | 54 (outer) / 44 (inner) |
| Jelly bodies | non-uniform border-radius `52% 48% 50% 50% / 54% 50% 50% 46%` (organic blob) |

### Shadows

- **Card lift**: `0 8px 28px rgba(180,60,200,0.15)`
- **Soft floating elements**: `0 4px 12px rgba(0,0,0,0.06)`
- **CTA primary**: `0 8px 22px rgba(180,60,200,0.40)`
- **CTA secondary (orange "Mosse")**: `0 6px 18px rgba(80,40,180,0.25)`
- **Bottom nav active pill**: `0 6px 16px rgba(180,60,200,0.35)`
- **Modal**: `0 20px 60px rgba(0,0,0,0.25)`
- **Jelly drop-shadow**: ellipse 12% opacity, blurred, beneath the jelly body
- **Inset gloss on jellies**: `inset 0 8% 12% rgba(255,255,255,0.4)` on top, `inset 0 -10% 10% rgba(0,0,0,0.12)` on bottom

### Glass / Blur

Glass surfaces use `backdrop-filter: blur(12px) saturate(180%)` over a `rgba(255,255,255,0.55)` fill, with a `1px solid rgba(255,255,255,0.70)` inner stroke and a 1px white inset highlight on top. In SwiftUI use `.background(.ultraThinMaterial)` or `.regularMaterial` over a tinted fill.

---

## Screens

All screens are 390×844 pt (iPhone 14/15 design canvas). Status bar 47pt tall, home indicator 34pt tall.

### 1. Splash

- **Purpose**: Brand reveal on app launch.
- **Background**: Pastel Cream vertical gradient.
- **Layout**: Centered vertical stack — hero jelly cluster, logo, tagline. 6 floating mini-jellies scattered in corners.
- **Hero cluster**: 3 overlapping jellies (red wow-face 82pt, green happy 76pt, blue wink 80pt) at hand-tuned positions, each with independent bob animation at slightly different durations (2.2s / 2.4s / 2.6s) and phase offsets.
- **Logo**: "JELLY MIX" 56pt Fredoka 700 with gradient text.
- **Tagline**: `FONDI · COMBINA · COLLEZIONA` — 13pt, 4pt letter-spacing, `textMuted`.
- **Loading dots**: 3 dots at the bottom, 56pt above safe area, alternating pop animation 1s with 0.15s stagger.
- **Timing**: phase 0 → 1 at 350ms (logo + cluster fade-in + scale 0.85 → 1, 0.6s ease-out cubic), phase 1 → 2 at 1.6s (tagline + dots fade in), auto-advance to Mappa at 2.6s. Tappable to skip.

### 2. Mappa (Map)

- **Purpose**: Browse worlds and pick a level.
- **Header (64pt top inset)**: 5 hearts pill (lives), then "JELLY MIX" logo 42pt.
- **World cards**: Stacked vertically, 14pt gap, 16pt side margins, 24pt radius.
  - Active world card (e.g. "Mondo Fragoloso"): full-color gradient background (`#ff5567` → 10% darker), white text, 56pt rounded square icon tile (`rgba(255,255,255,0.25)` background) with the world emoji at 32pt. Scale 1.02. Animated shine sweep (linear-gradient diagonal stripe) every 3.5s.
  - Future world card ("Scontri tra Agrumi" yellow `#ffc83a`): same style with yellow gradient.
  - Locked card: glass surface, muted text, lock emoji on the right.
- **Level path**: Below world cards, height 520pt, padding 0 60pt.
  - SVG dotted path zig-zags through 5 visible nodes (`d="M 75 60 Q 220 90, 220 160 T 75 260 T 220 360 T 75 460"`), 6pt stroke with `2 14` dash, `pathColor` color, 75% opacity.
  - Each level node: 64pt circle, white background, 3pt border, 0 4px 14px shadow + inset 0 -2px 4px shadow. Three states:
    - **Done**: white fill, gold star (24pt SVG)
    - **Current**: gradient fill (accentGrad), white star, 3pt white border, pulsing glow animation (2s). Label tab "LVL N" 28pt above the node.
    - **Locked**: white fill, muted gray lock icon
- **Bottom nav**: see Bottom Nav spec below.

### 3. Gioco (Game)

- **Purpose**: The core puzzle. Drag jellies onto a 5×6 grid; combine same-color and mix-color pairs to satisfy the level objective.
- **Top bar (56pt top inset, 14pt side padding)**:
  - Back button: 42pt circle, glass surface, chevron-left
  - Logo "JELLY MIX" 32pt centered
- **Stats row (12pt below)**:
  - Two stacked pills on the left: "Mosse: {n}" orange gradient (`#ffae3a` → `#ff7a30`), and "LVL {n} · Crea {target} {goalColor} ({progress}/{target})" purple-pink gradient. Both 12.5–14pt.
  - Right: large CoinPill showing current run coins
- **PROSSIMO / CONSERVA slots**: Two 76pt rounded squares (18pt radius, glass, 1.5pt border) with caption labels above (11pt, 2pt letter-spacing). PROSSIMO holds the next-up jelly to play; CONSERVA holds an optional held jelly. Tapping CONSERVA swaps with PROSSIMO. Both are draggable.
- **Progress bar**: 11pt tall, capsule, `boardCell` background, fill is `accentGrad` with 8px glow, animated width transition 0.5s cubic-bezier(.3,1.3,.5,1). "PUNTI: {score}" label 13pt 700 weight in `accent1` below.
- **Board**: 5×6 grid, 56pt cells, 8pt gap, padded 14pt inside a glass card. Cells have 13pt radius and `boardCell` fill. Hover/drop target shows accent-tinted fill + 2pt dashed accent border.
- **Power-ups row**: 3 buttons (Martello/Scambio/Pennello), 52×56pt, 14pt radius, tinted with each power-up's color at 30% alpha + 60% border alpha. Disabled (count=0) at 55% opacity. Emoji icon + "×N" label.

#### Merge Rules

When a jelly is dropped on a cell containing another jelly, attempt to merge:

| Existing + Dropped | Result |
|---|---|
| red + yellow (either order) | orange |
| blue + yellow | green |
| red + blue | purple |
| red + white | pink |
| rainbow + any color | any (becomes the non-rainbow color) |

If no rule matches, reject with a shake animation on the target cell (4 frames, 0.4s). If the cell is empty, place the dragged jelly.

On successful merge:
- Cell flashes (`mergeFlash` keyframe — 0.7s box-shadow expansion 0→24px+12 spread with the new color's `glow`, scale 1 → 1.15 → 1)
- 8 sparkle particles spawn within a 60pt radius of the cell center, each 4-pointed star, 12pt, animated `sparkle` 0.8s (rotate + drift up + scale to 0.3 + fade out). Sparkles staggered 0.04s.
- "+50" floating score rises from the cell, 18pt 800 weight in `accent1`, animation `rise` 0.9s (translateY -60pt + opacity → 0)
- Score += 50, coins += 5
- If the result matches the level goal color (e.g. orange), increment goal counter

If `progress >= target`: after 600ms show **Win Modal**.

#### Win Modal

- Full-screen overlay `rgba(20,8,35,0.5)` with 6pt backdrop blur
- 50–60 confetti pieces falling from top, mixed colors, 1.5–2.7s duration, random delay 0–0.4s, rotating 720°
- Centered card 290pt wide, 28pt radius, screen-background gradient fill
- Large orange jelly 80pt with wow expression, bobbing
- "LIVELLO!" logo 32pt
- "Hai completato il livello" 14pt textMuted
- 3 gold stars 38pt each, popping in with 0.15s stagger
- CoinPill showing total run coins
- "Continua" CTA: full-width capsule, accentGrad, 12pt vertical padding, white 700 16pt label

#### Drag Behavior

- Mouse-down or touch-start on a jelly captures pointer
- Floating "ghost" jelly follows pointer (size 56pt, scale 1.15, wow expression, drop-shadow `0 8px 16px rgba(0,0,0,0.25)`)
- Source slot becomes 30% opacity during drag
- Hovered cell highlights with dashed border
- On release: drop onto hovered cell, or cancel if outside board
- After successful place/merge: decrement `moves`, refill PROSSIMO with a random color (5 base colors weighted equally), clear CONSERVA if that was the source

In SwiftUI use `.gesture(DragGesture(minimumDistance: 0).onChanged/.onEnded)` with a hit-test against grid cell frames captured via `PreferenceKey`s.

### 4. Eventi (Events) — NEW

- **Purpose**: Daily reward via a wheel of fortune. Once-per-24h cooldown stored locally (`UserDefaults`).
- **Header**: 5 hearts pill + "EVENTI" logo 42pt.
- **Event card** (margin 16pt, padding 22pt 18pt 20pt, 28pt radius): Pastel pink→peach diagonal gradient `linear-gradient(160deg, rgba(255,180,220,0.55), rgba(255,200,140,0.35))`, glass blur, 1.5pt white-ish border.
  - Title "Ruota Fortunata" 24pt 700, gradient text.
  - Subtitle "Gira una volta al giorno per vincere un potenziamento gratis" 13pt textMuted, centered, max 280pt wide.
  - **Wheel** (see below) — 290×290pt.
  - **Action button**, full width:
    - When `canSpin`: "GIRA LA RUOTA!" 18pt 800, accentGrad fill, capsule, pulsing glow 2s
    - During spin: "STOP!" red gradient `#ff5567 → #ff3088`, faster pulse 0.6s
    - On cooldown: capsule with muted fill — small "PROSSIMO GIRO" caption + "{h}h {m}m" countdown 22pt 800 in `accent1`. Below it a small dev-reset link (remove in production).
- **Wheel** (290×290 container):
  - Outer 8pt ring with conic-gradient through accent1 → accent2 → accent1
  - Inner 6pt padded white (or `#1a0d2e` for dark theme) circle
  - 16 alternating bulbs around the ring (white / gold `#ffe35c`), 8pt circles with 6–8pt glow, staggered `pulseGlow` 1.4s
  - 8 segment SVG paths alternating `#ffe0ec` / `#ffd4ad`, 2pt white stroke
  - 8 prize "chips" overlaid: 48pt white circles with 2pt colored inset stroke (matching the prize's color), each containing the prize icon. Positioned via polar coords at radius 88 of 280pt viewBox. Each chip is rotated to face outward, with the icon counter-rotated to stay upright.
  - Center hub: 50pt circle, radial gradient `#fff7a0 → #ffae3a → #c97a00`, gold 5-pointed star icon inside.
  - Pointer (fixed at top, outside the rotating layer): 28×36pt SVG droplet shape filled with `accent1`, 2pt white stroke, with a 4pt white center dot. Drop shadow `0 3px 4px rgba(0,0,0,0.25)`.
- **Wheel rotation**:
  - Idle: 0deg
  - Spinning: requestAnimationFrame loop, 1.4°/ms (~1400°/s)
  - On STOP: cancel the rAF, compute final angle so the chosen segment's center aligns with the pointer (which sits at 0° / top). Add 4 extra full spins (1440°) so it always overshoots. Transition the final rotation via 4500ms `cubic-bezier(.15,.85,.25,1)` (strong easeOut).
- **Prize reveal modal** (after the easeOut completes):
  - Same overlay style as Win Modal but with 50-piece confetti
  - 280pt card, 28pt radius
  - "HAI VINTO" eyebrow 13pt 700 with 2pt letter-spacing in textMuted
  - 110pt halo circle with radial gradient using the prize's color at 40% alpha, fading to transparent
  - Inside the halo: 84pt white circle with 3pt colored inset stroke, prize icon at 50pt, jellyBob animation 1.4s
  - Prize label using the logo gradient style, 28pt
  - "+{amount} {unit}" chip — pill, color@20%-alpha background, color-tinted text, 700 13pt
  - "Fantastico!" CTA — accentGrad capsule
- **Cooldown persistence**: Store `Date()` of last spin in UserDefaults under key `jellymix-last-spin`. `canSpin = Date().timeIntervalSince(last) >= 24*60*60`.

#### Wheel Prizes (8)

| idx | id | label (it) | icon | color | amount |
|---|---|---|---|---|---|
| 0 | hammer | Martello | 🔨 (or hammer SF symbol) | `#ff6b6b` | 1 |
| 1 | coins | 50 Monete | gold coin | `#ffb31a` | 50 |
| 2 | swap | Scambio | 🔄 | `#3d8cff` | 1 |
| 3 | jelly | Jelly Rara | rainbow jelly | `#a35bff` | 1 |
| 4 | brush | Pennello | 🎨 | `#c84ad6` | 1 |
| 5 | coins-big | 200 Monete | gold coin | `#ffce5c` | 200 |
| 6 | life | Vita Extra | ❤️ | `#ff4d80` | 1 |
| 7 | star | Stella Bonus | ⭐ | `#6ec8ff` | 1 |

Selection is uniform-random in the prototype. Replace with weighted probabilities (rare prizes less common) for production.

- **Next events teaser card** (below the wheel card): muted glass card listing future events:
  - 🏆 "Sfida Settimanale" — Termina tra 4 giorni — PRESTO badge
  - ✨ "Mondo Bonus" — Disponibile sabato — PRESTO badge

### 5. Negozio (Shop)

- **Purpose**: Buy boosters and gacha packs with coins.
- **Header**: hearts pill, then "NEGOZIO" logo + CoinPill (current balance) side by side.
- **Pack card** (22pt margin, 28pt radius, pink↔purple soft gradient background, glass):
  - 4 decorative twinkles in the corners (pop animation, 1.6s alternate)
  - **Pack visual**: 110×130pt rounded box (22pt radius) with accent gradient fill, "BUSTINA" top band (30pt tall, dashed-bottom-bordered 25%-alpha white stripe), wow-face pink jelly peeking out the bottom. Idle: `float` 3s. While opening: `packShake` 0.18s loop. On burst: scale to 1.4 + fade to 0 over 0.4s.
  - Title "Bustina di Gelatine" 22pt 700 gradient text
  - Subtitle "3 carte casuali, incluse le rare!" 13.5pt textMuted
  - CTA "Apri Bustina — 100 [coin]" — blue-purple gradient capsule when affordable; muted otherwise.
- **Pack opening sequence**:
  - 0–900ms: shake
  - 900–1300ms: burst (pack scales/fades)
  - At 1300ms: show reveal modal with 3 cards
- **Reveal modal**: full overlay, 40 confetti pieces, 3 cards (84×108pt, 16pt radius, white) appearing with `cardReveal` 0.6s with 0.18s stagger — rotates from rotateY(180) translateY(40) scale(0.5) to identity. Each card shows a jelly (52pt) and its Italian name. CTA "Tocca per continuare".
- **Potenziamenti list** (below pack card):
  - Section title "Potenziamenti" 20pt gradient text, centered
  - 3 rows (Martello/Scambio/Pennello), each 16pt radius, white-translucent fill, 8pt gap between rows
  - Row layout: 44pt colored tinted icon square + name (15pt 700) + sub ("{description} · Posseduti: {n}", 11pt muted) + price capsule on the right (accentGrad if affordable, muted otherwise, "{price} [coin]")
  - Buying decrements coin balance and increments the owned count for that booster.

### 6. Collezione (Collection)

- **Purpose**: Browse all unlockable jelly types.
- **Header**: hearts, "COLLEZIONE" logo, "{owned}/{total} sbloccate" counter.
- **Grid**: 3 columns, 16pt gap, 20pt side margin.
- **Tile**:
  - 86pt rounded square (22pt radius), glass background
  - 58pt jelly inside (blob shape, idle wobble if owned)
  - If unowned: jelly is grayscaled (80%) + 55% opacity + brightness 0.85; a small 22pt lock badge sits at bottom-right of the tile
  - Label below: "{name}" 12.5pt 700 in `accent1` if owned, "???" in `textMuted` otherwise

### Bottom Nav (Mappa / Eventi / Negozio / Collezione)

- Fixed at bottom, 16pt margins from screen edges
- Capsule shape, 6pt internal padding, glass fill, 1pt border
- 4 equal-flex tabs. Active tab fills with `accentGrad` and lifts (shadow `0 6px 16px rgba(180,60,200,0.35)`, scale 1; inactive scales 0.96)
- Each tab: 20pt SVG icon stacked above 8.5pt 800-weight label with 0.6pt letter-spacing
- Active text white, inactive text `textMuted`
- Smooth 0.2s transition between states

Icons (use SF Symbols equivalents in SwiftUI):
- Mappa: map / folded-paper icon
- Eventi: target / wheel (circle with cross)
- Negozio: shopping bag
- Collezione: open book / two pages

---

## Components Inventory

| Component | Description |
|---|---|
| `JellyBlob` | Organic blob avatar with radial-gradient body, gloss highlight, specular dot, drop shadow, eyes (sclera + iris + pupil), mouth (SVG path: smile / sad / wow / wink / sleepy), cheek blush. Idle animation: `jellyIdle` scale wobble 2.8–4s. Bob variant: `jellyBob` translateY ±4pt + rotate ±1°. Faded/locked/empty variants. |
| `HeartRow` | 5 hearts in a glass capsule. Empty hearts are grayscaled 80% + 35% opacity. |
| `Coin` | Radial-gradient gold coin SVG with "$" centered. |
| `CoinPill` | Coin + number in a gold gradient capsule (or dark-glass capsule in dark theme). |
| `Pill` | Generic capsule with optional gradient fill. |
| `Confetti` | 30–60 randomly-positioned colored rectangles falling top→bottom with rotation, 1.5–2.7s. |
| `Sparkle` | 4-pointed-star SVG, 12pt, rises and rotates with fade-out. |
| `BottomNav` | 4-tab capsule. See spec above. |
| `WorldCard` | Map world card. |
| `LevelNode` | Map level dot (done/current/locked). |
| `PieceSlot` | PROSSIMO / CONSERVA slot. |
| `WinModal` | Level-complete celebration. |
| `Wheel` | Wheel of fortune. |
| `PrizeReveal` | Wheel prize modal. |

In SwiftUI, model JellyBlob as a reusable view with a `JellyColor` enum and a `JellyShape` `Shape` for the organic border-radius (use a custom path; the CSS uses `border-radius: 52% 48% 50% 50% / 54% 50% 50% 46%` which translates to an asymmetric superellipse — a `Path` with cubic curves is fine).

---

## Animations & Motion

| Keyframe | Use | Duration | Easing |
|---|---|---|---|
| `screenIn` | Screen mount fade-in | 0.35s | cubic-bezier(.2,.9,.3,1.2) |
| `jellyIdle` | Body wobble | 2.8–4s | ease-in-out, infinite |
| `jellyBob` | Up-down bob | 2.2–2.6s | ease-in-out, infinite |
| `blink` | Eye blink | 3–5s | random, infinite |
| `sparkle` | Sparkle particle | 0.8s | ease-out, forwards |
| `pop` | Star / dot bounce | 0.5–1s | various |
| `mergeFlash` | Cell merge | 0.7s | ease-out |
| `shake` | Reject placement | 0.4s | ease |
| `confettiFall` | Confetti | 1.5–2.7s | ease-in, forwards |
| `pulseGlow` | Pulsing ring on active CTA / nodes | 0.6–2s | infinite |
| `packShake` | Pack pre-open | 0.18s | infinite |
| `cardReveal` | Pack card flip-in | 0.6s | cubic-bezier(.3,1.4,.5,1) |
| `float` | Decorative idle | 3s + | ease-in-out, infinite |
| `rise` | Floating "+50" | 0.9s | ease-out, forwards |
| `shine` | Sweep across world card | 3.5s | infinite |

In SwiftUI use `.animation(.easeInOut(duration:).repeatForever(autoreverses:))` for idle loops, `.spring()` for the pop/bounce, and `withAnimation` blocks for triggered transitions.

---

## State Model (suggested)

```
GameState
  - lives: Int (0…5)
  - coins: Int
  - currentLevel: Int
  - currentWorld: WorldId
  - unlockedJellies: Set<JellyColor>
  - boosters: [BoosterId: Int]   // owned counts
  - lastSpinDate: Date?           // for the wheel cooldown
  - lastSpinPrize: Prize?         // for re-display if interrupted

LevelState  (per-game-session)
  - board: [[JellyColor?]]        // 5×6
  - moves: Int
  - score: Int
  - sessionCoins: Int
  - next: JellyColor
  - hold: JellyColor?
  - goalProgress: Int
  - goalTarget: Int
  - goalColor: JellyColor
```

Persist `GameState` to `UserDefaults` (or a small SwiftData model if the app already uses one). `LevelState` lives only for the duration of a game.

---

## Italian Copy (final)

- Splash tagline: `FONDI · COMBINA · COLLEZIONA`
- Worlds: `Mondo Fragoloso` · `Scontri tra Agrumi` · `Foresta Gommosa` · `Oceano di Gelatina`
- Game stats: `Mosse: {n}` · `LVL {n} · Crea {target} {color} ({n}/{target})` · `PUNTI: {n}`
- Power-ups: `Martello` · `Scambio` · `Pennello`
- Shop: `Bustina di Gelatine` · `3 carte casuali, incluse le rare!` · `Apri Bustina — 100` · `Potenziamenti` · `Posseduti: {n}` · `Tocca per continuare` · `Nuove Jelly!`
- Events: `EVENTI` · `Ruota Fortunata` · `Gira una volta al giorno per vincere un potenziamento gratis` · `GIRA LA RUOTA!` · `STOP!` · `PROSSIMO GIRO` · `HAI VINTO` · `Fantastico!` · `Sfida Settimanale` · `Mondo Bonus` · `PRESTO`
- Win: `LIVELLO!` · `Hai completato il livello` · `Continua`
- Collection: `COLLEZIONE` · `{n} / {total} sbloccate` · `???` for locked entries
- Jelly names: `Rossa` · `Blu` · `Verde` · `Gialla` · `Arancione` · `Viola` · `Rosa` · `Arcobaleno`
- Nav labels (uppercase 8.5pt): `MAPPA` · `EVENTI` · `NEGOZIO` · `COLLEZIONE`

---

## Assets

No bitmap assets are required — everything is vector / SF Symbols / emoji / native CSS gradients. For SwiftUI:

- **Logo**: render as `Text("JELLY MIX")` with `.font(.custom("Fredoka-Bold", size:))` and a `.foregroundStyle(LinearGradient(...))`. Bundle Fredoka (and optionally Baloo 2 / Sniglet) as a font asset.
- **Jelly bodies**: drawn natively — `RadialGradient` for the body fill, `BlurView` or `Color` overlays for gloss, `Circle`s for eyes/pupils, a `Path` for the mouth.
- **Coin**: `Circle` with `RadialGradient`, `Text("$")` centered, `Color` stroke.
- **Lock / power-up icons**: SF Symbols are fine (`lock.fill`, `hammer.fill`, `arrow.left.arrow.right`, `paintbrush.fill`, `heart.fill`, `star.fill`, etc.) — match the colors specified above.
- **World emojis**: native emoji are used directly in the prototype (🍓🍋🌳🌊). Keep emoji or replace with custom illustrations later.

---

## Files in this bundle

- `index.html` — entry point that loads scripts in order
- `styles.css` — keyframes + utility classes
- `themes.js` — color palettes + jelly color table
- `jelly.jsx` — JellyBlob + Sparkle components
- `screens-shared.jsx` — HeartRow, Coin, CoinPill, Pill, Confetti
- `screens-splash-map.jsx` — Splash + Map
- `screens-game.jsx` — Game board + Win modal
- `screens-shop-collection.jsx` — Shop + Collection + BottomNav
- `screens-events.jsx` — Events screen + Wheel + PrizeReveal
- `app.jsx` — App router, theme switching, phone frame
- `tweaks-panel.jsx` — Development-only tweak panel (not part of the final design)

To run the prototype: open `index.html` in a browser.

---

## Notes for the SwiftUI implementer

1. **Don't lift HTML/CSS verbatim.** Use this doc as the source of truth and the HTML as a visual reference. Build everything as composable SwiftUI views.
2. **Drag-and-drop**: use `DragGesture` + a `GeometryReader`-captured cell-frame dictionary, not the system `.onDrag/.onDrop` (which is overkill here and doesn't animate nicely).
3. **Wheel rotation**: SwiftUI handles this cleanly with `.rotationEffect(.degrees(rotation)).animation(.timingCurve(.15,.85,.25,1, duration: 4.5), value: rotation)`. For the fast-spin phase, use a `Timer` or a `TimelineView` driving the rotation value at ~1400°/s, and switch to the final target on STOP.
4. **Glass surfaces**: prefer `.background(.ultraThinMaterial)` over manual blur for performance.
5. **Cooldown timer**: use a `Timer.publish(every: 1, on: .main, in: .common)` source to refresh the countdown label every second while on the Events screen.
6. **Confetti**: spawn 50–60 `Rectangle`s with random initial positions and offsets, animate offset/rotation/opacity with `.animation`. They auto-remove when they leave the screen.
7. **Persistence**: `@AppStorage("jellymix-last-spin")` for the wheel cooldown (store as `TimeInterval`).
8. **Theming**: define a `Theme` struct with all the tokens above; expose via `EnvironmentValues` so future palette swaps are trivial.
9. **Bottom nav**: each tab's active state animates with a `matchedGeometryEffect` so the gradient pill slides between tabs (current prototype only fades; the SwiftUI version can be more refined).

Ask if anything is ambiguous before guessing — the design is opinionated and small misses (especially in spacing and easing) will be noticeable.
