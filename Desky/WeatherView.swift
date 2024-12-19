import SwiftUI
import CoreLocation

struct WeatherView: View {
    @StateObject private var weatherViewModel = WeatherViewModel()
    @State private var isSearching = false
    @State private var searchText = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Weather app gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.6, blue: 0.9),
                        Color(red: 0.2, green: 0.4, blue: 0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Top padding
                        Color.clear.frame(height: geometry.safeAreaInsets.top + 20)
                        
                        // Search bar and button
                        HStack {
                            if isSearching {
                                searchBar(width: min(geometry.size.width * 0.8, 400))
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            } else {
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring()) {
                                        isSearching.toggle()
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Weather content
                        if let weather = weatherViewModel.weather {
                            VStack(alignment: .leading, spacing: 10) {
                                // City name and current weather
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(weather.cityName)
                                            .font(.system(size: min(46, geometry.size.width * 0.1), weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("\(Int(weather.temperature))°")
                                                .font(.system(size: min(46, geometry.size.width * 0.1), weight: .bold))
                                            Text(weather.description.capitalized)
                                                .font(.system(size: min(46, geometry.size.width * 0.1), weight: .bold))
                                                .foregroundColor(.yellow)
                                            Image(systemName: getWeatherIcon(for: weather.description))
                                                .font(.system(size: min(46, geometry.size.width * 0.1), weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                
                                // Forecast section
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("5-DAY FORECAST")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                    }
                                    .padding(.horizontal, min(20, geometry.size.width * 0.05))
                                    .padding(.top, 20)
                                    
                                    if let forecast = weatherViewModel.forecast {
                                        VStack(spacing: 0) {
                                            ForEach(forecast.indices, id: \.self) { index in
                                                let day = forecast[index]
                                                HStack {
                                                    Text(formatDate(day.date))
                                                        .frame(width: 100, alignment: .leading)
                                                        .font(.system(size: 18, weight: .medium))
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: getWeatherIcon(for: day.description))
                                                        .font(.system(size: 20, weight: .medium))
                                                    
                                                    Text("\(Int(day.temperature))°")
                                                        .frame(width: 50)
                                                        .font(.system(size: 20, weight: .medium))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, min(20, geometry.size.width * 0.05))
                                                .background(Color(red: 0.4, green: 0.6, blue: 0.9))
                                                
                                                if index < forecast.count - 1 {
                                                    Divider()
                                                        .background(Color.white.opacity(0.1))
                                                }
                                            }
                                        }
                                        .background(Color(red: 0.4, green: 0.6, blue: 0.9))
                                        .cornerRadius(15)
                                        .padding(.horizontal, min(20, geometry.size.width * 0.05))
                                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    }
                                }
                            }
                        } else if weatherViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2)
                        } else if let errorMessage = weatherViewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                    }
                    .frame(minHeight: geometry.size.height)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            weatherViewModel.requestLocationPermission()
        }
    }
    
    private func searchBar(width: CGFloat) -> some View {
        HStack {
            TextField("Search...", text: $searchText)
                .padding(.leading, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                .frame(width: width)
                .foregroundColor(.white)
                .onSubmit {
                    isSearching = false
                    weatherViewModel.debouncedFetchWeather(for: searchText)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
    }
    
    private func getWeatherIcon(for description: String) -> String {
        switch description.lowercased() {
        case let desc where desc.contains("clear"):
            return "sun.max.fill"
        case let desc where desc.contains("cloud"):
            return "cloud.fill"
        case let desc where desc.contains("rain"):
            return "cloud.rain.fill"
        case let desc where desc.contains("snow"):
            return "cloud.snow.fill"
        case let desc where desc.contains("thunder"):
            return "cloud.bolt.fill"
        default:
            return "sun.max.fill"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // Full day name
        return formatter.string(from: date)
    }
    
    private func getForecastColor(for description: String) -> Color {
        switch description.lowercased() {
        case let desc where desc.contains("clear"):
            return Color.blue.opacity(0.3)
        case let desc where desc.contains("cloud"):
            return Color.gray.opacity(0.3)
        case let desc where desc.contains("rain"):
            return Color.indigo.opacity(0.3)
        case let desc where desc.contains("snow"):
            return Color.cyan.opacity(0.3)
        case let desc where desc.contains("thunder"):
            return Color.purple.opacity(0.3)
        default:
            return Color.clear
        }
    }
}

class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var forecast: [ForecastDay]?
    @Published var errorMessage: String?
    @Published var isLoading = false
<<<<<<< HEAD
    private let apiKey = "e1648e7a34f3662e40461a54fef629d9"
=======
    private let apiKey = "HEHE_WEATHER_API" 
>>>>>>> main
    private let locationManager = CLLocationManager()
    private var debounceTimer: Timer?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            fetchWeather(for: location.coordinate)
            fetchForecast(for: location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Location error: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func debouncedFetchWeather(for cityName: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.fetchWeather(for: cityName)
            self?.fetchForecast(for: cityName)
        }
    }
    
    func fetchWeather(for cityName: String) {
        guard let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return }
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCity)&appid=\(apiKey)&units=metric"
        fetchWeatherData(from: urlString)
    }
    
    func fetchWeather(for coordinate: CLLocationCoordinate2D) {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(apiKey)&units=metric"
        fetchWeatherData(from: urlString)
    }
    
    func fetchForecast(for cityName: String) {
        guard let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return }
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?q=\(encodedCity)&appid=\(apiKey)&units=metric"
        fetchForecastData(from: urlString)
    }
    
    func fetchForecast(for coordinate: CLLocationCoordinate2D) {
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(apiKey)&units=metric"
        fetchForecastData(from: urlString)
    }
    
    private func fetchWeatherData(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let weatherData = try decoder.decode(OpenWeatherResponse.self, from: data)
                    
                    self?.weather = Weather(
                        cityName: weatherData.name,
                        temperature: weatherData.main.temp,
                        description: weatherData.weather.first?.description ?? "",
                        humidity: weatherData.main.humidity,
                        windSpeed: weatherData.wind.speed
                    )
                    self?.errorMessage = nil
                } catch {
                    print("Raw data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            self?.errorMessage = "Data corrupted: \(context.debugDescription)"
                        case .keyNotFound(let key, let context):
                            self?.errorMessage = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
                        case .typeMismatch(let type, let context):
                            self?.errorMessage = "Type '\(type)' mismatch: \(context.debugDescription)"
                        case .valueNotFound(let type, let context):
                            self?.errorMessage = "Value of type '\(type)' not found: \(context.debugDescription)"
                        @unknown default:
                            self?.errorMessage = "Unknown decoding error"
                        }
                    } else {
                        self?.errorMessage = "Decoding error: \(error.localizedDescription)"
                    }
                }
            }
        }.resume()
    }
    
    private func fetchForecastData(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid forecast URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Forecast network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No forecast data received"
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let forecastData = try decoder.decode(ForecastResponse.self, from: data)
                    
                    let dailyForecasts = self?.processForecastData(forecastData.list)
                    self?.forecast = dailyForecasts
                } catch {
                    print("Raw forecast data: \(String(data: data, encoding: .utf8) ?? "Unable to convert forecast data to string")")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            self?.errorMessage = "Forecast data corrupted: \(context.debugDescription)"
                        case .keyNotFound(let key, let context):
                            self?.errorMessage = "Forecast key '\(key.stringValue)' not found: \(context.debugDescription)"
                        case .typeMismatch(let type, let context):
                            self?.errorMessage = "Forecast type '\(type)' mismatch: \(context.debugDescription)"
                        case .valueNotFound(let type, let context):
                            self?.errorMessage = "Forecast value of type '\(type)' not found: \(context.debugDescription)"
                        @unknown default:
                            self?.errorMessage = "Unknown forecast decoding error"
                        }
                    } else {
                        self?.errorMessage = "Forecast decoding error: \(error.localizedDescription)"
                    }
                }
            }
        }.resume()
    }
    
    private func processForecastData(_ list: [ForecastItem]) -> [ForecastDay] {
        var dailyForecasts: [ForecastDay] = []
        var processedDates: Set<String> = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in list {
            let dateString = dateFormatter.string(from: item.dt)
            if !processedDates.contains(dateString) {
                processedDates.insert(dateString)
                dailyForecasts.append(ForecastDay(
                    date: item.dt,
                    temperature: item.main.temp,
                    description: item.weather.first?.description ?? ""
                ))
            }
        }
        
        return dailyForecasts
    }
}

