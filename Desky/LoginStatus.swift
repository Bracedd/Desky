import SwiftUI
import Combine

class LoginStatus: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
            
            // Update orientation when login status changes
            if isLoggedIn {
                AppDelegate.orientationLock = .landscape
                // Force the orientation change for iOS 15
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            } else {
                AppDelegate.orientationLock = .all
            }
        }
    }
    
    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        // Set initial orientation based on login status
        if isLoggedIn {
            AppDelegate.orientationLock = .landscape
            // Force the orientation change for iOS 15
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        }
    }
}
