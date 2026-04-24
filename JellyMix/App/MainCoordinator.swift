//
//  MainCoordinator.swift
//  JellyMix
//
//  Created by Antonio Virgone on 22/04/26.
//

import Foundation
import SwiftUI

// Gli stati possibili della nostra app
enum AppScreen {
    case map
    case game
}

struct MainCoordinator: View {
    @State private var currentScreen: AppScreen = .map
    @State private var maxUnlockedLevel: Int = 1
    
    // Condividiamo lo stesso motore per tutta l'app
    @StateObject private var gameEngine = GameViewModel()
    
    var body: some View {
        ZStack {
            // Sfondo sfumato
            LinearGradient(
                colors: [
                    Color.yellow.opacity(0.2),
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            Group {
                if currentScreen == .map {
                    // Sostituisci questo con il codice della tua SagaMap vera,
                    // per ora mettiamo una Mappa segnaposto con dei bottoni
                    VStack(spacing: 30) {
                        Text("JELLY MIX")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                            .shadow(radius: 2)
/*
                        // === LA NUOVA MAPPA SAGA ===
                        SagaMapView(maxUnlockedLevel: maxUnlockedLevel) { levelToPlay in
                            // Callback chiamato dalla mappa quando si preme "Gioca"
                            gameEngine.resetGame(forLevel: levelToPlay)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                currentScreen = .game
                            }
                        }
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.1)), removal: .opacity.combined(with: .scale(scale: 0.9))))
                        */
                        SagaMapView(
                            worlds: gameEngine.worlds, // Usiamo i dati dal motore
                            maxUnlockedLevel: maxUnlockedLevel,
                            getColor: gameEngine.getColor // Passiamo la funzione per i colori
                        ) { levelToPlay in
                            gameEngine.resetGame(forLevel: levelToPlay)
                            withAnimation(.spring()) {
                                currentScreen = .game
                            }
                        }
 
                    }
                } else {
                    // === LA SCHERMATA DI GIOCO ===
                    ContentView(viewModel: gameEngine) {
                        // Callback chiamato da ContentView per tornare indietro
                        
                        // Se il livello è stato completato e era l'ultimo sbloccato, sblocca il prossimo!
                        if gameEngine.isLevelCompleted && gameEngine.currentLevel == maxUnlockedLevel {
                            maxUnlockedLevel += 1
                            //TODO: Qui potresti salvare maxUnlockedLevel nel localStorage (UserDefaults)
                        }
                        
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            currentScreen = .map
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9)), removal: .opacity.combined(with: .scale(scale: 1.1))))
                }
            }
        }
    }
}
