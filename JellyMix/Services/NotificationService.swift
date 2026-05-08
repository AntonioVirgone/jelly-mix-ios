//
//  NotificationService.swift
//  JellyMix
//

import Foundation
import UserNotifications

enum NotificationService {

    private static let categoryLivesRestored = "LIVES_RESTORED"
    private static let identifierPrefix = "life_restore_"

    // MARK: - Permessi

    // Richiede il permesso per le notifiche locali e remote.
    // Il sistema memorizza la scelta dell'utente: viene mostrato una sola volta.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { print("[Notifications] Errore permesso: \(error.localizedDescription)") }
        }
    }

    // MARK: - FCM token (remote push)

    // Salva il token FCM e lo registra sul backend con backoff esponenziale.
    // Chiamato da MessagingDelegate all'avvio e ad ogni refresh del token.
    static func registerFCMToken(_ token: String) async {
        UserDefaults.standard.set(token, forKey: "fcmDeviceToken")
        await registerWithBackoff(token: token, attempt: 1)
    }

    // Rimuove il token dal backend. Da chiamare in caso di logout.
    static func unregisterFCMToken() async {
        guard let token = UserDefaults.standard.string(forKey: "fcmDeviceToken") else { return }
        do {
            let _: EmptyResponse = try await CommonService.request(
                from: "notifications/token/\(token)",
                method: .delete
            )
            UserDefaults.standard.removeObject(forKey: "fcmDeviceToken")
            print("[FCM] Token rimosso dal backend.")
        } catch {
            print("[FCM] Errore rimozione token: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifiche locali (ripristino vite)

    // Pianifica una notifica locale per ogni vita che verrà ripristinata in background.
    // Cancella qualsiasi pianificazione precedente prima di creare quella nuova.
    static func scheduleLivesRestoredNotifications(currentLives: Int, maxLives: Int, timeToNextLife: Int, secondsPerLife: Int) {
        guard currentLives < maxLives else { return }

        cancelPendingLivesNotifications()

        var delay = TimeInterval(timeToNextLife)
        var livesCount = currentLives + 1

        while livesCount <= maxLives {
            let isLast = livesCount == maxLives
            let content = makeLivesContent(lives: livesCount, maxLives: maxLives, isLast: isLast)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
            let lifeIndex = livesCount
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(lifeIndex)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("[Notifications] Scheduling vita \(lifeIndex): \(error.localizedDescription)") }
            }

            livesCount += 1
            delay += TimeInterval(secondsPerLife)
        }
    }

    // Rimuove le notifiche di ripristino vite pendenti.
    // Chiamato quando l'app torna in foreground: il timer in-app gestisce le vite.
    static func cancelPendingLivesNotifications() {
        let identifiers = (1...5).map { "\(identifierPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Private

    private static func registerWithBackoff(token: String, attempt: Int) async {
        guard attempt <= 3 else {
            print("[FCM] Registrazione abbandonata dopo 3 tentativi.")
            return
        }
        do {
            let body = FCMTokenBody(token: token, platform: "ios")
            let _: EmptyResponse = try await CommonService.request(
                from: "notifications/register",
                method: .post,
                body: body
            )
            print("[FCM] Token registrato (tentativo \(attempt)).")
        } catch {
            let delaySec = pow(2.0, Double(attempt)) // 2s → 4s → 8s
            print("[FCM] Tentativo \(attempt) fallito, retry tra \(Int(delaySec))s.")
            try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
            await registerWithBackoff(token: token, attempt: attempt + 1)
        }
    }

    private static func makeLivesContent(lives: Int, maxLives: Int, isLast: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = categoryLivesRestored

        if isLast {
            content.title = "Cuori al massimo! ❤️"
            content.body = "Hai \(maxLives) cuori. Torna a giocare con JellyMix!"
        } else {
            content.title = "Vita ripristinata! ❤️"
            content.body = "Hai \(lives) cuori. Ancora \(maxLives - lives) alla ricarica completa."
        }

        content.sound = .default
        return content
    }
}

// MARK: - Request body

private struct FCMTokenBody: Encodable {
    let token: String
    let platform: String
}
