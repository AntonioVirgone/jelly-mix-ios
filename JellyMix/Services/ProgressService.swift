//
//  ProgressService.swift
//  JellyMix
//
//  Servizio per gli endpoint di progresso di gioco (Step 2).
//  Tutti gli endpoint richiedono autenticazione Firebase (✅).
//

import Foundation

enum ProgressService {

    // MARK: - Report progress

    /// POST /api/v1/progress ✅
    /// Inviato dopo ogni livello completato. L'endpoint è idempotente:
    /// il server ignora chiamate che porterebbero il progresso indietro.
    /// Fire-and-forget: il client non aspetta la risposta per aggiornare la UI locale.
    static func reportLevelCompleted(
        worldId: String,
        levelId: String,
        isWorldComplete: Bool
    ) async throws {
        let body = ReportProgressBody(
            worldId: worldId,
            levelId: levelId,
            isWorldComplete: isWorldComplete
        )
        // Il server risponde 201 con body vuoto — usiamo EmptyResponse per decodificare
        let _: EmptyResponse = try await CommonService.request(
            from: "progress",
            method: .post,
            body: body,
            authenticated: true
        )
    }

    // MARK: - Fetch progress

    /// GET /api/v1/progress/me ✅
    /// Restituisce il progresso completo dell'utente su tutti i mondi.
    /// Usato all'avvio per sincronizzare il progresso su un nuovo device (reinstallazione).
    static func getMyProgress() async throws -> MyProgressResponse {
        try await CommonService.request(from: "progress/me", authenticated: true)
    }

    // getFriendsProgress() è stato spostato in FriendshipService (Step 3)
}
