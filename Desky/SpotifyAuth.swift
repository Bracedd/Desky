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
    @Published var connectionState: ConnectionState = .disconnected
    @Published var currentPlaybackState: SPTAppRemotePlayerState? // Added property
    private var stateUpdateTimer: Timer?
    
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
    
    private var tokenExpirationDate: Date? {
        didSet {
            if let date = tokenExpirationDate {
                UserDefaults.standard.set(date, forKey: "spotifyTokenExpiration")
            }
        }
    }
    
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                UserDefaults.standard.set(token, forKey: "spotifyRefreshToken")
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
    
    private var connectionRetryCount = 0
    private let maxConnectionRetries = 3
    private var connectionRetryTimer: Timer?
    
    override init() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        isConnected = UserDefaults.standard.bool(forKey: "spotifyConnected")
        accessToken = UserDefaults.standard.string(forKey: "spotifyAccessToken")
        refreshToken = UserDefaults.standard.string(forKey: "spotifyRefreshToken")
        tokenExpirationDate = UserDefaults.standard.object(forKey: "spotifyTokenExpiration") as? Date
        
        super.init()
        
        checkAndRefreshTokenIfNeeded()
        
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
        reconnectionTimer?.invalidate()
        connectionRetryTimer?.invalidate()
        
        checkAndRefreshTokenIfNeeded()
        
        if isAuthenticated && !appRemote.isConnected {
            isReconnecting = true
            reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                print("🔄 Restoring connection after app switch...")
                self?.connectionRetryCount = 0
                self?.attemptConnection()
                self?.isReconnecting = false
            }
        }
    }
    
    @objc private func handleAppWillResignActive() {
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
                self?.connectionState = .error(message: "Network error occurred")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No data received")
                self?.connectionState = .error(message: "No data received from server")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let accessToken = json["access_token"] as? String {
                        print("✅ Access Token received: \(accessToken.prefix(10))...")
                        DispatchQueue.main.async {
                            self?.accessToken = accessToken
                            self?.isAuthenticated = true
                            
                            if let refreshToken = json["refresh_token"] as? String {
                                self?.refreshToken = refreshToken
                            }
                            
                            if let expiresIn = json["expires_in"] as? Double {
                                self?.tokenExpirationDate = Date().addingTimeInterval(expiresIn)
                            }
                            
                            print("🎉 Authentication status updated to true")
                            self?.connectionState = .connected
                            self?.setupAppRemote()
                        }
                    } else if let error = json["error"] as? String {
                        print("❌ Token error: \(error)")
                        if let description = json["error_description"] as? String {
                            print("📝 Error description: \(description)")
                            self?.connectionState = .error(message: description)
                        }
                    }
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("📝 Raw response data: \(dataString)")
                }
                self?.connectionState = .error(message: "Failed to parse server response")
            }
        }.resume()
    }
    
    func getAccessToken() -> String? {
        return accessToken
    }
    
    public func setupAppRemote() {
        guard let token = accessToken else {
            print("❌ No access token available for app remote setup")
            connectionState = .error(message: "No access token available")
            return
        }
        
        print("🔑 Using token: \(token.prefix(10))...")
        
        let configuration = SPTConfiguration(clientID: Constants.spotifyClientID, redirectURL: URL(string: Constants.redirectURI)!)
        
        let newAppRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        newAppRemote.delegate = self
        newAppRemote.connectionParameters.accessToken = token
        
        self.appRemote = newAppRemote
        
        connectionState = .connecting
        print("🔄 Attempting to connect to Spotify...")
        appRemote.connect()
        
        // Retry connection if it fails
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if !(self?.appRemote.isConnected ?? false) {
                print("🔄 First connection attempt failed. Retrying...")
                self?.connectionState = .retrying
                self?.appRemote.connect()
            }
        }
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
            } else if let playerState = result as? SPTAppRemotePlayerState {
                print("✅ Received player state - Track: \(playerState.track.name)")
                DispatchQueue.main.async {
                    self?.currentPlaybackState = playerState
                    self?.updatePlayerState(playerState)
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
        connectionState = .disconnected
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
        connectionRetryTimer?.invalidate()
        stateUpdateTimer?.invalidate()
    }
    
    private func checkAndRefreshTokenIfNeeded() {
        guard let expirationDate = tokenExpirationDate else { return }
        
        if Date().addingTimeInterval(5 * 60) > expirationDate {
            refreshAccessToken()
        }
    }
    
    private func refreshAccessToken() {
        guard let refreshToken = refreshToken else { return }
        
        print("🔄 Refreshing access token...")
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let body = "grant_type=refresh_token" +
            "&refresh_token=\(refreshToken)" +
            "&client_id=\(Constants.spotifyClientID)" +
            "&client_secret=\(Constants.spotifyClientSecret)"
        
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Token refresh error: \(error.localizedDescription)")
                self?.connectionState = .error(message: "Failed to refresh token")
                return
            }
            
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let newToken = json["access_token"] as? String {
                        print("✅ New access token received")
                        DispatchQueue.main.async {
                            self?.accessToken = newToken
                            if let expiresIn = json["expires_in"] as? Double {
                                self?.tokenExpirationDate = Date().addingTimeInterval(expiresIn)
                            }
                            self?.setupAppRemote()
                        }
                    }
                }
            } catch {
                print("❌ JSON parsing error during token refresh: \(error)")
                self?.connectionState = .error(message: "Failed to parse token refresh response")
            }
        }.resume()
    }
    
    private func attemptConnection() {
        guard connectionRetryCount < maxConnectionRetries else {
            print("❌ Max connection retries reached")
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.connectionState = .error(message: "Failed to connect after multiple attempts")
                NotificationCenter.default.post(name: NSNotification.Name("ShowSpotifyConnectionError"), object: nil)
            }
            return
        }
         
        connectionRetryCount += 1
        print("🔄 Connection attempt \(connectionRetryCount)/\(maxConnectionRetries)")
        
        setupAppRemote()
        
        connectionRetryTimer?.invalidate()
        connectionRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            if !(self?.appRemote.isConnected ?? false) {
                self?.attemptConnection()
            }
        }
    }
    
    func logout() {
        if appRemote.isConnected {
            appRemote.disconnect()
        }
        
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        isAuthenticated = false
        isConnected = false
        connectionState = .disconnected
        
        UserDefaults.standard.removeObject(forKey: "spotifyAccessToken")
        UserDefaults.standard.removeObject(forKey: "spotifyRefreshToken")
        UserDefaults.standard.removeObject(forKey: "spotifyTokenExpiration")
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "spotifyConnected")
        UserDefaults.standard.removeObject(forKey: "lastSpotifyConnection")
        UserDefaults.standard.synchronize()
    }
    
    // Added method to start periodic updates
    func startPlaybackStateUpdates() {
        stateUpdateTimer?.invalidate()
        stateUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.requestPlayerState()
        }
    }
    
    func stopPlaybackStateUpdates() {
        stateUpdateTimer?.invalidate()
        stateUpdateTimer = nil
    }
}

