import SwiftUI

struct HomeView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @StateObject private var spotifyAuth = SpotifyAuth()
    @State private var showSpotifyAlert = false
    @State private var showPlaybackAlert = false
    @State private var isConnecting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Desky!")
                .font(.largeTitle)
                .padding()
            
            if let currentTrack = spotifyAuth.currentTrack {
                VStack(spacing: 10) {
                    Text("Now Playing")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(currentTrack.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(currentTrack.artist)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: currentTrack.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 5)
            } else {
                VStack(spacing: 10) {
                    if !spotifyAuth.isConnected {
                        Button(action: {
                            if let spotifyURL = URL(string: "spotify:"), UIApplication.shared.canOpenURL(spotifyURL) {
                                UIApplication.shared.open(spotifyURL) { success in
                                    if success {
                                        showPlaybackAlert = true
                                    }
                                }
                            } else {
                                showSpotifyAlert = true
                            }
                        }) {
                            Text("Connect to Spotify")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    } else if spotifyAuth.currentTrack == nil {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Connecting to Spotify...")
                            .foregroundColor(.secondary)
                    }
                    
                    if showPlaybackAlert {
                        VStack(spacing: 8) {
                            Text("Please follow these steps:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("1. Open Spotify")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("2. Start playing any song")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("3. Come back and tap 'Connect'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                isConnecting = true
                                spotifyAuth.setupAppRemote()
                                // Reset connecting state after a timeout
                                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                    isConnecting = false
                                }
                            }) {
                                HStack {
                                    if isConnecting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 5)
                                    }
                                    Text(isConnecting ? "Connecting..." : "Connect")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                            .disabled(isConnecting)
                            .opacity(isConnecting ? 0.6 : 1)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                }
            }
        }
        .padding()
        .onDisappear {
            spotifyAuth.disconnect()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSpotifyPlaybackAlert"))) { _ in
            showPlaybackAlert = true
        }
        .alert(isPresented: $showSpotifyAlert) {
            Alert(
                title: Text("Spotify Required"),
                message: Text("Please install Spotify from the App Store and start playing music to use this feature."),
                primaryButton: .default(Text("Open App Store")) {
                    if let url = URL(string: "itms-apps://apple.com/app/spotify") {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
