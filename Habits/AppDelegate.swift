//
//  AppDelegate.swift
//  Habits
//
//  Created by Diego Sierra on 13/01/23.
//

import UIKit
import BackgroundTasks
import UserNotifications

@available(iOS 16.0, *)
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let temporaryDirectory = NSTemporaryDirectory()
        let urlCache = URLCache(memoryCapacity: 25_000_000, diskCapacity: 50_000_000, diskPath: temporaryDirectory)
        URLCache.shared = urlCache
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "HomeRefresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        notificationPermission()
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(scheduleNotification()) { (error) in
            if error != nil {
                print("Notifications could not be delievered")
            }
        }
        let checkHabitAction = UNNotificationAction(identifier: Habit.showHabitStats, title: "Check Habit", options: [])
        let habitsNotificationCategory = UNNotificationCategory(identifier: Habit.notificationCategoryId, actions: [checkHabitAction], intentIdentifiers: [], options: [])
        notificationCenter.setNotificationCategories([habitsNotificationCategory])
        notificationCenter.delegate = self
        
        
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print(token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if let homeCollectionViewController = storyboard.instantiateViewController(withIdentifier: "HomeCollectionViewController") as? HomeCollectionViewController, let tabBarController = self.window?.rootViewController as? UITabBarController, let navController = tabBarController.selectedViewController as? UINavigationController? {
            navController?.pushViewController(homeCollectionViewController, animated: true)
    
        }
        
        completionHandler()
    }
    
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
        print("Scheduled")
    }
    
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "HomeRefresh")
        
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let operations = Operations.performApplicationUpdates()
        let lastOpertation = operations.last!
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        lastOpertation.completionBlock = {
            task.setTaskCompleted(success: !lastOpertation.isCancelled)
        }
        
        queue.addOperations(operations, waitUntilFinished: false)
        
        print("Handled App Refresh")
        
    }
    
    
    func notificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print(error)
            } else {
                print("Permission granted \(granted)")
            }
        }
    }
    
    func scheduleNotification() -> UNNotificationRequest {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Another user is taking the lead on a habit"
        notificationContent.body = "Jump in to see who's taking the lead in one of your previously logged habits"
        notificationContent.categoryIdentifier = Habit.notificationCategoryId
        notificationContent.sound = UNNotificationSound.defaultRingtone
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (5), repeats: false)
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: notificationContent, trigger: trigger)
        
        return request
    }
}

