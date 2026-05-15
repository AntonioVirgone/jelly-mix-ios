//
//  ProfileView.swift
//  JellyMix
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var editingName: String = ""
    @State private var editingUsername: String = ""
    @State private var isEditing: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil
    @State private var saveSuccess: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                if let profile = viewModel.userProfile {
                    infoSection(profile: profile)
                    heartsSection
                    editSection(profile: profile)
                } else {
                    loadingOrOffline
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 6) {
            Text("PROFILO")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .leading, endPoint: .trailing
                ))
        }
    }

    // MARK: - Avatar + Info

    private func infoSection(profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            // Avatar placeholder (appicon)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.indigo.opacity(0.25), .purple.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 90, height: 90)
                    .overlay(Circle().stroke(Color.indigo.opacity(0.3), lineWidth: 2))

                Image("AppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
            }

            VStack(spacing: 4) {
                Text(profile.resolvedDisplayName)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                if let username = profile.username {
                    Text("@\(username)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Text("Player #\(profile.playerNumber)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Hearts

    private var heartsSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.lives)/\(viewModel.maxLives) cuori")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                if let config = viewModel.heartsConfig {
                    Text("Ricarica ogni \(config.heartRechargeMinutes) min")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<viewModel.maxLives, id: \.self) { i in
                    Image(systemName: i < viewModel.lives ? "heart.fill" : "heart")
                        .foregroundColor(i < viewModel.lives ? .red : .gray.opacity(0.35))
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - Edit

    private func editSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MODIFICA PROFILO")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .kerning(1.2)

            VStack(spacing: 12) {
                ProfileField(label: "Nome visualizzato", placeholder: "Il tuo nome", text: $editingName)
                ProfileField(label: "Username", placeholder: "nome_utente", text: $editingUsername, autocapitalize: false)
            }

            if let error = saveError {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
            }

            Button {
                Task { await saveProfile(profile: profile) }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else if saveSuccess {
                        Image(systemName: "checkmark")
                    } else {
                        Text("Salva")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
            }
            .disabled(isSaving)
            .onAppear {
                editingName = profile.displayName ?? ""
                editingUsername = profile.username ?? ""
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Loading / Offline

    private var loadingOrOffline: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Profilo non disponibile")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Text("Connettiti per caricare il tuo profilo")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Save

    private func saveProfile(profile: UserProfile) async {
        isSaving = true
        saveError = nil
        saveSuccess = false
        defer { isSaving = false }

        let newName = editingName.trimmingCharacters(in: .whitespaces)
        let newUsername = editingUsername.trimmingCharacters(in: .whitespaces)

        do {
            let updated = try await DataUserService.updateMe(
                displayName: newName.isEmpty ? nil : newName,
                username: newUsername.isEmpty ? nil : newUsername
            )
            await MainActor.run {
                viewModel.userProfile = updated
                saveSuccess = true
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { saveSuccess = false }
        } catch {
            await MainActor.run {
                saveError = "Errore nel salvataggio. Verifica i dati e riprova."
            }
        }
    }
}

// MARK: - ProfileField

private struct ProfileField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var autocapitalize: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .font(.system(size: 15, design: .rounded))
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                )
        }
    }
}

#Preview {
    ProfileView(viewModel: {
        let vm = GameViewModel()
        return vm
    }())
    .preferredColorScheme(.dark)
}
