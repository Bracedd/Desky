import SwiftUI
import SpotifyiOS
import Combine

class SpotifyAuth: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        }
    }
    
    @Published var currentTrack: (title: String, artist: String, isPlaying: Bool, imageURL: URL?)?
    @Published var isConnected: Bool = false {
        didSet {
            UserDefaults.standard.set(isConnected, forKey: "spotifyConnected")
            if isConnected {
                UserDefaults.standard.set(Date(), forKey: "lastSpotifyConnection")
            }
        }
    }
    
    private var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "spotifyAccessToken")
                UserDefaults.standard.set(Date(), forKey: "tokenTimestamp")
                if !isConnected {
                    setupAppRemote()
                }
            }
        }
    }
    
    private lazy var appRemote: SpotifyiOS.SPTAppRemote = {
        let configuration = SpotifyiOS.SPTConfiguration(clientID: Constants.spotifyClientID, redirectURL: URL(string: Constants.redirectURI)!)
        let appRemote = SpotifyiOS.SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.delegate = self
        return appRemote
    }()
    
    private var isReconnecting = false
    private var reconnectionTimer: Timer?
    
    override init() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        isConnected = UserDefaults.standard.bool(forKey: "spotifyConnected")
        accessToken = UserDefaults.standard.string(forKey: "spotifyAccessToken")
        
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillTerminate() {
        UserDefaults.standard.synchronize()
    }
    
    @objc private func handleAppDidBecomeActive() {
        // Cancel any existing timer
        reconnectionTimer?.invalidate()
        
        if isAuthenticated && appRemote.isConnected {
            // Add a small delay to ensure proper state restoration
            isReconnecting = true
            reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                print("🔄 Restoring connection after app switch...")
                self?.appRemote.connect()
                self?.isReconnecting = false
            }
        }
    }
    
    @objc private func handleAppWillResignActive() {
        // Cancel any pending reconnection
        reconnectionTimer?.invalidate()
        isReconnecting = false
        
        if appRemote.isConnected {
            print("📱 App resigning active, disconnecting from Spotify...")
            appRemote.disconnect()
        }
    }
    
    func handleURL(_ url: URL) {
        print("✅ Received callback URL: \(url)")
        
        if url.scheme == "desky" {
            if let code = url.queryParameters?["code"] {
                print("🎯 Successfully extracted authorization code: \(code)")
                requestAccessToken(with: code)
            } else {
                print("⚠️ No authorization code found in URL parameters")
                print("🔍 URL parameters: \(url.queryParameters ?? [:])")
            }
        } else {
            print("❌ URL scheme mismatch. Expected 'desky', got '\(url.scheme ?? "nil")'")
        }
    }
    
    private func requestAccessToken(with code: String) {
        print("🔄 Starting token request...")
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let encodedRedirectURI = Constants.redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? Constants.redirectURI
        
        let body = "grant_type=authorization_code" +
            "&code=\(code)" +
            "&redirect_uri=\(encodedRedirectURI)" +
            "&client_id=\(Constants.spotifyClientID)" +
            "&client_secret=\(Constants.spotifyClientSecret)"
        
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        print("📤 Sending token request...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let accessToken = json["access_token"] as? String {
                        print("✅ Access Token received: \(accessToken.prefix(10))...")
                        DispatchQueue.main.async {
                            self?.accessToken = accessToken
                            self?.isAuthenticated = true
                            print("🎉 Authentication status updated to true")
                        }
                    } else if let error = json["error"] as? String {
                        print("❌ Token error: \(error)")
                        if let description = json["error_description"] as? String {
                            print("📝 Error description: \(description)")
                        }
                    }
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("📝 Raw response data: \(dataString)")
                }
            }
        }.resume()
    }
    
    func getAccessToken() -> String? {
        return accessToken
    }
    
    public func setupAppRemote() {
        guard let token = accessToken else {
            print("❌ No access token available for app remote setup")
            return
        }
        
        print("🔑 Using token: \(token.prefix(10))...")
        
        // Create a fresh configuration
        let configuration = SPTConfiguration(clientID: Constants.spotifyClientID, redirectURL: URL(string: Constants.redirectURI)!)
        
        // Create a new app remote instance
        let newAppRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        newAppRemote.delegate = self
        newAppRemote.connectionParameters.accessToken = token
        
        // Store the new instance
        self.appRemote = newAppRemote
        
        // Try to connect using connect() instead of authorizeAndPlayURI
        print("🔄 Attempting to connect to Spotify...")
        appRemote.connect()
    }
    
    public func requestPlayerState() {
        print("🎵 Requesting player state...")
        guard appRemote.isConnected else {
            print("❌ Cannot request player state - not connected")
            return
        }
        
        appRemote.playerAPI?.getPlayerState { [weak self] result, error in
            if let error = error {
                print("❌ Error getting player state: \(error)")
                // Try again after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.requestPlayerState()
                }
            } else if let playerState = result as? SPTAppRemotePlayerState {
                print("✅ Received player state - Track: \(playerState.track.name)")
                self?.updatePlayerState(playerState)
            } else {
                print("⚠️ No player state available")
            }
        }
    }
    
    func disconnect() {
        if appRemote.isConnected {
            appRemote.disconnect()
        }
        if !shouldAutoReconnect() {
            isConnected = false
        }
    }
    
    private func shouldAutoReconnect() -> Bool {
        if let lastConnection = UserDefaults.standard.object(forKey: "lastSpotifyConnection") as? Date {
            let timeInterval = Date().timeIntervalSince(lastConnection)
            return timeInterval < 24 * 60 * 60 // 24 hours in seconds
        }
        return false
    }
    
    deinit {
        reconnectionTimer?.invalidate()
    }
}

