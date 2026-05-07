//
//  NotificationService.swift
//  JellyMix
//

import Foundation
import UserNotifications

enum NotificationService {

    private static let categoryID = "LIVES_RESTORED"
    private static let identifierPrefix = "life_restore_"

    // Richiede il permesso per le notifiche locali.
    // Chiamato una volta sola all'avvio — il sistema memorizza la scelta dell'utente.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("[Notifications] Errore permesso: \(error.localizedDescription)") }
        }
    }

    // Pianifica una notifica per ogni vita che verrà ripristinata mentre l'app è in background.
    // Cancella prima qualsiasi notifica pendente per evitare duplicati.
    static func scheduleLivesRestoredNotifications(currentLives: Int, maxLives: Int, timeToNextLife: Int, secondsPerLife: Int) {
        guard currentLives < maxLives else { return }

        cancelPendingNotifications()

        var delay = TimeInterval(timeToNextLife)
        var livesCount = currentLives + 1

        while livesCount <= maxLives {
            let isLast = livesCount == maxLives
            let content = makeContent(lives: livesCount, maxLives: maxLives, isLast: isLast)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
            let lifeIndex = livesCount
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(lifeIndex)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("[Notifications] Errore scheduling vita \(lifeIndex): \(error.localizedDescription)") }
            }

            livesCount += 1
            delay += TimeInterval(secondsPerLife)
        }
    }

    // Rimuove tutte le notifiche di ripristino vite pendenti.
    // Chiamato quando l'app torna in foreground (il timer in-app gestisce le vite).
    static func cancelPendingNotifications() {
        let identifiers = (1...5).map { "\(identifierPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Private

    private static func makeContent(lives: Int, maxLives: Int, isLast: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = categoryID

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
