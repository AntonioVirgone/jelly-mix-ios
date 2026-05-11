//
//  AppDelegate.swift
//  JellyMix
//

import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        // Cold start: l'app è stata aperta dal tap di una push.
        // Le notifiche interne vengono postate con un ritardo minimo perché
        // i listener SwiftUI si registrano dopo didFinishLaunchingWithOptions.
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.handleWorldUpdatePayload(userInfo, navigateToMap: true)
            }
        }

        return true
    }

    // MARK: - APNs token

    // Firebase richiede il token APNs per mappar internamente il token FCM.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNS] Registrazione fallita: \(error.localizedDescription)")
    }

    // MARK: - Remote notification (data-only / content-available)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        handleWorldUpdatePayload(userInfo, navigateToMap: false)
        completionHandler(.newData)
    }

    // MARK: - Payload handling

    // Unico punto in cui viene interpretato il payload FCM.
    // Posta le notifiche interne che JellyMixApp e MainCoordinator ascoltano.
    func handleWorldUpdatePayload(_ userInfo: [AnyHashable: Any], navigateToMap: Bool) {
        guard let type = userInfo["type"] as? String,
              type == "WORLD_CREATED" || type == "WORLD_UPDATED" else { return }

        NotificationCenter.default.post(
            name: .mapUpdatePushReceived,
            object: nil,
            userInfo: [
                "type": type,
                "worldName": userInfo["worldName"] as? String ?? ""
            ]
        )

        if navigateToMap {
            NotificationCenter.default.post(name: .openMapFromNotification, object: nil)
        }
    }
}

// MARK: - MessagingDelegate (FCM token)

extension AppDelegate: MessagingDelegate {

    // Chiamato all'avvio e ogni volta che Firebase rinnova il token FCM.
    // Ri-registriamo sempre per mantenere il backend allineato al token corrente.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { await NotificationService.registerFCMToken(fcmToken) }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // App in foreground: mostra il banner e aggiorna subito i dati della mappa.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleWorldUpdatePayload(notification.request.content.userInfo, navigateToMap: false)
        completionHandler([.banner, .sound])
    }

    // Tap sulla notifica (da background o foreground): aggiorna i dati e naviga alla mappa.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleWorldUpdatePayload(userInfo, navigateToMap: true)
        // Tap su notifica locale (ripristino vite) → naviga alla mappa comunque.
        NotificationCenter.default.post(name: .openMapFromNotification, object: nil)
        completionHandler()
    }
}

// MARK: - Notification.Name

extension Notification.Name {
    /// Postata quando arriva WORLD_CREATED o WORLD_UPDATED: JellyMixApp chiama backgroundRefresh().
    static let mapUpdatePushReceived = Notification.Name("mapUpdatePushReceived")
    /// Postata al tap di una notifica: MainCoordinator naviga a .map.
    static let openMapFromNotification = Notification.Name("openMapFromNotification")
}
