import UIKit
import AppsFlyerLib

class AppDelegate: NSObject, UIApplicationDelegate {
    var orientationLock: UIInterfaceOrientationMask = .portrait
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        AppsFlyerLib.shared().isDebug = true
        
        AppsFlyerLib.shared().appsFlyerDevKey = "MCaesbL7TBCb8DhNice8vS"
        AppsFlyerLib.shared().appleAppID = "6765881339"
        AppsFlyerLib.shared().delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: NSSelectorFromString("sendLaunch"),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        return true
    }
    
    @objc func sendLaunch() {
        AppsFlyerLib.shared().start { dictionary, error in
            if let error = error {
                print("AppsFlyer start error: \(error.localizedDescription)")
                return
            }
            if let dictionary = dictionary {
                print("AppsFlyer start success: \(dictionary)")
            }
        }
        
        let appsFlyerID = AppsFlyerLib.shared().getAppsFlyerUID()
        print("AppsFlyer ID: \(appsFlyerID)")
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return orientationLock
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        print("Conversion data: \(installData)")
        
        if let status = installData["af_status"] as? String {
            if status == "Non-organic" {
                if let sourceID = installData["media_source"],
                   let campaign = installData["campaign"] {
                    print("This is a Non-organic install. Media source: \(sourceID)  Campaign: \(campaign)")
                }
            } else {
                print("This is an Organic install.")
            }
        }
    }
    
    func onConversionDataFail(_ error: Error) {
        print("\(error)")
    }
}
