//
//  FriendshipModels.swift
//  JellyMix
//
//  Modelli Codable per il sistema amicizie (Step 3).
//  Speculari ai DTO dell'API: /api/v1/friendships e /api/v1/users/me/friends-progress.
//

import Foundation

// Profilo pubblico dell'amico — usato all'interno di Friendship
struct FriendProfile: Codable {
    let id: String
    let playerNumber: Int
    let displayName: String
    let avatarCode: String?     // nullable lato server

    // Fallback display consistente con UserProfile.resolvedDisplayName
    var resolvedDisplayName: String {
        displayName.isEmpty ? "Player#\(playerNumber)" : displayName
    }
}

// Record di amicizia — status può essere "PENDING" o "ACCEPTED"
// `friend` è sempre l'altro utente, indipendentemente da chi ha iniziato
struct Friendship: Codable, Identifiable {
    let id: String
    let status: String          // "PENDING" | "ACCEPTED"
    let createdAt: Date
    let friend: FriendProfile
}

// Risposta di POST /api/v1/friendships/invite — codice monouso con scadenza 7 giorni
struct InviteResponse: Codable {
    let code: String            // Da inserire nel deep link jellymix://invite/:code
    let expiresAt: Date
}

// Livello corrente di un amico su un mondo (versione ridotta senza levelId)
struct FriendCurrentLevel: Codable {
    let levelNumber: Int
    let levelIndex: Int
}

// Progresso di un amico su un singolo mondo
struct FriendProgressEntry: Codable {
    let worldId: String
    let worldName: String
    let stageNumber: Int
    let worldIcon: String
    let isWorldComplete: Bool
    let currentLevel: FriendCurrentLevel?   // null se nessun livello completato nel mondo
}

// Progresso completo di un singolo amico su tutti i mondi
struct FriendProgress: Codable {
    let friendId: String
    let displayName: String
    let avatarCode: String?
    let currentStageNumber: Int?            // null se nessun progresso
    let worlds: [FriendProgressEntry]

    var resolvedDisplayName: String {
        displayName.isEmpty ? "Amico" : displayName
    }
}

// Risposta di GET /api/v1/users/me/friends-progress — feed progressi amici
struct FriendsProgressResponse: Codable {
    let friends: [FriendProgress]
}
