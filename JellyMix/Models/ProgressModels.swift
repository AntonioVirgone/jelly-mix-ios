//
//  ProgressModels.swift
//  JellyMix
//
//  Modelli Codable per il sistema progresso di gioco (Step 2).
//  Speculari ai DTO dell'API: POST /api/v1/progress e GET /api/v1/progress/me.
//

import Foundation

// Body per POST /api/v1/progress — inviato dopo ogni livello completato
struct ReportProgressBody: Encodable {
    let worldId: String          // UUID del mondo corrente
    let levelId: String          // UUID del livello appena completato
    let isWorldComplete: Bool    // true solo sull'ultimo livello del mondo
}

// Puntatore all'ultimo livello completato in un mondo — parte di WorldProgressEntry
struct LevelProgressCursor: Codable {
    let levelId: String      // UUID del livello
    let levelNumber: Int     // Numero assoluto del livello
    let levelIndex: Int      // Posizione relativa nel mondo (1-based)
}

// Progresso di un singolo mondo — elemento dell'array "worlds" in MyProgressResponse
struct WorldProgressEntry: Codable {
    let worldId: String
    let worldName: String
    let stageNumber: Int
    let worldIcon: String
    let worldColor: String
    let isWorldComplete: Bool
    let completedAt: Date?               // null se il mondo non è ancora completato
    let currentLevel: LevelProgressCursor?  // null se nessun livello completato nel mondo
}

// Risposta di GET /api/v1/progress/me — progresso completo dell'utente
struct MyProgressResponse: Codable {
    let currentStageNumber: Int?         // Mondo massimo raggiunto; null se nessun progresso
    let worlds: [WorldProgressEntry]     // Ordinati per stageNumber crescente
}

// Risposta di GET /api/v1/users/me/friends-progress — stub per Step 3
// Attualmente restituisce sempre { friends: [] }
struct FriendsProgressResponse: Codable {
    let friends: [String]    // Placeholder — verrà tipizzato in Step 3
}
