import SwiftUI

@main
struct DeskyApp: App {
    @StateObject private var loginStatus = LoginStatus()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(loginStatus)
        }
    }
}
