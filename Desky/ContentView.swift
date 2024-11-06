import SwiftUI

struct ContentView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    
    var body: some View {
        NavigationView {
            Group {
                if loginStatus.isLoggedIn {
                    HomeView()
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(LoginStatus())
    }
}
