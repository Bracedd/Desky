import SwiftUI

class SpotifyAuth: ObservableObject {
    @Published var isAuthenticated: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        }
    }
    
    private var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "spotifyAccessToken")
            }
        }
    }
    
    init() {
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        self.accessToken = UserDefaults.standard.string(forKey: "spotifyAccessToken")
        
        if isAuthenticated {
            print("📱 Restored previous authentication state")
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
} 