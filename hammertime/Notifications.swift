//
//  Notifications.swift
//  hammertime
//

import Foundation
import UserNotifications

enum NotificationManager {
    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = ForegroundNotificationDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            #if DEBUG
            if let error { print("[Notify] auth error: \(error)") }
            print("[Notify] granted=\(granted)")
            #endif
        }
    }

    static func scheduleRestDone(after seconds: Int) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let req = UNNotificationRequest(identifier: "rest-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { error in
            #if DEBUG
            if let error { print("[Notify] schedule error: \(error)") }
            #endif
        }
    }
}

// Ensure sound plays when app is in foreground
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationDelegate()
    private override init() { super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound])
    }
}


