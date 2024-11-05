import SwiftUI

struct LoginView: View {
    @StateObject private var spotifyAuth = SpotifyAuth()
    @EnvironmentObject var loginStatus: LoginStatus
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack{
            
            Color(hex: "2b2b2b")
                .ignoresSafeArea()
            
            VStack() {
                if isAuthenticating {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Authenticating with Spotify...")
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(){
                    Text("welcome to")
                        .fontWeight(.bold)
                        .font(.system(size: 45))
                        .foregroundColor(.white)
                    
                    Text("DESKY")
                        .fontWeight(.heavy)
                        .font(.system(size: 92))
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
                        
                }
                
                    
                Spacer()
                
                Button(action: authenticateWithSpotify) {
                    HStack {
                        
                        Text("Login with Spotify")
                            .fontWeight(.bold)
                    }
                    .font(.headline)
                    .padding(.all, 5)
                    .frame(minWidth: 250)
                    .background(
                        Color(hex: "6b6b6b")
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(color: Color(hex: "000000").opacity(0.5), radius: 20, x: 0 , y: 15)
                }
                .disabled(isAuthenticating)
                .opacity(isAuthenticating ? 0.6 : 1)
            
                Spacer()
            }
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

// Preview for iPhone only
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView()
                .environmentObject(LoginStatus())
                .previewDevice("iPhone 15")
                .previewDisplayName("Light Mode")
            
            LoginView()
                .environmentObject(LoginStatus())
                .preferredColorScheme(.dark)
                .previewDevice("iPhone 15")
                .previewDisplayName("Dark Mode")
        }
    }
}
