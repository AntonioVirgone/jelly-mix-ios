//
//  JellyMixApp.swift
//  JellyMix
//
//  Created by Antonio Virgone on 21/04/26.
//

import SwiftUI

@main
struct JellyMixApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var showSplash = true
    @StateObject private var gameEngine = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .task {
                            await prepareLogData()
                            await prepareAppData()
                        }
                } else {
                    MainCoordinator(gameEngine: gameEngine)
                        .transition(.opacity)
                }
            }
            // Push remota "map_update": aggiorna la mappa con la stessa logica del refresh automatico.
            .onReceive(NotificationCenter.default.publisher(for: .mapUpdatePushReceived)) { _ in
                guard !showSplash else { return }
                Task { await backgroundRefresh() }
            }
        }
        // Quando l'app torna in foreground (dopo essere stata in background)
        // avvia subito un refresh silenzioso della mappa.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !showSplash {
                Task { await backgroundRefresh() }
            }
        }
    }

    // MARK: - Boot sequence

    private func prepareLogData() async {
        if UserDefaults.standard.string(forKey: "appId") != nil { return }
        let newAppId = UUID().uuidString
        do {
            try await DataLoggerService.createLevel(
                dataLogger: DataLoggerModels(appId: newAppId, type: TypeDataLogger.install)
            )
            UserDefaults.standard.set(newAppId, forKey: "appId")
        } catch {
            print("LOG: Errore invio dati install.")
        }
    }

    private func prepareAppData() async {
        let startTime = Date()

        // 1. Carica subito da cache (disco) o bundle — istantaneo, nessuna rete.
        if let local = WorldCacheService.loadBestAvailable() {
            gameEngine.applyLevelCollection(local)
            gameEngine.resetGame(forLevel: 1)
        }

        // 2. Durata minima splash: 1 secondo.
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 1.0 {
            try? await Task.sleep(nanoseconds: UInt64((1.0 - elapsed) * 1_000_000_000))
        }

        // 3. Mostra la schermata principale.
        withAnimation(.easeOut(duration: 0.5)) { showSplash = false }

        // 4. Avvia il refresh in background senza aspettarne il risultato.
        Task { await backgroundRefresh() }
    }

    // MARK: - Background refresh

    // Tenta di scaricare i mondi aggiornati con retry.
    // Se riesce: salva su disco, aggiorna il ViewModel, notifica la UI.
    @MainActor
    private func backgroundRefresh() async {
        do {
            let fresh = try await WorldService.fetchWorldsWithRetry()
            try? WorldCacheService.save(fresh)
            gameEngine.applyLevelCollection(fresh)
            gameEngine.mapWasUpdated = true
            print("[Refresh] Mappa aggiornata dall'API.")
        } catch {
            print("[Refresh] Tutti i tentativi falliti: \(error.localizedDescription)")
        }
    }
}
