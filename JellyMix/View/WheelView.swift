//
//  WheelView.swift
//  JellyMix
//

import SwiftUI

// MARK: - Wheel geometry helpers

private let prizes = WheelPrize.all
private let segCount = prizes.count             // 8
private let segDeg   = 360.0 / Double(segCount) // 45°
private let svgSize  = 280.0                    // coordinate space
private let cx       = 140.0
private let cy       = 140.0
private let segRadius = 130.0
private let chipRadius = 88.0                   // distance of prize chips from center

/// Polar → Cartesian in SVG coordinate space
private func polar(_ angleDeg: Double, _ dist: Double) -> CGPoint {
    let rad = (angleDeg - 90) * .pi / 180
    return CGPoint(x: cx + dist * cos(rad), y: cy + dist * sin(rad))
}

// MARK: - Segment path

private struct SegmentShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / svgSize
        let a0 = Double(index) * segDeg
        let a1 = a0 + segDeg
        let p0 = polar(a0, segRadius)
        let center = CGPoint(x: cx, y: cy)

        var path = Path()
        path.move(to: center * scale)
        path.addLine(to: p0 * scale)
        path.addArc(
            center: center * scale,
            radius: segRadius * scale,
            startAngle: .degrees(a0 - 90),
            endAngle: .degrees(a1 - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Prize chip overlay (rotates with the wheel)

private struct PrizeChipsLayer: View {
    let size: CGFloat   // rendered pt (290)

    var body: some View {
        ZStack {
            ForEach(Array(prizes.enumerated()), id: \.offset) { i, prize in
                let angle = Double(i) * segDeg + (segDeg / 2)
                let pos   = polar(angle, chipRadius)
                let scale = size / svgSize

                PrizeChipView(prize: prize, chipSize: 42)
                    // counter-rotate so the icon stays upright while the wheel spins
                    .rotationEffect(.degrees(angle))
                    .position(x: pos.x * scale, y: pos.y * scale)
            }
        }
    }
}

private struct PrizeChipView: View {
    let prize: WheelPrize
    let chipSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(prize.color, lineWidth: 2))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Image(systemName: prize.icon)
                .font(.system(size: chipSize * 0.38, weight: .semibold))
                .foregroundColor(prize.color)
        }
        .frame(width: chipSize, height: chipSize)
    }
}

// MARK: - Bulbs ring (fixed, outside rotating layer)

private struct BulbsRingLayer: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                let angle = (Double(i) / 16.0) * 360.0
                let pos   = polar(angle, segRadius - 4)
                let scale = size / svgSize
                let isGold = i % 2 != 0

                BulbView(isGold: isGold, index: i)
                    .position(x: pos.x * scale, y: pos.y * scale)
            }
        }
    }
}

private struct BulbView: View {
    let isGold: Bool
    let index: Int
    @State private var glowing = false

    var body: some View {
        Circle()
            .fill(isGold ? Color(hex: "#ffe35c") : Color.white)
            .frame(width: 8, height: 8)
            .shadow(
                color: isGold
                    ? Color(hex: "#ffc800").opacity(glowing ? 0.9 : 0.4)
                    : Color.white.opacity(glowing ? 0.9 : 0.4),
                radius: glowing ? 5 : 2
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.08)
                ) { glowing = true }
            }
    }
}

// MARK: - Center hub

private struct CenterHub: View {
    let size: CGFloat
    let spinning: Bool
    @State private var wobble = false

    private let hubSize: CGFloat = 50

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#fff7a0"), Color(hex: "#ffae3a"), Color(hex: "#c97a00")],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: hubSize / 2
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                .shadow(color: Color(hex: "#b46400").opacity(0.4), radius: 6, y: 3)
                .frame(width: hubSize, height: hubSize)

            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(wobble ? 1.08 : 0.95)
        }
        .frame(width: size / svgSize * 60, height: size / svgSize * 60)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                wobble = true
            }
        }
    }
}

