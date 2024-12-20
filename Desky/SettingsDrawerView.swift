import SwiftUI

struct SettingsDrawerView: View {
    @EnvironmentObject var spotifyAuth: SpotifyAuth
    @EnvironmentObject var loginStatus: LoginStatus
    @Binding var isPresented: Bool
    @State private var showingLogoutAlert = false
    @AppStorage("autoConnectSpotify") private var autoConnectSpotify = true
    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @State private var dragOffset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop
                Color.black.opacity(0.7)
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
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            dismissDrawer()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(Color(hex: "b6b5b5"))
                        }
                    }
                    .padding()
                    .background(Color(hex: "2b2b2b"))
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            settingsGroup {
                                toggleRow(title: "Auto-connect Spotify", icon: "music.note", isOn: $autoConnectSpotify)
                            }
                            
                            settingsGroup {
                                toggleRow(title: "24-Hour Format", icon: "clock", isOn: $use24HourFormat)
                            }
                            
                            settingsGroup {
                                Button(action: {
                                    showingLogoutAlert = true
                                }) {
                                    HStack {
                                        Label("Logout from Spotify", systemImage: "arrow.right.circle")
                                        Spacer()
                                    }
                                    .foregroundStyle(Color(hex: "ff0000"))
                                }
                            }
                            
                            Text("Version 1.0.0")
                                .font(.footnote)
                                .foregroundColor(Color(hex: "b6b5b5"))
                                .padding(.top, 8)
                        }
                        .padding()
                    }
                }
                .frame(width: min(400, geometry.size.width * 0.8))
                .background(Color(hex: "2b2b2b"))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: -10, y: 0)
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
        .background(Color(hex: "6b6b6b").opacity(0.2))
        .cornerRadius(15)
    }
    
    private func toggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Label {
                Text(title)
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "b386da"))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "b386da")))
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


