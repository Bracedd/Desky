import SwiftUI

struct HomeView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @StateObject private var spotifyAuth = SpotifyAuth()
    @State private var showSpotifyAlert = false
    @State private var showPlaybackAlert = false
    @State private var isConnecting = false
    @State private var showConnectionError = false
    
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
                    
                    // Album Artwork
                    if let imageURL = currentTrack.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(8)
                            case .failure(_):
                                Image(systemName: "music.note")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                                    .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                            .frame(width: 200, height: 200)
                    }
                    
                    Text(currentTrack.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(currentTrack.artist)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // Show playing status
                    HStack {
                        Image(systemName: currentTrack.isPlaying ? "music.note" : "pause.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text(currentTrack.isPlaying ? "Playing" : "Paused")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 5)
                
                // Manual refresh button
                Button(action: {
                    spotifyAuth.requestPlayerState()
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
                .padding(.top)
            } else {
                VStack(spacing: 10) {
                    if !spotifyAuth.isConnected {
                        VStack(spacing: 15) {
                            Text("Connect with Spotify")
                                .font(.headline)
                            
                            Button(action: {
                                isConnecting = true
                                // First ensure Spotify is running and then connect
                                if let spotifyURL = URL(string: "spotify:") {
                                    UIApplication.shared.open(spotifyURL) { success in
                                        if success {
                                            // Give Spotify time to fully launch
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                spotifyAuth.setupAppRemote()
                                            }
                                        }
                                        // Reset connecting state after a timeout
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                            isConnecting = false
                                        }
                                    }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSpotifyConnectionError"))) { _ in
            showConnectionError = true
        }
        .alert(isPresented: $showConnectionError) {
            Alert(
                title: Text("Connection Failed"),
                message: Text("Please make sure Spotify is open and playing music, then try connecting again."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