struct Weather: Codable {
    let cityName: String
    let temperature: Double
    let description: String
    let humidity: Double
    let windSpeed: Double
}

struct ForecastDay: Codable {
    let date: Date
    let temperature: Double
    let description: String
}

struct OpenWeatherResponse: Codable {
    let name: String
    let main: MainWeather
    let weather: [WeatherDescription]
    let wind: Wind
}

struct ForecastResponse: Codable {
    let list: [ForecastItem]
}

struct ForecastItem: Codable {
    let dt: Date
    let main: MainWeather
    let weather: [WeatherDescription]
    let wind: Wind?
    let pop: Double?

    enum CodingKeys: String, CodingKey {
        case dt = "dt"
        case main
        case weather
        case wind
        case pop
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Double.self, forKey: .dt)
        dt = Date(timeIntervalSince1970: timestamp)
        main = try container.decode(MainWeather.self, forKey: .main)
        weather = try container.decode([WeatherDescription].self, forKey: .weather)
        wind = try container.decodeIfPresent(Wind.self, forKey: .wind)
        pop = try container.decodeIfPresent(Double.self, forKey: .pop)
    }
}

struct MainWeather: Codable {
    let temp: Double
    let humidity: Double
}

struct WeatherDescription: Codable {
    let description: String
}

struct Wind: Codable {
    let speed: Double
}



