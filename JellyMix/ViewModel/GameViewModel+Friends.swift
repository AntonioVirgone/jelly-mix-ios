//
//  GameViewModel+Friends.swift
//  JellyMix
//
//  Logica del sistema amicizie (Step 3).
//  Caricamento, mutazioni e gestione delle notifiche push sociali.
//

import Foundation

extension GameViewModel {

    // MARK: - Bootstrap (chiamato da bootstrapUser dopo auth)

    /// Carica amici, richieste pendenti e feed progressi in parallelo.
    @MainActor
    func loadFriendsData() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }

        // Chiamate parallele: amici confermati, richieste in attesa, feed progressi
        async let friendsTask          = FriendshipService.getFriends()
        async let pendingTask          = FriendshipService.getPendingRequests()
        async let friendsProgressTask  = FriendshipService.getFriendsProgress()

        friends           = (try? await friendsTask) ?? []
        pendingFriendships = (try? await pendingTask) ?? []
        friendsProgress   = (try? await friendsProgressTask)?.friends ?? []
    }

    // MARK: - Reload parziali (chiamati dopo push o azione utente)

    /// Ricarica solo amici confermati e feed progressi (dopo FRIEND_ACCEPTED).
    @MainActor
    func reloadFriendsAndProgress() async {
        async let friendsTask         = FriendshipService.getFriends()
        async let friendsProgressTask = FriendshipService.getFriendsProgress()
        friends         = (try? await friendsTask) ?? []
        friendsProgress = (try? await friendsProgressTask)?.friends ?? []
    }

    /// Ricarica solo le richieste pendenti (dopo push FRIEND_REQUEST).
    @MainActor
    func reloadPendingFriendships() async {
        pendingFriendships = (try? await FriendshipService.getPendingRequests()) ?? []
    }

    // MARK: - Invito (Metodo A)

    /// Genera un codice invito e restituisce il deep link da condividere.
    func generateInviteLink() async throws -> String {
        let response = try await FriendshipService.generateInvite()
        return "jellymix://invite/\(response.code)"
    }

    /// Accetta un invito via codice (chiamato dopo apertura deep link).
    /// Aggiorna la lista amici in caso di successo.
    @MainActor
    func acceptInviteCode(_ code: String) async throws {
        let friendship = try await FriendshipService.acceptInvite(code: code)
        // Aggiunge l'amico alla lista locale senza un fetch completo
        if !friends.contains(where: { $0.id == friendship.id }) {
            friends.insert(friendship, at: 0)
        }
        await reloadFriendsAndProgress()
    }

    // MARK: - Ricerca username (Metodo B)

    /// Invia una richiesta di amicizia all'utente con l'id specificato.
    func sendFriendRequest(toUserId: String) async throws {
        let _ = try await FriendshipService.sendRequest(toUserId: toUserId)
    }

    // MARK: - Gestione richieste ricevute

    /// Accetta una richiesta PENDING. Rimuove dalla lista pending e aggiorna amici.
    @MainActor
    func acceptFriendRequest(friendshipId: String) async throws {
        let friendship = try await FriendshipService.acceptRequest(friendshipId: friendshipId)
        // Aggiorna le liste locali senza ulteriori fetch
        pendingFriendships.removeAll { $0.id == friendshipId }
        if !friends.contains(where: { $0.id == friendship.id }) {
            friends.insert(friendship, at: 0)
        }
        await reloadFriendsAndProgress()
    }

    /// Rifiuta una richiesta PENDING. Rimuove solo dalla lista pending.
    @MainActor
    func rejectFriendRequest(friendshipId: String) async throws {
        try await FriendshipService.rejectRequest(friendshipId: friendshipId)
        pendingFriendships.removeAll { $0.id == friendshipId }
    }

    // MARK: - Rimozione amico

    /// Rimuove un amico confermato. Aggiorna amici e feed progressi.
    @MainActor
    func removeFriend(friendshipId: String) async throws {
        try await FriendshipService.removeFriend(friendshipId: friendshipId)
        friends.removeAll { $0.id == friendshipId }
        // Rimuove dal feed progressi
        if let friendship = friends.first(where: { $0.id == friendshipId }) {
            friendsProgress.removeAll { $0.friendId == friendship.friend.id }
        }
        friendsProgress = (try? await FriendshipService.getFriendsProgress())?.friends ?? []
    }
}
