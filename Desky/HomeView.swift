import SwiftUI

struct HomeView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @StateObject private var spotifyAuth = SpotifyAuth()
    @State private var showSpotifyAlert = false
    @State private var showConnectionError = false
    @State private var isConnecting = false
    @State private var progress: Double = 0.0
    @State private var isTrackChanged = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let currentTrack = spotifyAuth.currentTrack {
                    playerView(for: currentTrack, in: geometry)
                        .opacity(isTrackChanged ? 0.5 : 1.0) // Adjust opacity here
                        .animation(.easeInOut(duration: 0.5), value: isTrackChanged)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TrackDidChange"))) { _ in
                            isTrackChanged.toggle() // Toggle to trigger animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isTrackChanged.toggle() // Reset after animation completes
                            }
                        }
                } else {
                    connectButton
                }
            }
        }
        .onDisappear {
            spotifyAuth.disconnect()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSpotifyConnectionError"))) { _ in
            showConnectionError = true
        }
    }
    
    private func playerView(for track: (title: String, artist: String, isPlaying: Bool, imageURL: URL?), in geometry: GeometryProxy) -> some View {
        HStack(spacing: 20) {
            // Left side: Album Artwork with animation on opacity
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
                            .shadow(color: .black, radius: 25)
                            .padding(.bottom, geometry.size.height * 0.1)
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
                .opacity(isTrackChanged ? 0.5 : 1.0) // Add opacity animation here as well
                .animation(.easeInOut(duration: 0.5), value: isTrackChanged)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.height * 0.5, height: geometry.size.height * 0.5)
                    .foregroundColor(.white)
                    .opacity(isTrackChanged ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.5), value: isTrackChanged)
            }
            
            // Right side: Track Info and Progress
            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                
                
                Text( track.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                

                
                
                Text(track.artist)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(15)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                            .cornerRadius(15)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(formatTime(Int(progress * 3 * 60))) // Assuming 3 minutes max duration
                    Spacer()
                    Text(formatTime(3 * 60)) // 3 minutes in seconds
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            AsyncImage(url: track.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay(Color.black.opacity(0.7))
                        .blur(radius: 50)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black
                }
            }
        )
        .onAppear {
            // Start updating progress
            startProgressTimer()
        }
        .onDisappear {
            // Stop updating progress
            stopProgressTimer()
        }
    }
    
    private var connectButton: some View {
        Button(action: {
            isConnecting = true
            spotifyAuth.setupAppRemote()
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                isConnecting = false
            }
        }) {
            ZStack {
                Color(hex: "2b2b2b")
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Connect With Spotify To Get Started!")
                        .foregroundColor(.white)
                        .fontWeight(.heavy)
                        .padding(.bottom, 25)
                        .font(.system(size: 32))
                    
                    Text(isConnecting ? "Connecting..." : "Connect to Spotify")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(20)
                }
            }
        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(isConnecting)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func startProgressTimer() {
        // Reset progress
        progress = 0.0
        
        // Start a timer to update progress
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.progress < 1.0 {
                self.progress += 1.0 / (30.0 * 60.0) // Assuming 30 minutes max duration
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopProgressTimer() {
        // This method would be called to stop the progress timer if needed
    }
}



struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(LoginStatus())
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
    
