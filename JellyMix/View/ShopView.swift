//
//  ShopView.swift
//  JellyMix
//
//  Created by Antonio Virgone on 24/04/26.
//

import Foundation
import SwiftUI

// MARK: - Vista Negozio Principale
struct ShopView: View {
    @ObservedObject var viewModel: GameViewModel

    @State private var pulledCards: [ElementType]? = nil
    @State private var packCount: Int = 0

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Header monete
                ZStack {
                    Text("NEGOZIO")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .shadow(radius: 2)
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text("\(viewModel.coins)")
                            Image("icon_coins")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .offset(y: 1)
                        }
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Capsule().fill(Color.orange.opacity(0.8)))
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Bustina
                VStack(spacing: 12) {
                    Text("Bustina di Gelatine")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))

                    Text("3 carte casuali, incluse le rare!")
                        .font(.subheadline)
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))

                    Button(action: {
                        withAnimation(.spring()) {
                            packCount += 1
                            pulledCards = viewModel.buyAndOpenPack(cost: 100)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("Apri Bustina — 100")
                            Image("icon_coins")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(
                                viewModel.coins >= 100
                                ? LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
                            )
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(viewModel.coins < 100)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                                         startPoint: .leading,
                                         endPoint: .trailing)))
                .padding(.horizontal)

                // Carte pescate
                if let cards = pulledCards {
                    VStack(spacing: 16) {
                        Text("Hai ottenuto:")
                            .font(.headline)
                            .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))

                        HStack(spacing: 16) {
                            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                                JellyCardView(jellyType: card)
                                    .id("\(packCount)-\(i)")
                                    .frame(width: 90, height: 135)
                            }
                        }
                        
                        Button {
                            withAnimation { pulledCards = nil }
                        } label: {
                            Text("Continua")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Spacer()
                }

                Spacer()
            }
        }
    }
}

// MARK: - Carta Singola (effetto flip)
struct JellyCardView: View {
    var jellyType: ElementType

    @State private var isFlipped: Bool = false
    @State private var flashEffect: Bool = false

    var body: some View {
        ZStack {
            // Retro carta
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(radius: 5)
                .overlay(
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                )
                .opacity(isFlipped ? 0 : 1)

            // Fronte carta
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .shadow(color: jellyType.config.color.opacity(0.6), radius: isFlipped ? 15 : 0)
                .overlay(
                    VStack {
                        Text(jellyType.config.name.uppercased())
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.gray)
                            .padding(.top, 10)

                        Spacer()

                        ElementView(type: jellyType, isDirty: false)
                            .frame(width: 60, height: 60)
                            .scaleEffect(flashEffect ? 1.2 : 1.0)

                        Spacer()
                    }
                )
                .rotation3DEffect(.degrees(-180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            guard !isFlipped else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isFlipped = true
            }
            withAnimation(.easeInOut(duration: 0.2).delay(0.3)) { flashEffect = true }
            withAnimation(.easeInOut(duration: 0.2).delay(0.5)) { flashEffect = false }
        }
    }
}
