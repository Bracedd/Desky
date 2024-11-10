import SwiftUI

struct ContentView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @State private var selectedTab: FloatingTabBar.Tab = .home
    @State private var isTabBarVisible = false
    @State private var hideTabBarTask: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            if loginStatus.isLoggedIn {
                Color.black
                    .ignoresSafeArea()
                
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        HomeView()
                            .tag(FloatingTabBar.Tab.home)
                        
                        TimeView()
                            .tag(FloatingTabBar.Tab.time)
                        
                        WeatherView()
                            .tag(FloatingTabBar.Tab.weather)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    FloatingTabBar(selectedTab: $selectedTab, isVisible: $isTabBarVisible)
                        .padding(.bottom, 15)
                }
                .transition(.opacity)
                .contentShape(Rectangle()) // Makes the entire view tappable
                .onTapGesture {
                    showTabBar()
                }
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Show tab bar initially
            showTabBar()
        }
    }
    
    private func showTabBar() {
        // Cancel any existing hide task
        hideTabBarTask?.cancel()
        
        // Show the tab bar
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTabBarVisible = true
        }
        
        // Create new task to hide tab bar after 10 seconds
        let task = DispatchWorkItem {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTabBarVisible = false
            }
        }
        
        hideTabBarTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: task)
    }
}