extension SpotifyAuth: SPTAppRemoteDelegate {
    private static var isAttemptingConnection = false
    
    func appRemote(_ appRemote: SpotifyiOS.SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("❌ Failed to connect to Spotify")
        if let error = error {
            print("Error details: \(error.localizedDescription)")
            
            if !isReconnecting {
                print("🔄 Trying alternate connection method...")
                appRemote.authorizeAndPlayURI("")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    if !(self?.appRemote.isConnected ?? false) {
                        self?.attemptConnection()
                    }
                }
            }
        }
        connectionState = .error(message: "Failed to connect to Spotify")
    }
    
    func appRemoteDidEstablishConnection(_ appRemote: SpotifyiOS.SPTAppRemote) {
        print("✅ Connected to Spotify")
        
        connectionRetryCount = 0
        connectionRetryTimer?.invalidate()
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.connectionState = .connected
            self?.startPlaybackStateUpdates()
        }
        
        appRemote.playerAPI?.delegate = self
        requestPlayerState()
        
        appRemote.playerAPI?.subscribe { [weak self] result, error in
            if let error = error {
                print("❌ Error subscribing to player state: \(error)")
                self?.requestPlayerState()
            } else {
                print("✅ Successfully subscribed to player state updates")
            }
        }
    }
    
    func appRemote(_ appRemote: SpotifyiOS.SPTAppRemote, didDisconnectWithError error: Error?) {
        print("❌ Disconnected from Spotify")
        isConnected = false
        connectionState = .disconnected
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
    
    private func updatePlayerState(_ playerState: SPTAppRemotePlayerState) { // Updated method
        print("🎵 Updating player state for track: \(playerState.track.name)")
        
        let imageURL: URL? = {
            let identifier = playerState.track.imageIdentifier
            let cleanIdentifier = identifier
                .replacingOccurrences(of: "spotify:", with: "")
                .replacingOccurrences(of: "image:", with: "")
            return URL(string: "https://i.scdn.co/image/\(cleanIdentifier)")
        }()
        
        if let url = imageURL {
            print("🖼️ Image URL created: \(url)")
            NotificationCenter.default.post(name: NSNotification.Name("TrackDidChange"), object: nil)
        } else {
            print("⚠️ Could not create image URL from identifier: \(playerState.track.imageIdentifier)")
        }
        
        DispatchQueue.main.async {
            self.currentPlaybackState = playerState // Update currentPlaybackState
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

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case retrying
    case error(message: String)
}


