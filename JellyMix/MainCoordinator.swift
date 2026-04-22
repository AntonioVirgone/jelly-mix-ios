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

                        Text("Mappa dei Mondi")
                            .font(.largeTitle).bold()
                        
                        ForEach(1...4, id: \.self) { level in
                            Button(action: {
                                // Cliccando su un livello, prepariamo il gioco e cambiamo schermata
                                gameEngine.resetGame(forLevel: level)
                                withAnimation { currentScreen = .game }
                            }) {
                                Text("Gioca Livello \(level)")
                                    .padding()
                                    .background(level <= maxUnlockedLevel ? Color.blue : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(level > maxUnlockedLevel)
                        }
                    }
                } else {
                    // Passiamo una Closure (callback) a ContentView per fargli sapere quando deve chiudersi
                    ContentView(viewModel: gameEngine) {
                        // Questa azione verrà chiamata quando l'utente clicca "Torna alla Mappa"
                        if gameEngine.isLevelCompleted && gameEngine.currentLevel == maxUnlockedLevel {
                            maxUnlockedLevel += 1 // Sblocca il livello successivo
                        }
                        withAnimation { currentScreen = .map }
                    }
                }
            }
        }
    }
}
