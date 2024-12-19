import SwiftUI

struct ContentView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @EnvironmentObject var spotifyAuth: SpotifyAuth
    @State private var selectedTab: FloatingTabBar.Tab = .home
    @State private var isTabBarVisible = false
    @State private var hideTabBarTask: DispatchWorkItem?
    @State private var isSettingsPresented = false
    
    var body: some View {
        ZStack {
            if loginStatus.isLoggedIn {
                Color.black
                    .ignoresSafeArea()
                
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        HomeView()
                            .environmentObject(spotifyAuth)
                            .tag(FloatingTabBar.Tab.home)
                        
                        TimeView()
                            .tag(FloatingTabBar.Tab.time)
                        
                        WeatherView()
                            .tag(FloatingTabBar.Tab.weather)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    FloatingTabBar(selectedTab: $selectedTab, isVisible: $isTabBarVisible, onSettingsTap: {
                        withAnimation {
                            isSettingsPresented = true
                        }
                    })
                    .padding(.bottom, 15)
                }
                .transition(.opacity)
                .contentShape(Rectangle())
                .onTapGesture {
                    showTabBar()
                }
                
                SettingsDrawerView(isPresented: $isSettingsPresented)
                    .environmentObject(spotifyAuth)
                    .environmentObject(loginStatus)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            showTabBar()
        }
    }
    
    private func showTabBar() {
        hideTabBarTask?.cancel()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTabBarVisible = true
        }
        
        let task = DispatchWorkItem {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTabBarVisible = false
            }
        }
        
        hideTabBarTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }
    
    private func logout() {
        loginStatus.isLoggedIn = false
        selectedTab = .home
    }
}	
