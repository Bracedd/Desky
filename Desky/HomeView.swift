import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @EnvironmentObject var spotifyAuth: SpotifyAuth
    @State private var showSpotifyAlert = false
    @State private var showConnectionError = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let currentTrack = spotifyAuth.currentTrack {
                    playerView(for: currentTrack, in: geometry)
                } else {
                    connectButton
                }
                
            }
        }
        .onAppear {
            spotifyAuth.startPlaybackStateUpdates()
        }
        .onDisappear {
            spotifyAuth.stopPlaybackStateUpdates()
            spotifyAuth.disconnect()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSpotifyConnectionError"))) { _ in
            showConnectionError = true
        }
        .alert("Connection Error", isPresented: $showConnectionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Failed to connect to Spotify. Please try again.")
        }
    }
    
    private func playerView(for track: (title: String, artist: String, isPlaying: Bool, imageURL: URL?), in geometry: GeometryProxy) -> some View {
        HStack(spacing: 20) {
            albumArtView(for: track, in: geometry)
            
            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                
                Text(track.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                Button(action: {
                    spotifyAuth.setupAppRemote()
                }) {
                    Text("Refresh")
                        .foregroundColor(Color(hex: "b386da"))
                        .padding(.vertical, 8)
                }
                
                progressBar
                
                timeLabels
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            backgroundView(for: track)
        )
    }
    
    private func albumArtView(for track: (title: String, artist: String, isPlaying: Bool, imageURL: URL?), in geometry: GeometryProxy) -> some View {
        Group {
            if let imageURL = track.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: geometry.size.height * 0.7, height: geometry.size.height * 0.7)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.height * 0.7, height: geometry.size.height * 0.7)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black, radius: 50)
                    case .failure(_):
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.height * 0.5, height: geometry.size.height * 0.5)
                            .foregroundColor(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.height * 0.5, height: geometry.size.height * 0.5)
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
        .id(track.title)
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(15)
                
                if let playbackState = spotifyAuth.currentPlaybackState {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(playbackState.playbackPosition) / CGFloat(playbackState.track.duration), height: 4)
                        .cornerRadius(15)
                }
            }
        }
        .frame(height: 4)
    }
    
    private var timeLabels: some View {
        HStack {
            if let playbackState = spotifyAuth.currentPlaybackState {
                Text(formatTime(Int(playbackState.playbackPosition)))
                Spacer()
                Text(formatTime(Int(playbackState.track.duration)))
            } else {
                Text("0:00")
                Spacer()
                Text("0:00")
            }
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.6))
    }
    
    private func backgroundView(for track: (title: String, artist: String, isPlaying: Bool, imageURL: URL?)) -> some View {
        AsyncImage(url: track.imageURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.7))
                    .blur(radius: 50)
                    .edgesIgnoringSafeArea(.all)
                    .ignoresSafeArea()
            } else {
                Color.black
            }
        }
        .transition(.opacity)
        .id(track.title)
    }
    
    private var connectButton: some View {
        Button(action: {
            spotifyAuth.setupAppRemote()
        }) {
            ZStack {
                Color(hex: "2b2b2b")
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("Connect With Spotify")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .font(.system(size: 28))
                    
                    VStack(spacing: 10) {
                        Text("Steps to connect")
                            .fontWeight(.bold)
                        Text("1. Make Sure Spotify is downloaded and signed in")
                        Text("2. Click connect and let it authorize")
                        Text("3. You're ready to go!")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "B6B5B5"))
                    .multilineTextAlignment(.center)
                    
                    Text("*Require Spotify Premium For Playback Controls")
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "B386DA"))
                    
                    Text("Connect to Spotify")
                        .font(.system(size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(hex: "6B6B6B"))
                        .cornerRadius(25)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            // Include hours only if necessary
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            // Only show minutes and seconds
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    
    
    struct HomeView_Previews: PreviewProvider {
        static var previews: some View {
            HomeView()
                .environmentObject(LoginStatus())
                .environmentObject(SpotifyAuth())
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
