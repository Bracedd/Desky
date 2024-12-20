import SwiftUI

struct HomeView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    @EnvironmentObject var spotifyAuth: SpotifyAuth
    @State private var showSpotifyAlert = false
    @State private var showConnectionError = false
    @State private var isConnecting = false
    @State private var progress: Double = 0.0
    @State private var isTrackChanged = false
    @State private var progressTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let currentTrack = spotifyAuth.currentTrack {
                    playerView(for: currentTrack, in: geometry)
                        .opacity(isTrackChanged ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: isTrackChanged)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TrackDidChange"))) { _ in
                            isTrackChanged.toggle()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isTrackChanged.toggle()
                            }
                        }
                } else {
                    connectButton
                }
            }
        }
        .onDisappear {
            stopProgressTimer()
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
            // Album Artwork
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
                .opacity(isTrackChanged ? 0.5 : 1.0)
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
            
            // Track Info and Progress
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
                    Text(formatTime(Int(progress * 3 * 60)))
                    Spacer()
                    Text(formatTime(3 * 60))
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
                        .ignoresSafeArea()
                } else {
                    Color.black
                }
            }
        )
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
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
                    
                    Text(isConnecting ? "Connecting..." : "Connect to Spotify")
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
        .disabled(isConnecting)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func startProgressTimer() {
        stopProgressTimer() // Stop existing timer if any
        progress = 0.0
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.progress < 1.0 {
                self.progress += 1.0 / (30.0 * 60.0)
            } else {
                self.stopProgressTimer()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
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

