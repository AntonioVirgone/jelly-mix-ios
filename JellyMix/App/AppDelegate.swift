//
//  AppDelegate.swift
//  JellyMix
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Registrazione APNs: richiede sempre il token anche per le push silenziose.
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - APNs token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.saveDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNS] Registrazione fallita: \(error.localizedDescription)")
    }

    // MARK: - Remote notification (foreground e background)
    //
    // Invocato quando arriva una push con `content-available: 1` oppure quando l'utente
    // tappa una push alert. Il backend deve includere "type": "map_update" nel payload.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let type = userInfo["type"] as? String, type == "map_update" else {
            completionHandler(.noData)
            return
        }

        // Pubblica un evento interno: JellyMixApp lo ascolta e chiama backgroundRefresh().
        NotificationCenter.default.post(name: .mapUpdatePushReceived, object: nil)
        completionHandler(.newData)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Mostra le notifiche locali (ripristino vite) anche quando l'app è in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Invocato quando l'utente tappa la notifica (locale o remota).
    // Naviga alla mappa in modo che l'utente possa subito scegliere un livello.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(name: .openMapFromNotification, object: nil)
        completionHandler()
    }
}

// MARK: - Notification.Name

extension Notification.Name {
    /// Postata dall'AppDelegate quando arriva una push remota di tipo "map_update".
    static let mapUpdatePushReceived = Notification.Name("mapUpdatePushReceived")
    /// Postata quando l'utente tappa qualsiasi notifica: naviga alla schermata mappa.
    static let openMapFromNotification = Notification.Name("openMapFromNotification")
}
