import SwiftUI

struct ContentView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @StateObject private var spotifyAuth = SpotifyAuth()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationView {
            Group {
                if spotifyAuth.isAuthenticated || loginStatus.isLoggedIn {
                    HomeView()
                        .transition(.slide)
                } else {
                    VStack(spacing: 20) {
                        if isAuthenticating {
                            VStack(spacing: 15) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Authenticating with Spotify...")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: authenticateWithSpotify) {
                            HStack {
                                Image(systemName: "music.note")
                                Text("Login with Spotify")
                            }
                            .font(.headline)
                            .padding()
                            .frame(minWidth: 200)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isAuthenticating)
                        .opacity(isAuthenticating ? 0.6 : 1)
                    }
                    .animation(.easeInOut, value: isAuthenticating)
                }
            }
            .alert("Authentication Error",
                isPresented: $showingError) {
                    Button("OK", role: .cancel) { 
                        isAuthenticating = false
                    }
                } message: {
                    Text(errorMessage)
                }
        }
        .onOpenURL { url in
            spotifyAuth.handleURL(url)
            isAuthenticating = false
        }
        .onChange(of: spotifyAuth.isAuthenticated) { newValue in
            if newValue {
                loginStatus.isLoggedIn = true
                print("🔄 Updated LoginStatus to match SpotifyAuth")
            }
        }
    }
    
    func authenticateWithSpotify() {
        isAuthenticating = true
        print("🎵 Starting Spotify authentication...")
        
        let encodedScope = Constants.scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRedirectURI = Constants.redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = "https://accounts.spotify.com/authorize" +
            "?client_id=\(Constants.spotifyClientID)" +
            "&response_type=code" +
            "&redirect_uri=\(encodedRedirectURI)" +
            "&scope=\(encodedScope)" +
            "&show_dialog=true"
        
        guard let url = URL(string: authURLString) else {
            showingError = true
            errorMessage = "Failed to create authentication URL"
            isAuthenticating = false
            return
        }
        
        UIApplication.shared.open(url) { success in
            if !success {
                DispatchQueue.main.async {
                    showingError = true
                    errorMessage = "Failed to open Spotify authentication"
                    isAuthenticating = false
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
