import SwiftUI

struct ContentView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @State private var selectedTab: FloatingTabBar.Tab = .home
    
    var body: some View {
        ZStack {
            if loginStatus.isLoggedIn {
                Color.black
                    .ignoresSafeArea()
                
                ZStack(alignment: .bottom) { // Changed to .top
                    TabView(selection: $selectedTab) {
                        HomeView()
                            .tag(FloatingTabBar.Tab.home)
                        
                        TimeView()
                            .tag(FloatingTabBar.Tab.time)
                        
                        WeatherView()
                            .tag(FloatingTabBar.Tab.weather)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    FloatingTabBar(selectedTab: $selectedTab)
                        .padding(.bottom, 15) // Changed to top padding
                }
                .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }
}
