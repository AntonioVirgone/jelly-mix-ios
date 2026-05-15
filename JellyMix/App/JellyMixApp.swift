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

        // 2. Bootstrap utente (non bloccante: il gioco funziona anche offline)
        await bootstrapUser()

        // 3. Durata minima splash: 1 secondo.
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 1.0 {
            try? await Task.sleep(nanoseconds: UInt64((1.0 - elapsed) * 1_000_000_000))
        }

        // 4. Mostra la schermata principale.
        withAnimation(.easeOut(duration: 0.5)) { showSplash = false }

        // 5. Avvia il refresh in background senza aspettarne il risultato.
        Task { await backgroundRefresh() }
    }

    // Sequenza: Firebase auth → GET /users/me + hearts + progress (parallelo) → registra FCM.
    // GET /progress/me viene chiamato DOPO che i worlds sono già caricati da cache (step 1
    // di prepareAppData), così mergeServerProgress() ha il catalogo livelli disponibile.
    // Ogni step è indipendente: un fallimento non blocca i successivi.
    private func bootstrapUser() async {
        do { try await AuthService.shared.signInIfNeeded() }
        catch { print("[Auth] signInIfNeeded fallito: \(error.localizedDescription)"); return }

        // Chiamate parallele: profilo, config cuori e progresso di gioco
        async let profileTask  = DataUserService.getMe()
        async let configTask   = DataUserService.getHeartsConfig()
        async let progressTask = ProgressService.getMyProgress()

        let profile  = try? await profileTask
        let config   = try? await configTask
        let progress = try? await progressTask

        // Applica profilo e parametri cuori (Step 1)
        if let profile, let config {
            await gameEngine.applyServerUserData(profile: profile, config: config)
        }

        // Merge progresso server con stato locale (Step 2).
        // I worlds sono già in gameEngine (caricati da cache nel passo precedente).
        // Se nessuna cache era disponibile (primo avvio fresh), worlds è vuoto e
        // il merge non fa nulla — il progresso verrà riconciliato al prossimo avvio.
        if let progress {
            await gameEngine.mergeServerProgress(progress)
        }

        // Registra FCM token salvato (se disponibile) con auth attiva
        if let savedToken = UserDefaults.standard.string(forKey: "fcmDeviceToken") {
            await NotificationService.registerFCMToken(savedToken)
        }
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
