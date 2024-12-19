import SwiftUI

struct SettingsDrawerView: View {
    @EnvironmentObject var spotifyAuth: SpotifyAuth
    @EnvironmentObject var loginStatus: LoginStatus
    @Binding var isPresented: Bool
    @State private var showingLogoutAlert = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("autoConnectSpotify") private var autoConnectSpotify = true
    @State private var dragOffset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .opacity(opacity)
                    .onTapGesture {
                        dismissDrawer()
                    }
                
                // Drawer Content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.title2.bold())
                        Spacer()
                        Button {
                            dismissDrawer()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            settingsGroup {
                                toggleRow(title: "Dark Mode", icon: "moon.fill", isOn: $isDarkMode)
                            }
                            
                            settingsGroup {
                                toggleRow(title: "Auto-connect Spotify", icon: "music.note", isOn: $autoConnectSpotify)
                            }
                            
                            settingsGroup {
                                Button(action: {
                                    showingLogoutAlert = true
                                }) {
                                    HStack {
                                        Label("Logout from Spotify", systemImage: "arrow.right.circle")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(.red)
                                }
                            }
                            
                            settingsGroup {
                                HStack {
                                    Label("Version", systemImage: "info.circle")
                                    Spacer()
                                    Text("1.0.0")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
                .mask(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, x: -5, y: 0)
                .offset(x: dragOffset)
                .offset(x: isPresented ? 0 : geometry.size.width)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > geometry.size.width / 3 {
                                dismissDrawer()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
        .onChange(of: isPresented) { newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                opacity = newValue ? 1 : 0
            }
        }
        .alert(isPresented: $showingLogoutAlert) {
            Alert(
                title: Text("Logout from Spotify"),
                message: Text("Are you sure you want to logout?"),
                primaryButton: .destructive(Text("Logout")) {
                    withAnimation {
                        spotifyAuth.logout()
                        loginStatus.isLoggedIn = false
                        dismissDrawer()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func toggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }
    
    private func dismissDrawer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresented = false
            dragOffset = 0
        }
    }
}

struct SettingsDrawerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDrawerView(isPresented: .constant(true))
            .environmentObject(SpotifyAuth())
            .environmentObject(LoginStatus())
            .preferredColorScheme(.dark)
    }
}


