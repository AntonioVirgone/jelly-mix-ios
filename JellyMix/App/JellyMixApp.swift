//
//  JellyMixApp.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import SwiftUI

@main
struct JellyMixApp: App {
    @State private var showSplash = true
    @StateObject private var gameEngine = GameViewModel()

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .task {
                        await prepareLogData()
                        await prepareAppData()
                    }
            } else {
                /// La view principale
                MainCoordinator(gameEngine: gameEngine)
                    .transition(.opacity)
            }
        }
    }
    
    private func prepareLogData() async {
        if let appId = UserDefaults.standard.string(forKey: "appId") {
            print("LOG: App ID già registrato: \(appId)")
        } else {
            let newAppId = UUID().uuidString
            do {
                try await DataLoggerService.createLevel(dataLogger: DataLoggerModels(appId: newAppId, type: TypeDataLogger.install))
                UserDefaults.standard.set(newAppId, forKey: "appId")
            } catch {
                print("LOG: Errore invio dati log.")
            }
        }        
    }
    
    /// Logica di caricamento dati con gestione dei tempi e fallback
    private func prepareAppData() async {
        // Memorizziamo il tempo di inizio per garantire una durata minima alla Splash
        let startTime = Date()
        
        do {
            // 1. Tentativo di caricamento tramite CommonService (API)
            // Utilizziamo il metodo definito nel Canvas
            let data = try await LevelService.fetchWorlds()
            gameEngine.worlds = data
            print("LOG: Mondi caricati con successo dal backend.")
            
        } catch {
            print("LOG: Errore API (\(error.localizedDescription)). Avvio fallback da Bundle...")
            
            // 2. Fallback: Caricamento dal file JSON locale
            do {
                let localData = try LevelService.loadFromBundle()
                gameEngine.worlds = localData
            } catch {
                print("LOG: Errore critico nel caricamento dei dati locali.")
                // Qui potresti gestire uno stato di errore più grave
            }
        }
        
        // 3. Garantiamo una durata minima della splash per fluidità visiva
        let elapsedTime = Date().timeIntervalSince(startTime)
        if elapsedTime < 2.0 {
            try? await Task.sleep(nanoseconds: UInt64((2.0 - elapsedTime) * 1_000_000_000))
        }
        
        // 4. Transizione fluida alla main view
        withAnimation(.easeOut(duration: 0.5)) {
            showSplash = false
        }
    }
}
