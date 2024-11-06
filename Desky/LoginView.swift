import SwiftUI
import SpotifyiOS

struct LoginView: View {
    @StateObject private var spotifyAuth = SpotifyAuth()
    @EnvironmentObject var loginStatus: LoginStatus
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "2b2b2b")
                    .ignoresSafeArea()
                
                VStack {
                    if isAuthenticating {
                        VStack(spacing: geometry.size.height * 0.01) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Authenticating with Spotify...")
                                .foregroundColor(.secondary)
                                .font(.system(size: geometry.size.width * 0.05))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: geometry.size.height * 0.01) {
                        Text("welcome to")
                            .fontWeight(.bold)
                            .font(.system(size: geometry.size.width * 0.10))
                            .foregroundColor(.white)
                        
                        Text("DESKY")
                            .fontWeight(.heavy)
                            .font(.system(size: geometry.size.width * 0.24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "b386da"), Color(hex: "433d91")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("the only accessory you need on your desk")
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: "b6b5b5"))
                            .font(.system(size: geometry.size.width * 0.05))
                    }
                    
                    Spacer(minLength: geometry.size.height * 0.1)
                    
                    Button(action: authenticateWithSpotify) {
                        Text("Login with Spotify")
                            .fontWeight(.bold)
                            .font(.headline)
                            .frame(maxWidth: geometry.size.width * 0.7)
                            .padding(.vertical, geometry.size.height * 0.015)
                            .background(Color(hex: "6b6b6b"))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .shadow(color: Color(hex: "000000").opacity(0.5), radius: 20, x: 0, y: 15)
                    }
                    .disabled(isAuthenticating)
                    .opacity(isAuthenticating ? 0.6 : 1)
                    
                    Spacer()
                }
                .padding(.horizontal, geometry.size.width * 0.1)
                .animation(.easeInOut, value: isAuthenticating)
                .alert("Authentication Error",
                       isPresented: $showingError) {
                    Button("OK", role: .cancel) {
                        isAuthenticating = false
                    }
                } message: {
                    Text(errorMessage)
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
            "&scope=\(encodedScope)"
        
        guard let authURL = URL(string: authURLString) else {
            showingError = true
            errorMessage = "Could not create authorization URL"
            isAuthenticating = false
            return
        }
        
        // Open the authorization URL
        UIApplication.shared.open(authURL) { success in
            if !success {
                DispatchQueue.main.async {
                    self.showingError = true
                    self.errorMessage = "Could not open Spotify authorization page"
                    self.isAuthenticating = false
                }
            }
        }
    }
}

// Preview for iPhone only
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView()
                .environmentObject(LoginStatus())
                .previewDevice("iPhone 14")
                .previewDisplayName("Light Mode")
            
            LoginView()
                .environmentObject(LoginStatus())
                .preferredColorScheme(.dark)
                .previewDevice("iPhone 14")
                .previewDisplayName("Dark Mode")
        }
    }
}
