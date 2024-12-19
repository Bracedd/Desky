import SwiftUI

@main
struct DeskyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var loginStatus = LoginStatus()
    @StateObject private var spotifyAuth = SpotifyAuth()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(loginStatus)
                .environmentObject(spotifyAuth)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    // Ensure orientation is set correctly when app appears
                    if loginStatus.isLoggedIn {
                        AppDelegate.orientationLock = .landscape
                        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                    }
                }
        }
    }
}

