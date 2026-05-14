//
//  EventsView.swift
//  JellyMix
//

import SwiftUI

struct EventsView: View {
    @ObservedObject var viewModel: GameViewModel
    @StateObject private var events = EventsViewModel()

    var body: some View {
        ZStack {
            // Pastel Cream background gradient
/*
            LinearGradient(
                colors: [
                    Color(hex: "#fff4e6"),
                    Color(hex: "#ffe9ee"),
                    Color(hex: "#f7d9ec"),
                    Color(hex: "#f0e6f7")
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
*/
            //ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("EVENTI")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.04), radius: 0, y: 4)

                    // ── Wheel card ───────────────────────────────────────────
                    WheelCard(events: events, gameViewModel: viewModel)

                    // ── Upcoming events teaser ───────────────────────────────
//                    UpcomingEventsCard()

//                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 30)
//                .padding(.bottom, 100)
            //}

            // ── Prize reveal overlay ─────────────────────────────────────────
            if events.phase == .revealing, let prize = events.currentPrize {
                PrizeRevealView(prize: prize) {
                    events.claimPrize(on: viewModel)
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.25), value: events.phase == .revealing)
    }
}

// MARK: - Wheel card

private struct WheelCard: View {
    @ObservedObject var events: EventsViewModel
    let gameViewModel: GameViewModel
    @State private var glowing = false

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Ruota Fortunata")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            // Subtitle
            Text("Gira una volta al giorno per vincere un potenziamento gratis")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color(hex: "#8a7a8e"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            // Wheel
            WheelView(
                rotation: events.wheelRotation,
                spinning: events.phase == .spinning
            )
            .padding(.vertical, 4)

            // Action button
            ActionButton(events: events, gameViewModel: gameViewModel)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.706, blue: 0.863, opacity: 0.55),
                            Color(red: 1, green: 0.784, blue: 0.549, opacity: 0.35)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0),
                        endPoint: UnitPoint(x: 1, y: 1)
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.70), lineWidth: 1.5)
                )
                .shadow(color: Color(hex: "#b43cc8").opacity(0.18), radius: 16, y: 6)
        )
    }
}

// MARK: - Action button

private struct ActionButton: View {
    @ObservedObject var events: EventsViewModel
    let gameViewModel: GameViewModel
    @State private var pulsing = false

    var body: some View {
        Group {
            switch events.phase {
            case .idle where events.canSpin:
                // GIRA LA RUOTA!
                Button(action: { events.startSpin() }) {
                    Text("GIRA LA RUOTA!")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .kerning(0.5)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#a23ad6"), Color(hex: "#ef3f6e")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: Color(hex: "#b43cc8").opacity(pulsing ? 0.6 : 0.25),
                            radius: pulsing ? 16 : 8, y: 4
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(pulsing ? 1.02 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulsing = true
                    }
                }

            case .spinning:
                // STOP!
                Button(action: { events.stopSpin() }) {
                    Text("STOP!")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .kerning(0.5)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#ff5567"), Color(hex: "#ff3088")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: Color(hex: "#ff5567").opacity(pulsing ? 0.6 : 0.25),
                            radius: pulsing ? 12 : 6, y: 4
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(pulsing ? 1.03 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulsing = true
                    }
                }

            default:
                // Cooldown or decelerating
                CooldownDisplay(events: events)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: events.phase)
    }
}

// MARK: - Cooldown display

private struct CooldownDisplay: View {
    @ObservedObject var events: EventsViewModel

    private var formattedCountdown: String {
        let s = events.secondsUntilNextSpin
        guard s > 0 else { return "" }
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(sec)s" }
        return "\(sec)s"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("PROSSIMO GIRO")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#8a7a8e"))
                .kerning(1.5)

            Text(formattedCountdown)
                .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                .foregroundColor(Color(hex: "#a23ad6"))

            // Dev reset — hidden in production builds
            #if DEBUG
            Button("(Dev: reset)") { events.resetCooldown() }
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#8a7a8e").opacity(0.6))
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(
            Capsule()
                .fill(Color(hex: "#a08caa").opacity(0.18))
        )
    }
}

// MARK: - Upcoming events card

private struct UpcomingEventsCard: View {
    private let events: [(icon: String, name: String, sub: String, color: Color)] = [
        ("🏆", "Sfida Settimanale", "Termina tra 4 giorni", Color(hex: "#ffce5c")),
        ("✨", "Mondo Bonus",       "Disponibile sabato",   Color(hex: "#a35bff")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PROSSIMI EVENTI")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#8a7a8e"))
                .kerning(1.5)
                .padding(.bottom, 10)

            ForEach(Array(events.enumerated()), id: \.offset) { i, event in
                if i > 0 {
                    Divider()
                        .background(Color.black.opacity(0.06))
                }
                HStack(spacing: 12) {
                    // Icon tile
                    Text(event.icon)
                        .font(.system(size: 20))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(event.color.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11)
                                        .stroke(event.color.opacity(0.35), lineWidth: 1.5)
                                )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#3a2a3e"))
                        Text(event.sub)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundColor(Color(hex: "#8a7a8e"))
                    }
                    Spacer()

                    // PRESTO badge
                    Text("PRESTO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .kerning(1)
                        .foregroundColor(Color(hex: "#8a7a8e"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: "#a08caa").opacity(0.18)))
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.55))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.70), lineWidth: 1)
                )
        )
    }
}

