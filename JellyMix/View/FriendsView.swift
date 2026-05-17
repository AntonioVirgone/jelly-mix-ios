//
//  FriendsView.swift
//  JellyMix
//
//  Vista provvisoria per il sistema amicizie (Step 3).
//  Supporta: lista amici, richieste pendenti, invita via link, cerca per username.
//

import SwiftUI

struct FriendsView: View {
    @ObservedObject var viewModel: GameViewModel

    // Controllo navigazione interna
    @State private var selectedTab: FriendsTab = .friends
    @State private var searchUsername: String = ""
    @State private var searchResults: [PublicProfile] = []
    @State private var isSearching: Bool = false
    @State private var inviteLink: String? = nil
    @State private var isGeneratingLink: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    enum FriendsTab { case friends, pending, add }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AMICI")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink],
                                                    startPoint: .leading, endPoint: .trailing))
                Spacer()
                // Badge richieste pendenti
                if viewModel.pendingFriendshipsCount > 0 {
                    Text("\(viewModel.pendingFriendshipsCount)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Selector tab interno
            HStack(spacing: 0) {
                internalTab("Amici", tab: .friends, badge: 0)
                internalTab("In attesa", tab: .pending, badge: viewModel.pendingFriendshipsCount)
                internalTab("Aggiungi", tab: .add, badge: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Feedback messaggi
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if let success = successMessage {
                Text(success)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            // Contenuto tab
            ScrollView {
                switch selectedTab {
                case .friends:   friendsListSection
                case .pending:   pendingSection
                case .add:       addFriendSection
                }
            }
            .refreshable {
                await viewModel.loadFriendsData()
            }
        }
    }

    // MARK: - Lista amici confermati

    private var friendsListSection: some View {
        LazyVStack(spacing: 12) {
            if viewModel.isLoadingFriends {
                ProgressView().padding(.top, 40)
            } else if viewModel.friends.isEmpty {
                emptyState(
                    icon: "person.2",
                    title: "Nessun amico ancora",
                    subtitle: "Invita qualcuno o cerca un username"
                )
            } else {
                ForEach(viewModel.friends) { friendship in
                    FriendRow(
                        friendship: friendship,
                        progress: viewModel.friendsProgress.first { $0.friendId == friendship.friend.id }
                    ) {
                        Task { try? await viewModel.removeFriend(friendshipId: friendship.id) }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Richieste pendenti ricevute

    private var pendingSection: some View {
        LazyVStack(spacing: 12) {
            if viewModel.pendingFriendships.isEmpty {
                emptyState(
                    icon: "clock",
                    title: "Nessuna richiesta in attesa",
                    subtitle: "Le richieste che ricevi appariranno qui"
                )
            } else {
                ForEach(viewModel.pendingFriendships) { friendship in
                    PendingRequestRow(friendship: friendship) {
                        // Accetta
                        Task {
                            do {
                                try await viewModel.acceptFriendRequest(friendshipId: friendship.id)
                                showSuccess("Ora sei amico di \(friendship.friend.resolvedDisplayName)!")
                            } catch {
                                showError("Impossibile accettare la richiesta")
                            }
                        }
                    } onReject: {
                        // Rifiuta
                        Task {
                            do {
                                try await viewModel.rejectFriendRequest(friendshipId: friendship.id)
                            } catch {
                                showError("Impossibile rifiutare la richiesta")
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Aggiungi amico

    private var addFriendSection: some View {
        VStack(spacing: 20) {
            // Metodo A: invita via link
            inviteSection

            Divider().padding(.horizontal, 20)

            // Metodo B: cerca per username
            searchSection
        }
        .padding(.top, 8)
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Invita via link", systemImage: "link")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)

            if let link = inviteLink {
                // Link generato — mostra con pulsante condivisione
                HStack {
                    Text(link)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    ShareLink(item: link) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                .padding(.horizontal, 20)
            }

            Button {
                Task {
                    isGeneratingLink = true
                    defer { isGeneratingLink = false }
                    do {
                        inviteLink = try await viewModel.generateInviteLink()
                    } catch {
                        showError("Impossibile generare il link")
                    }
                }
            } label: {
                HStack {
                    if isGeneratingLink {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "link.badge.plus")
                    }
                    Text(inviteLink == nil ? "Genera link invito" : "Rigenera link")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.purple, .pink],
                                             startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
            }
            .disabled(isGeneratingLink)
            .padding(.horizontal, 20)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cerca per username", systemImage: "magnifyingglass")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)

            HStack {
                TextField("username...", text: $searchUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))

                Button {
                    Task { await performSearch() }
                } label: {
                    if isSearching {
                        ProgressView().scaleEffect(0.8).frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.purple.opacity(0.15)))
                            .foregroundColor(.purple)
                    }
                }
                .disabled(isSearching || searchUsername.count < 3)
            }
            .padding(.horizontal, 20)

            if !searchResults.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(searchResults, id: \.id) { profile in
                        SearchResultRow(profile: profile) {
                            Task {
                                do {
                                    try await viewModel.sendFriendRequest(toUserId: profile.id)
                                    searchResults.removeAll { $0.id == profile.id }
                                    showSuccess("Richiesta inviata a \(profile.resolvedDisplayName)!")
                                } catch {
                                    showError("Impossibile inviare la richiesta")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func internalTab(_ title: String, tab: FriendsTab, badge: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedTab = tab }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(selectedTab == tab ? .white : .secondary)
            .background {
                if selectedTab == tab {
                    Capsule().fill(LinearGradient(colors: [.purple, .pink],
                                                  startPoint: .leading, endPoint: .trailing))
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private func performSearch() async {
        guard searchUsername.count >= 3 else { return }
        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await DataUserService.searchUsers(username: searchUsername)) ?? []
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        successMessage = nil
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            errorMessage = nil
        }
    }

    private func showSuccess(_ msg: String) {
        successMessage = msg
        errorMessage = nil
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
        }
    }
}

// MARK: - FriendRow

private struct FriendRow: View {
    let friendship: Friendship
    let progress: FriendProgress?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(friendship.friend.resolvedDisplayName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.purple)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(friendship.friend.resolvedDisplayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                if let progress, let stage = progress.currentStageNumber {
                    Text("Mondo \(stage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Player #\(friendship.friend.playerNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Rimuovi amico
            Button(action: onRemove) {
                Image(systemName: "person.badge.minus")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }
}

// MARK: - PendingRequestRow

private struct PendingRequestRow: View {
    let friendship: Friendship
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(friendship.friend.resolvedDisplayName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(friendship.friend.resolvedDisplayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Vuole essere tuo amico")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Accetta
            Button(action: onAccept) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
            }
            // Rifiuta
            Button(action: onReject) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.08)))
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let profile: PublicProfile
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(profile.resolvedDisplayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.resolvedDisplayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Player #\(profile.playerNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}
