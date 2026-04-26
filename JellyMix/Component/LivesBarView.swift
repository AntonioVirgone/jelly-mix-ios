//
//  LivesBarView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 26/04/26.
//

import SwiftUI

struct LivesBarView: View {
    @ObservedObject var viewModel: GameViewModel

    private var timerText: String {
        let m = viewModel.timeToNextLife / 60
        let s = viewModel.timeToNextLife % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 8) {
            // ── Cuori ──────────────────────────────────────
            HStack(spacing: 3) {
                ForEach(0..<viewModel.maxLives, id: \.self) { i in
                    Image(systemName: i < viewModel.lives ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(i < viewModel.lives ? .red : Color.white.opacity(0.35))
                        .scaleEffect(i < viewModel.lives ? 1.0 : 0.85)
                }
            }
            
            // ── Countdown (visibile solo se non siamo al massimo) ──
            if viewModel.lives < viewModel.maxLives {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(timerText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.red.opacity(0.65)))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.lives)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [.purple.opacity(0.4), .pink.opacity(0.4)],
                                     startPoint: .leading, endPoint: .trailing))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        )
    }
}

#Preview {
    LivesBarView(viewModel: GameViewModel())
}
