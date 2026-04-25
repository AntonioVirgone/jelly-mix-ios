//
//  MainCoordinator.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation
import SwiftUI

enum AppScreen {
    case map
    case game
    case shop
    case collection // <-- Nuovo
}

struct MainCoordinator: View {
    @State private var currentScreen: AppScreen = .map
    @State private var maxUnlockedLevel: Int = 1

    @StateObject private var gameEngine = GameViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Sfondo sfumato globale
            LinearGradient(
                colors: [
                    Color.yellow.opacity(0.2),
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            // ── Schermata di gioco (senza TabBar) ──────────────────────────
            if currentScreen == .game {
                ContentView(viewModel: gameEngine) {
                    if gameEngine.isLevelCompleted && gameEngine.currentLevel == maxUnlockedLevel {
                        maxUnlockedLevel += 1
                        UserDefaults.standard.set(maxUnlockedLevel, forKey: "maxUnlockedLevel")
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        currentScreen = .map
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal:   .opacity.combined(with: .scale(scale: 1.05))
                ))
                .zIndex(1)
            }

            // ── Schermate con TabBar ────────────────────────────────────────
            if currentScreen != .game {
                VStack(spacing: 0) {
                    // Contenuto della scheda attiva
                    ZStack {
                        // Mappa
                        VStack(spacing: 30) {
                            Text("JELLY MIX")
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .pink],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(radius: 2)

                            SagaMapView(
                                worlds: gameEngine.worlds,
                                maxUnlockedLevel: UserDefaults.standard.integer(forKey: "maxUnlockedLevel") != 0
                                    ? UserDefaults.standard.integer(forKey: "maxUnlockedLevel")
                                    : maxUnlockedLevel,
                                getColor: { gameEngine.getColor(from: $0) }
                            ) { levelToPlay in
                                gameEngine.resetGame(forLevel: levelToPlay)
                                withAnimation(.spring()) { currentScreen = .game }
                            }
                        }
                        .opacity(currentScreen == .map ? 1 : 0)
                        .allowsHitTesting(currentScreen == .map)

                        // Negozio
                        ShopView(viewModel: gameEngine)
                            .opacity(currentScreen == .shop ? 1 : 0)
                            .allowsHitTesting(currentScreen == .shop)
                        
                        CollectionBookView(viewModel: gameEngine)
                            .opacity(currentScreen == .collection ? 1 : 0)
                            .allowsHitTesting(currentScreen == .collection)
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentScreen)

                    // TabBar
                    AppTabBar(currentScreen: $currentScreen)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(0)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentScreen)
    }
}

// MARK: - TabBar

struct AppTabBar: View {
    @Binding var currentScreen: AppScreen

    var body: some View {
        HStack(spacing: 8) {
            tabItem(icon: "map.fill",  label: "MAPPA", screen: .map)
            tabItem(icon: "bag.fill",  label: "NEGOZIO", screen: .shop)
            tabItem(icon: "book.fill",  label: "COLLEZIONE", screen: .collection)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        )
        .padding(.horizontal, 60)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func tabItem(icon: String, label: String, screen: AppScreen) -> some View {
        let isSelected = currentScreen == screen

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentScreen = screen
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .gray)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: .purple.opacity(0.35), radius: 8, y: 3)
                }
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainCoordinator()
}
