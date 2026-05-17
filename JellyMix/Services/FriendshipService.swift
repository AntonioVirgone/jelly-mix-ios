//
//  FriendshipService.swift
//  JellyMix
//
//  Servizio per tutti gli endpoint del sistema amicizie (Step 3).
//  Tutti gli endpoint richiedono autenticazione Firebase (✅).
//

import Foundation

enum FriendshipService {

    // MARK: - Invite (Metodo A — zero friction)

    /// POST /api/v1/friendships/invite ✅
    /// Genera un codice monouso valido 7 giorni.
    /// Deep link da costruire: jellymix://invite/<code>
    static func generateInvite() async throws -> InviteResponse {
        try await CommonService.request(
            from: "friendships/invite",
            method: .post,
            authenticated: true
        )
    }

    /// POST /api/v1/friendships/accept-invite/:code ✅
    /// Chiamato quando l'utente apre il deep link jellymix://invite/:code.
    /// Crea direttamente un'amicizia ACCEPTED senza passare per PENDING.
    static func acceptInvite(code: String) async throws -> Friendship {
        try await CommonService.request(
            from: "friendships/accept-invite/\(code)",
            method: .post,
            authenticated: true
        )
    }

    // MARK: - Request (Metodo B — ricerca username)

    /// POST /api/v1/friendships/request/:userId ✅
    /// Invia una richiesta di amicizia — crea un record PENDING.
    /// Il server invia una push FRIEND_REQUEST al destinatario.
    static func sendRequest(toUserId: String) async throws -> Friendship {
        try await CommonService.request(
            from: "friendships/request/\(toUserId)",
            method: .post,
            authenticated: true
        )
    }

    /// POST /api/v1/friendships/accept/:id ✅ — risponde 200 (non 201)
    /// Accetta una richiesta PENDING. Solo il receiver può chiamarlo.
    /// Il server invia una push FRIEND_ACCEPTED all'initiator.
    static func acceptRequest(friendshipId: String) async throws -> Friendship {
        try await CommonService.request(
            from: "friendships/accept/\(friendshipId)",
            method: .post,
            authenticated: true
        )
    }

    /// POST /api/v1/friendships/reject/:id ✅ — risponde 204
    /// Rifiuta una richiesta PENDING. Solo il receiver può chiamarlo.
    static func rejectRequest(friendshipId: String) async throws {
        let _: EmptyResponse = try await CommonService.request(
            from: "friendships/reject/\(friendshipId)",
            method: .post,
            authenticated: true
        )
    }

    // MARK: - List

    /// GET /api/v1/friendships ✅
    /// Lista di tutti gli amici con status ACCEPTED, ordinati per data decrescente.
    static func getFriends() async throws -> [Friendship] {
        try await CommonService.request(from: "friendships", authenticated: true)
    }

    /// GET /api/v1/friendships/pending ✅
    /// Lista delle richieste ricevute in attesa (solo quelle IN cui l'utente è receiver).
    static func getPendingRequests() async throws -> [Friendship] {
        try await CommonService.request(from: "friendships/pending", authenticated: true)
    }

    // MARK: - Remove

    /// DELETE /api/v1/friendships/:id ✅ — risponde 204
    /// Rimuove un'amicizia ACCEPTED. Entrambi i membri possono rimuoverla.
    static func removeFriend(friendshipId: String) async throws {
        let _: EmptyResponse = try await CommonService.request(
            from: "friendships/\(friendshipId)",
            method: .delete,
            authenticated: true
        )
    }

    // MARK: - Friends progress

    /// GET /api/v1/users/me/friends-progress ✅
    /// Feed dei progressi di tutti gli amici confermati.
    /// Prima dello Step 3 restituiva sempre { friends: [] } (stub).
    static func getFriendsProgress() async throws -> FriendsProgressResponse {
        try await CommonService.request(from: "users/me/friends-progress", authenticated: true)
    }
}
