//
//  AuthService.swift
//  JellyMix
//
//  Gestisce l'identità Firebase anonima dell'utente.
//  È un `actor` per garantire thread-safety: getIdToken può essere chiamato
//  da più task concorrenti senza race condition.
//

import Foundation
import FirebaseAuth

// Errori specifici del layer di autenticazione
enum AuthError: Error {
    case notLoggedIn
}

actor AuthService {
    static let shared = AuthService()
    private init() {}

    // Esegue il login anonimo solo se l'utente non è già autenticato.
    // Chiamato al primo avvio; se Firebase ha già una sessione salvata, è un no-op.
    func signInIfNeeded() async throws {
        guard Auth.auth().currentUser == nil else { return }
        let result = try await Auth.auth().signInAnonymously()
        print("[Auth] Signed in anonymously: \(result.user.uid)")
    }

    // Restituisce sempre un token valido.
    // Firebase SDK rinnova automaticamente il token se scaduto (TTL 1h).
    // forcingRefresh: true usato dal CommonService dopo un 401.
    func getIdToken(forcingRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notLoggedIn
        }
        return try await user.getIDToken(forcingRefresh: forcingRefresh)
    }

    // Indica se l'utente ha una sessione Firebase attiva
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    // UID Firebase dell'utente corrente (nil se non autenticato)
    var currentUID: String? {
        Auth.auth().currentUser?.uid
    }
}
