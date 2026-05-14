//
//  PrizeRevealView.swift
//  JellyMix
//

import SwiftUI

// MARK: - Prize icon

private struct PrizeIconView: View {
    let prize: WheelPrize
    let size: CGFloat

    var body: some View {
        if prize.id == .coins || prize.id == .coinsBig {
            // Gold coin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#fff4a0"), Color(hex: "#ffb31a"), Color(hex: "#c97a00")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .overlay(
                    Text("$")
                        .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                )
                .frame(width: size, height: size)
        } else {
            Image(systemName: prize.icon)
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundColor(prize.color)
        }
    }
}

// MARK: - PrizeRevealView

struct PrizeRevealView: View {
    let prize: WheelPrize
    let onClose: () -> Void

    @State private var cardScale: Double = 0.7
    @State private var iconBob = false

    private var unitLabel: String {
        switch prize.id {
        case .coins, .coinsBig: return "Monete"
        case .life:             return "Vita"
        default:                return "Bonus"
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .blur(radius: 4)

            // Confetti
            ZStack {
                ForEach(0..<50, id: \.self) { i in
                    ConfettiPiece(
                        color: confettiColors[i % confettiColors.count],
                        x: CGFloat((i * 37) % 340) - 170,
                        delay: Double(i % 10) * 0.04,
                        duration: Double.random(in: 1.5...2.7),
                        rotation: Double(i * 27)
                    )
                }
            }
            .allowsHitTesting(false)

            // Card
            VStack(spacing: 14) {

                // Eyebrow
                Text("HAI VINTO")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#8a7a8e"))
                    .kerning(2)

                // Halo + icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [prize.color.opacity(0.4), prize.color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 55
                            )
                        )
                        .frame(width: 110, height: 110)

                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(prize.color, lineWidth: 3))
                        .shadow(color: prize.color.opacity(0.4), radius: 12, y: 4)
                        .frame(width: 84, height: 84)
                        .overlay(PrizeIconView(prize: prize, size: 50))
                }
                .scaleEffect(cardScale)
                .offset(y: iconBob ? -4 : 4)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: iconBob)

                // Label
                Text(prize.label)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                // Amount chip
                Text("+\(prize.amount) \(unitLabel)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(prize.color.opacity(0.18)))
                    .foregroundColor(prize.color)

                // CTA
                Button(action: onClose) {
                    Text("Fantastico!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color(hex: "#b43cc8").opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#fff4e6"), Color(hex: "#f0e6f7")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                cardScale = 1.0
            }
            iconBob = true
        }
    }
}
