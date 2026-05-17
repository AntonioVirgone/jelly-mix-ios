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
    case events
    case shop
    case collection
    case profile
    case friends    // Step 3: sistema amicizie
}

struct MainCoordinator: View {
    @State private var currentScreen: AppScreen = .map
    @State private var showNoLivesOverlay = false
    @State private var showMapUpdatedBanner = false

    @ObservedObject var gameEngine: GameViewModel

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
            
            // Floating decorative dots
            DecorativeDotsLayer()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // ── Schermata di gioco (senza TabBar) ──────────────────────────
            if currentScreen == .game {
                ContentView(viewModel: gameEngine) {
                    if gameEngine.isLevelCompleted,
                       let stageNumber = gameEngine.currentStageNumber,
                       let levelIndex  = gameEngine.currentLevelIndex {
                        gameEngine.completeLevel(stageNumber: stageNumber, levelIndex: levelIndex)
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
            // NOTA: la VStack è sempre montata (non condizionale) per evitare
            // che SagaMapView venga smontata/rimontata durante il gioco.
            // Quando rimontata, LazyVStack riparte da zero e proxy.scrollTo()
            // fallisce silenziosamente perché i nodi distanti non sono ancora
            // renderizzati. Con always-mounted il LazyVStack mantiene lo stato
            // e lo scroll funziona correttamente al ritorno dal gioco.
            VStack(spacing: 0) {
                    // Barra vite — sempre visibile su tutte le tab
                    LivesBarView(viewModel: gameEngine)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

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
                                isLevelUnlocked: { gameEngine.isUnlocked(stageNumber: $0, levelIndex: $1) },
                                isLevelCompleted: { stageNumber, levelIndex in
                                    // Un livello è "completato" se è in completedLevels OPPURE se il
                                    // suo intero mondo è già in completedWorlds (fix mergeServerProgress gap:
                                    // il server può marcare un mondo come complete senza inserire ogni
                                    // singolo levelIndex in completedLevels, causando currentNodeId errato).
                                    gameEngine.completedLevels.contains(LevelCoordinate(stageNumber: stageNumber, levelIndex: levelIndex))
                                    || gameEngine.completedWorlds.contains(stageNumber)
                                },
                                getColor: { gameEngine.getColor(from: $0) },
                                // progressVersion garantisce un singolo trigger atomico dopo ogni
                                // aggiornamento di completedLevels+completedWorlds (fix double-publish bug).
                                // worlds.count gestisce il caricamento asincrono iniziale dei livelli.
                                scrollTrigger: gameEngine.progressVersion
                                             + gameEngine.worlds.flatMap(\.levels).count * 1000
                            ) { stageNumber, levelIndex in
                                if gameEngine.lives > 0 {
                                    gameEngine.resetGame(stageNumber: stageNumber, levelIndex: levelIndex)
                                    withAnimation(.spring()) { currentScreen = .game }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showNoLivesOverlay = true
                                    }
                                }
                            }
                        }
                        .opacity(currentScreen == .map ? 1 : 0)
                        .allowsHitTesting(currentScreen == .map)

                        // Eventi
                        EventsView(viewModel: gameEngine)
                            .opacity(currentScreen == .events ? 1 : 0)
                            .allowsHitTesting(currentScreen == .events)

                        ProfileView(viewModel: gameEngine)
                            .opacity(currentScreen == .profile ? 1 : 0)
                            .allowsHitTesting(currentScreen == .profile)

                        // Negozio
                        ShopView(viewModel: gameEngine)
                            .opacity(currentScreen == .shop ? 1 : 0)
                            .allowsHitTesting(currentScreen == .shop)

                        CollectionBookView(viewModel: gameEngine)
                            .opacity(currentScreen == .collection ? 1 : 0)
                            .allowsHitTesting(currentScreen == .collection)

                        // Amici (Step 3)
                        FriendsView(viewModel: gameEngine)
                            .opacity(currentScreen == .friends ? 1 : 0)
                            .allowsHitTesting(currentScreen == .friends)
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentScreen)

