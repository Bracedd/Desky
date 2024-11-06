import SwiftUI
import SpotifyiOS
import Combine

class SpotifyAuth: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        }
    }
    
    @Published var currentTrack: (title: String, artist: String, isPlaying: Bool)?
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
    
    override init() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        isConnected = UserDefaults.standard.bool(forKey: "spotifyConnected")
        accessToken = UserDefaults.standard.string(forKey: "spotifyAccessToken")
        
        super.init()
        
        if isAuthenticated && shouldAutoReconnect() {
            print("📱 Attempting to restore previous session")
            setupAppRemote()
        }
        
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
    
    private func shouldAutoReconnect() -> Bool {
        if let lastConnection = UserDefaults.standard.object(forKey: "lastSpotifyConnection") as? Date {
            let timeInterval = Date().timeIntervalSince(lastConnection)
            return timeInterval < 24 * 60 * 60 // 24 hours in seconds
        }
        return false
    }
    
    @objc private func handleAppWillTerminate() {
        UserDefaults.standard.synchronize()
    }
    
    @objc private func handleAppDidBecomeActive() {
        if isAuthenticated && shouldAutoReconnect() && !appRemote.isConnected {
            print("🔄 App became active, reconnecting to Spotify...")
            setupAppRemote()
        }
    }
    
    @objc private func handleAppWillResignActive() {
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
        
        // First, ensure Spotify is open
        guard let spotifyURL = URL(string: "spotify:") else { return }
        
        UIApplication.shared.open(spotifyURL) { [weak self] success in
            if success {
                print("✅ Opened Spotify app")
                // Give Spotify more time to fully launch and establish connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    // Create a fresh configuration
                    let configuration = SPTConfiguration(clientID: Constants.spotifyClientID, redirectURL: URL(string: Constants.redirectURI)!)
                    
                    // Create a new app remote instance
                    let newAppRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
                    newAppRemote.delegate = self
                    newAppRemote.connectionParameters.accessToken = token
                    
                    // Store the new instance
                    self?.appRemote = newAppRemote
                    
                    print("🔄 Attempting connection after Spotify launch...")
                    self?.appRemote.connect()  // Use connect() instead of authorizeAndPlayURI
                }
            } else {
                print("❌ Failed to open Spotify app")
            }
        }
    }
    
    private func requestPlayerState() {
        print("🎵 Requesting player state...")
        appRemote.playerAPI?.getPlayerState { [weak self] result, error in
            if let error = error {
                print("❌ Error getting player state: \(error)")
            } else if let playerState = result as? SPTAppRemotePlayerState {
                print("✅ Received player state - Track: \(playerState.track.name)")
                DispatchQueue.main.async {
                    self?.currentTrack = (
                        title: playerState.track.name,
                        artist: playerState.track.artist.name,
                        isPlaying: !playerState.isPaused
                    )
                }
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
}

extension SpotifyAuth: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SpotifyiOS.SPTAppRemote) {
        print("✅ Connected to Spotify")
        isConnected = true
        
        // Set up player API delegate first
        appRemote.playerAPI?.delegate = self
        
        // Subscribe to player state updates
        appRemote.playerAPI?.subscribe { [weak self] result, error in
            if let error = error {
                print("❌ Error subscribing to player state: \(error)")
            } else {
                print("✅ Successfully subscribed to player state updates")
                // Get initial player state after successful subscription
                self?.requestPlayerState()
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
    
    func appRemote(_ appRemote: SpotifyiOS.SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("❌ Failed to connect to Spotify")
        if let error = error {
            print("Error details: \(error.localizedDescription)")
            
            // Only retry a few times to avoid infinite loop
            var retryCount = 0
            if retryCount < 3 {
                retryCount += 1
                // Increase delay between retries
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount * 2)) { [weak self] in
                    print("🔄 Retrying connection (Attempt \(retryCount))...")
                    self?.appRemote.authorizeAndPlayURI("") // Use authorizeAndPlayURI instead of connect
                }
            } else {
                print("❌ Max retry attempts reached")
                retryCount = 0
            }
        }
    }
}

extension SpotifyAuth: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        updatePlayerState(playerState)
    }
    
    private func updatePlayerState(_ playerState: SPTAppRemotePlayerState) {
        DispatchQueue.main.async {
            self.currentTrack = (
                title: playerState.track.name,
                artist: playerState.track.artist.name,
                isPlaying: playerState.isPaused == false
            )
        }
    }
} 
