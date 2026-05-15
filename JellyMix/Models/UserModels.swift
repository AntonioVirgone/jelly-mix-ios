//
//  UserModels.swift
//  JellyMix
//
//  Modelli Codable per il profilo utente e la configurazione cuori,
//  speculari ai DTO restituiti dall'API backend (Step 1).
//

import Foundation

// Profilo completo dell'utente autenticato — risposta di GET /api/v1/users/me
struct UserProfile: Codable {
    let id: String
    let playerNumber: Int       // Assegnato permanentemente alla creazione, non cambia mai
    let displayName: String?    // Nome visualizzato; nil finché non impostato dall'utente
    let username: String?       // Username univoco opzionale (3-20 char, lowercase)
    let avatarCode: String?     // Codice preset avatar (gestione futura)
    let heartsCount: Int        // Cuori al momento dell'ultimo salvataggio lato server
    let maxHearts: Int          // Massimo cuori consentiti (in sync con HeartsConfig)
    let lastHeartConsumedAt: Date?  // Timestamp ultimo consumo cuore; usato per calcolo ricarica
    let gdprConsentAt: Date?    // Data consenso GDPR; nil = non ancora prestato (Step 5)
    let createdAt: Date

    // Fallback display: se displayName non è stato impostato, mostra "Player#1234"
    var resolvedDisplayName: String {
        displayName ?? "Player#\(playerNumber)"
    }
}

// Parametri server per il sistema cuori — risposta di GET /api/v1/app-config/hearts
// Sostituisce i valori hardcoded maxLives=5 e secondsPerLife=300 nel GameViewModel
struct HeartsConfig: Codable {
    let heartRechargeMinutes: Int       // Minuti per ricaricare un cuore
    let maxHearts: Int                  // Cuori massimi possedibili
    let maxHeartsReceivedPerDay: Int    // Limite ricezione cuori da amici (Step 4)
}

// Profilo pubblico di un altro utente — risposta di GET /api/v1/users/{id}/profile
// Subset ridotto, senza dati sensibili
struct PublicProfile: Codable {
    let id: String
    let playerNumber: Int
    let displayName: String?
    let avatarCode: String?

    var resolvedDisplayName: String {
        displayName ?? "Player#\(playerNumber)"
    }
}

// Body per PATCH /api/v1/users/me — tutti i campi opzionali (partial update)
struct UpdateProfileBody: Encodable {
    let displayName: String?
    let username: String?
    let avatarCode: String?
}
