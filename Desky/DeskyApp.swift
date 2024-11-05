import SwiftUI


@main
struct DeskyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // Use the custom AppDelegate
    @StateObject private var loginStatus = LoginStatus()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(loginStatus)
                .onChange(of: loginStatus.isLoggedIn) { isLoggedIn in
                    // Lock orientation to landscape after login
                    AppDelegate.orientationLock = isLoggedIn ? .landscape : .all
                    if isLoggedIn {
                        UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
                    }
                }
        }
    }
}
