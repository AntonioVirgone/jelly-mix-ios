//
//  DataUserService.swift
//  JellyMix
//
//  Servizio per gli endpoint utente del backend (Step 1).
//  Tutti i metodi autenticati (✅) richiedono che AuthService.signInIfNeeded()
//  sia stato già chiamato prima dell'invocazione.
//

import Foundation

enum DataUserService {

    // MARK: - Current User

    /// GET /api/v1/users/me ✅
    /// Restituisce il profilo dell'utente autenticato.
    /// Il record viene creato automaticamente al primo accesso (upsert lato server).
    static func getMe() async throws -> UserProfile {
        try await CommonService.request(from: "users/me", authenticated: true)
    }

    /// PATCH /api/v1/users/me ✅
    /// Aggiorna i campi opzionali del profilo. Solo i campi non-nil vengono inviati.
    /// Restituisce il profilo aggiornato.
    static func updateMe(
        displayName: String? = nil,
        username: String? = nil,
        avatarCode: String? = nil
    ) async throws -> UserProfile {
        let body = UpdateProfileBody(displayName: displayName, username: username, avatarCode: avatarCode)
        return try await CommonService.request(from: "users/me", method: .patch, body: body, authenticated: true)
    }

    // MARK: - Public Profiles

    /// GET /api/v1/users/{id}/profile ❌ (pubblico)
    /// Profilo ridotto di un altro utente — usato per deep link e visualizzazione amici.
    static func getPublicProfile(id: String) async throws -> PublicProfile {
        try await CommonService.request(from: "users/\(id)/profile")
    }

    /// GET /api/v1/users/search?username= ✅
    /// Ricerca utenti per username (match parziale, case-insensitive, max 10 risultati).
    /// Usato per la funzione "aggiungi amico" (Step 3).
    static func searchUsers(username: String) async throws -> [PublicProfile] {
        guard let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        return try await CommonService.request(from: "users/search?username=\(encoded)", authenticated: true)
    }

    // MARK: - Hearts Config

    /// GET /api/v1/app-config/hearts ❌ (pubblico)
    /// Parametri server del sistema cuori. Sostituisce i valori hardcoded nel GameViewModel.
    /// Da cachare localmente e richiamare all'avvio.
    static func getHeartsConfig() async throws -> HeartsConfig {
        try await CommonService.request(from: "app-config/hearts")
    }
}
