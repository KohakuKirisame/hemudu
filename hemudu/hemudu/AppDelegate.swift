//
//  AppDelegate.swift
//  hemudu
//
//  Created by Ran Cao on 2017/2/26.
//  Copyright © 2017年 Ran Cao. All rights reserved.
//

import UIKit
import UserNotifications

let AliPush_key = "23705917"
let AliPush_Secret = "87750a79849c39f376f950588684f1fd"
let AliPush_MessageNoti = "CCPDidReceiveMessageNotification"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        //registerAppNotificationSettings(launchOptions: launchOptions as [NSObject : AnyObject]?)
        
        //initCloudPush(application: application)
        //CloudPushSDK.handleLaunching(launchOptions)
        
        // APNs注册，获取deviceToken并上报
        registerAPNs(application)
        // 初始化阿里云推送SDK
        initCloudPushSDK()
        // 监听推送通道打开动作
        listenOnChannelOpened()
        // 监听推送消息到达
        registerMessageReceive()
        // 点击通知将App从关闭状态启动时，将通知打开回执上报
        //CloudPushSDK.handleLaunching(launchOptions)(Deprecated from v1.8.1)
        CloudPushSDK.sendNotificationAck(launchOptions)
        
        return true
    }
    
    func registerAPNs(_ application: UIApplication) {
        if #available(iOS 10, *) {
            // iOS 10+
            let center = UNUserNotificationCenter.current()
            // 创建category，并注册到通知中心
            createCustomNotificationCategory()
            center.delegate = self
            // 请求推送权限
            center.requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { (granted, error) in
                if (granted) {
                    // User authored notification
                    print("User authored notification.")
                    // 向APNs注册，获取deviceToken
                    application.registerForRemoteNotifications()
                } else {
                    // User denied notification
                    print("User denied notification.")
                }
            })
        } else if #available(iOS 8, *) {
            // iOS 8+
            application.registerUserNotificationSettings(UIUserNotificationSettings.init(types: [.alert, .badge, .sound], categories: nil))
            application.registerForRemoteNotifications()
        } else {
            // < iOS 8
            application.registerForRemoteNotifications(matching: [.alert,.badge,.sound])
        }
    }
    
    // 创建自定义category，并注册到通知中心
    @available(iOS 10, *)
    func createCustomNotificationCategory() {
        let action1 = UNNotificationAction.init(identifier: "action1", title: "test1", options: [])
        let action2 = UNNotificationAction.init(identifier: "action2", title: "test2", options: [])
        let category = UNNotificationCategory.init(identifier: "test_category", actions: [action1, action2], intentIdentifiers: [], options: UNNotificationCategoryOptions.customDismissAction)
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // 初始化推送SDK
    func initCloudPushSDK() {
        // 打开Log，线上建议关闭
        CloudPushSDK.turnOnDebug()
        CloudPushSDK.asyncInit(AliPush_key, appSecret: AliPush_Secret) { (res) in
            if (res!.success) {
                print("Push SDK init success, deviceId: \(CloudPushSDK.getDeviceId()!)")
            } else {
                print("Push SDK init failed, error: \(res!.error!).")
            }
        }
    }
    
    // 监听推送通道是否打开
    func listenOnChannelOpened() {
        let notificationName = Notification.Name("CCPDidChannelConnectedSuccess")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(channelOpenedFunc(notification:)),
                                               name: notificationName,
                                               object: nil)
    }
    
    func channelOpenedFunc(notification : Notification) {
        print("Push SDK channel opened.")
    }
    
    // 注册消息到来监听
    func registerMessageReceive() {
        let notificationName = Notification.Name("CCPDidReceiveMessageNotification")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onMessageReceivedFunc(notification:)),
                                               name: notificationName,
                                               object: nil)
    }
    
    // 处理推送消息
    func onMessageReceivedFunc(notification : Notification) {
        print("Receive one message.")
        let pushMessage: CCPSysMessage = notification.object as! CCPSysMessage
        let title = String.init(data: pushMessage.title, encoding: String.Encoding.utf8)
        let body = String.init(data: pushMessage.body, encoding: String.Encoding.utf8)
        print("Message title: \(title!), body: \(body!).")
    }
    
    // App处于启动状态时，通知打开回调（< iOS 10）
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Receive one notification.")
        let aps = userInfo["aps"] as! [AnyHashable : Any]
        let alert = aps["alert"] ?? "none"
        let badge = aps["badge"] ?? 0
        let sound = aps["sound"] ?? "none"
        let extras = userInfo["Extras"]
        print("Notification, alert: \(alert), badge: \(badge), sound: \(sound), extras: \(extras).")
    }
    
    // 处理iOS 10通知(iOS 10+)
    @available(iOS 10.0, *)
    func handleiOS10Notification(_ notification: UNNotification) {
        let content: UNNotificationContent = notification.request.content
        let userInfo = content.userInfo
        // 通知时间
        let noticeDate = notification.date
        // 标题
        let title = content.title
        // 副标题
        let subtitle = content.subtitle
        // 内容
        let body = content.body
        // 角标
        let badge = content.badge ?? 0
        // 取得通知自定义字段内容，例：获取key为"Extras"的内容
        let extras = userInfo["Extras"]
        // 通知打开回执上报
        CloudPushSDK.sendNotificationAck(userInfo)
        print("Notification, date: \(noticeDate), title: \(title), subtitle: \(subtitle), body: \(body), badge: \(badge), extras: \(extras).")
    }
    
    // App处于前台时收到通知(iOS 10+)
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Receive a notification in foreground.")
        handleiOS10Notification(notification)
        // 通知不弹出
        completionHandler([])
        // 通知弹出，且带有声音、内容和角标
        //completionHandler([.alert, .badge, .sound])
    }
    
    // 触发通知动作时回调，比如点击、删除通知和点击自定义action(iOS 10+)
    @available(iOS 10, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userAction = response.actionIdentifier
        if userAction == UNNotificationDefaultActionIdentifier {
            print("User opened the notification.")
            // 处理iOS 10通知，并上报通知打开回执
            handleiOS10Notification(response.notification)
        }
        
        if userAction == UNNotificationDismissActionIdentifier {
            print("User dismissed the notification.")
        }
        
        let customAction1 = "action1"
        let customAction2 = "action2"
        if userAction == customAction1 {
            print("User touch custom action1.")
        }
        
        if userAction == customAction2 {
            print("User touch custom action2.")
        }
        
        completionHandler()
    }
    
    // APNs注册成功
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Get deviceToken from APNs success.")
        CloudPushSDK.registerDevice(deviceToken) { (res) in
            if (res!.success) {
                print("Upload deviceToken to Push Server, deviceToken: \(CloudPushSDK.getApnsDeviceToken()!)")
            } else {
                print("Upload deviceToken to Push Server failed, error: \(res?.error)")
            }
        }
    }
    
    // APNs注册失败
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Get deviceToken from APNs failed, error: \(error).")
    }
    
    
    /*
    func initCloudPush(application:UIApplication) {
        CloudPushSDK.asyncInit(AliPush_key, appSecret: AliPush_Secret, callback: nil)
        let settings = UIUserNotificationSettings(types: [.alert,.badge,.sound], categories: nil)
        if #available(iOS 8.0, *){
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
        registerMessageReceive()
    }
    
    func application(application:UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken:NSData) {
        CloudPushSDK.registerDevice(deviceToken as Data!, withCallback: nil)
        print(deviceToken)
    }
    
    func application(application:UIApplication, didFailToRegisterForRemoteNotificationsWithError error:NSError) {
        print("did fail to reg fo remote notif with error:\(error.localizedDescription)")
    }
    
    func registerMessageReceive() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.onMessageReceived(notification:)),name:NSNotification.Name(rawValue: AliPush_MessageNoti), object: nil)
    }
    
    func onMessageReceived(notification: NSNotification) {
        let message:CCPSysMessage = notification.object as! CCPSysMessage
        let title:NSString = NSString(data: message.title, encoding: String.Encoding.utf8.rawValue)!
        let body:NSString = NSString(data: message.body, encoding: String.Encoding.utf8.rawValue)!
        print("Received Mes title:\(title), centent:\(body)")
    }
    
    func application(application:UIApplication, didReceiveRemoteNotification userInfo:[NSObject:AnyObject]) {
        print("Receive one notif")
        /*
        let aps_dic:NSDictionary = userInfo["aps"] as! NSDictionary
        let content = aps_dic.value(forKey:"alert")
        let badge = aps_dic.value(forKey: "badge")?.integervalue
        let sound = aps_dic.value(forKey: "sounde")
        let extras = aps_dic.value(forKey: "Extras")
 */
        application.applicationIconBadgeNumber = 0
        CloudPushSDK.handleReceiveRemoteNotification(userInfo)
    }
*/
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