// MARK: - Pointer

private struct PointerView: View {
    var body: some View {
        ZStack {
            // Droplet shape: teardrop pointing down
            Path { path in
                // 28×36 viewBox, tip at bottom center
                path.move(to: CGPoint(x: 14, y: 36))
                path.addCurve(to: CGPoint(x: 4, y: 8),
                              control1: CGPoint(x: 14, y: 30),
                              control2: CGPoint(x: 4, y: 18))
                path.addQuadCurve(to: CGPoint(x: 14, y: 0),
                                  control: CGPoint(x: 4, y: 0))
                path.addQuadCurve(to: CGPoint(x: 24, y: 8),
                                  control: CGPoint(x: 24, y: 0))
                path.addCurve(to: CGPoint(x: 14, y: 36),
                              control1: CGPoint(x: 24, y: 18),
                              control2: CGPoint(x: 14, y: 30))
            }
            .fill(Color(hex: "#a23ad6"))
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 14, y: 36))
                    path.addCurve(to: CGPoint(x: 4, y: 8),
                                  control1: CGPoint(x: 14, y: 30),
                                  control2: CGPoint(x: 4, y: 18))
                    path.addQuadCurve(to: CGPoint(x: 14, y: 0),
                                      control: CGPoint(x: 4, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 24, y: 8),
                                      control: CGPoint(x: 24, y: 0))
                    path.addCurve(to: CGPoint(x: 14, y: 36),
                                  control1: CGPoint(x: 24, y: 18),
                                  control2: CGPoint(x: 14, y: 30))
                }
                .stroke(Color.white, lineWidth: 2)
            )

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .offset(y: -27)     // near top of the 36pt shape
        }
        .frame(width: 28, height: 36)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }
}

// MARK: - WheelView (public)

struct WheelView: View {
    let rotation: Double
    let spinning: Bool

    private let size: CGFloat = 290
    private let outerRingPad: CGFloat = 8
    private let innerPad: CGFloat = 6
    private let fillA = Color(hex: "#ffe0ec")
    private let fillB = Color(hex: "#ffd4ad")

    var body: some View {
        ZStack(alignment: .top) {
            // ── Outer ring + inner disc ──────────────────────────────────────
            Circle()
                .fill(
                    AngularGradient(
                        colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e"), Color(hex: "#a23ad6")],
                        center: .center
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(outerRingPad)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .padding(outerRingPad)
                        )
                )

            // ── Bulbs (fixed — outside rotating layer) ──────────────────────
            BulbsRingLayer(size: size)
                .frame(width: size, height: size)

            // ── Rotating wheel ───────────────────────────────────────────────
            ZStack {
                // Segments
                ForEach(0..<segCount, id: \.self) { i in
                    SegmentShape(index: i)
                        .fill(i % 2 == 0 ? fillA : fillB)
                    SegmentShape(index: i)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                }

                // Inner white ring (hides segment tips near center)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 2))
                    .frame(width: size / svgSize * 84, height: size / svgSize * 84)

                // Prize chips
                PrizeChipsLayer(size: size)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            // Fast spin: no SwiftUI animation (driven by Timer)
            // Deceleration: animated via withAnimation in ViewModel

            // ── Center hub (fixed above rotating layer) ──────────────────────
            CenterHub(size: size, spinning: spinning)
                .frame(width: size, height: size)

            // ── Pointer (fixed at top) ────────────────────────────────────────
            PointerView()
                .offset(y: -(36 / 2) + 4)      // sits just above the ring edge
        }
        .frame(width: size, height: size + 14)  // +14 for pointer overhang
        .shadow(color: Color(hex: "#b43cc8").opacity(0.3), radius: 20, y: 10)
    }
}

#Preview {
    WheelView(rotation: 0, spinning: false)
}

// MARK: - CGPoint helpers

private extension CGPoint {
    static func * (lhs: CGPoint, rhs: Double) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}