extension SpotifyAuth: SPTAppRemoteDelegate {
    private static var isAttemptingConnection = false
    
    func appRemote(_ appRemote: SpotifyiOS.SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("❌ Failed to connect to Spotify")
        if let error = error {
            print("Error details: \(error.localizedDescription)")
            
            // Only try reconnecting if we're not already in the process
            if !isReconnecting {
                // Try one more time with authorizeAndPlayURI
                print("🔄 Trying alternate connection method...")
                appRemote.authorizeAndPlayURI("")
                
                // If that fails too, show error
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if !(self?.appRemote.isConnected ?? false) {
                        DispatchQueue.main.async {
                            self?.isConnected = false
                            NotificationCenter.default.post(name: NSNotification.Name("ShowSpotifyConnectionError"), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    func appRemoteDidEstablishConnection(_ appRemote: SpotifyiOS.SPTAppRemote) {
        print("✅ Connected to Spotify")
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
        }
        
        // Set up player API delegate and immediately request state
        appRemote.playerAPI?.delegate = self
        requestPlayerState()
        
        // Then subscribe to future updates
        appRemote.playerAPI?.subscribe { [weak self] result, error in
            if let error = error {
                print("❌ Error subscribing to player state: \(error)")
                // Try to request state even if subscription fails
                self?.requestPlayerState()
            } else {
                print("✅ Successfully subscribed to player state updates")
            }
        }
    }
    
    func appRemote(_ appRemote: SpotifyiOS.SPTAppRemote, didDisconnectWithError error: Error?) {
        print("❌ Disconnected from Spotify")
        isConnected = false
        if let error = error {
            print("Error: \(error)")
        }
    }
}

extension SpotifyAuth: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        print("🎵 Player state changed automatically")
        updatePlayerState(playerState)
    }
    
    private func updatePlayerState(_ playerState: SPTAppRemotePlayerState) {
        print("🎵 Updating player state for track: \(playerState.track.name)")
        
        // Create image URL from identifier with better formatting
        let imageURL: URL? = {
            let identifier = playerState.track.imageIdentifier
            // Remove any potential spotify: prefix
            let cleanIdentifier = identifier.replacingOccurrences(of: "spotify:", with: "")
            return URL(string: "https://i.scdn.co/image/\(cleanIdentifier)")
        }()
        
        if let url = imageURL {
            print("🖼️ Image URL created: \(url)")
        } else {
            print("⚠️ Could not create image URL from identifier: \(playerState.track.imageIdentifier)")
        }
        
        DispatchQueue.main.async {
            self.currentTrack = (
                title: playerState.track.name,
                artist: playerState.track.artist.name,
                isPlaying: playerState.isPaused == false,
                imageURL: imageURL
            )
            print("✅ Updated current track: \(playerState.track.name)")
        }
    }
} 