                    // TabBar — passa il badge delle richieste pendenti al tab Amici
                    AppTabBar(
                        currentScreen: $currentScreen,
                        pendingFriendshipsCount: gameEngine.pendingFriendshipsCount
                    )
                }
                // Nasconde l'interfaccia durante il gioco senza smontarla.
                .opacity(currentScreen != .game ? 1 : 0)
                .allowsHitTesting(currentScreen != .game)
                .zIndex(0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentScreen)
        .onAppear {
            gameEngine.setupLivesSystem()
        }
        // Mostra il banner se i nuovi dati arrivano mentre l'utente è sulla mappa.
        .onChange(of: gameEngine.mapWasUpdated) { _, updated in
            if updated && currentScreen == .map { showBanner() }
        }
        // Mostra il banner se l'utente torna sulla mappa dopo che il refresh era già avvenuto.
        .onChange(of: currentScreen) { _, newScreen in
            if newScreen == .map && gameEngine.mapWasUpdated { showBanner() }
        }
        .overlay(alignment: .top) {
            if showMapUpdatedBanner {
                MapUpdatedBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .allowsHitTesting(false)
                    .zIndex(99)
            }
        }
        .overlay {
            if showNoLivesOverlay {
                NoLivesOverlayView(viewModel: gameEngine) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showNoLivesOverlay = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showNoLivesOverlay)
        // Tap su qualsiasi notifica → naviga alla mappa con animazione spring.
        .onReceive(NotificationCenter.default.publisher(for: .openMapFromNotification)) { _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                showNoLivesOverlay = false
                currentScreen = .map
            }
        }
    }
    
    // MARK: - Banner helpers

    private func showBanner() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showMapUpdatedBanner = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                showMapUpdatedBanner = false
            }
            gameEngine.mapWasUpdated = false
        }
    }
}

// MARK: - TabBar

struct AppTabBar: View {
    @Binding var currentScreen: AppScreen
    // Badge count richieste amicizia pendenti — passato dall'esterno
    var pendingFriendshipsCount: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            tabItem(icon: "map.fill",       label: "MAPPA",      screen: .map)
            tabItem(icon: "target",         label: "EVENTI",     screen: .events)
            tabItem(icon: "person.fill",    label: "PROFILO",    screen: .profile)
            // Tab amici con badge per richieste pendenti
            tabItemWithBadge(icon: "person.2.fill", label: "AMICI", screen: .friends,
                             badgeCount: pendingFriendshipsCount)
            tabItem(icon: "bag.fill",       label: "NEGOZIO",    screen: .shop)
            tabItem(icon: "book.fill",      label: "COLLEZIONE", screen: .collection)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // Tab item con badge numerico rosso (usato per le richieste di amicizia pendenti)
    @ViewBuilder
    private func tabItemWithBadge(icon: String, label: String, screen: AppScreen, badgeCount: Int) -> some View {
        let isSelected = currentScreen == screen
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { currentScreen = screen }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                    if badgeCount > 0 {
                        // Badge rosso con il contatore richieste
                        Text("\(badgeCount)")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 10, y: -8)
                    }
                }
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .gray)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .purple.opacity(0.35), radius: 8, y: 3)
                }
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
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
                    .font(.system(size: 8, weight: .black, design: .rounded))
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

// MARK: - Overlay Vite Esaurite

struct NoLivesOverlayView: View {
    @ObservedObject var viewModel: GameViewModel
    var onDismiss: () -> Void

    private var timerText: String {
        let m = viewModel.timeToNextLife / 60
        let s = viewModel.timeToNextLife % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 22) {
                // Icona
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)
                    )

                Text("Vite esaurite!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                // Cuori vuoti
                HStack(spacing: 5) {
                    ForEach(0..<viewModel.maxLives, id: \.self) { _ in
                        Image(systemName: "heart")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }

                // Countdown prossima vita
                VStack(spacing: 6) {
                    Text("Prossima vita tra")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                    Text(timerText)
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .red.opacity(0.6), radius: 8)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.red.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                        )
                )

                Button("Chiudi") { onDismiss() }
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [.purple, .pink],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    )
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.3), radius: 8, y: 3)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
            )
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Banner View

struct MapUpdatedBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
            Text("Mappa aggiornata")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .green.opacity(0.35), radius: 8, y: 4)
        )
    }
}

#Preview {
    MainCoordinator(gameEngine: GameViewModel())
}
