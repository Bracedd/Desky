import Foundation


extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return nil
        }
        return items.reduce(into: [String: String]()) { dict, item in
            dict[item.name] = item.value
        }
    }
}
