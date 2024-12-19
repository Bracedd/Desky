import SwiftUI
import CoreLocation

struct WeatherView: View {
    @StateObject private var weatherViewModel = WeatherViewModel()
    @State private var isSearching = false
    @State private var searchText = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if let weather = weatherViewModel.weather {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                currentWeatherView(weather: weather)
                                hourlyForecastView()
                                dailyForecastView()
                            }
                            .padding(.horizontal)
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
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            weatherViewModel.requestLocationPermission()
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white)
            
            TextField("Search for a city", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.white)
                .onChange(of: searchText) { newValue in
                    weatherViewModel.debouncedFetchWeather(for: newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    weatherViewModel.clearWeather()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
        .padding()
    }
    
    private func currentWeatherView(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(weather.cityName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(weather.description.capitalized)
                .font(.title2)
            
            Text("\(Int(weather.temperature))°")
                .font(.system(size: 80, weight: .thin))
            
            HStack {
                Label("H: \(Int(weather.tempMax))°", systemImage: "thermometer.sun")
                Label("L: \(Int(weather.tempMin))°", systemImage: "thermometer.snowflake")
            }
            
            HStack {
                Label("\(Int(weather.humidity))%", systemImage: "humidity")
                Label("\(Int(weather.windSpeed)) m/s", systemImage: "wind")
            }
        }
        .foregroundColor(.white)
        .frame(width: 300, alignment: .leading)
    }
    
    private func hourlyForecastView() -> some View {
        VStack(alignment: .leading) {
            Text("Hourly Forecast")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(0..<24) { hour in
                        VStack {
                            Text("\(hour):00")
                            Image(systemName: "cloud.sun")
                            Text("\(Int.random(in: 15...30))°")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .frame(width: 300)
    }
    
    private func dailyForecastView() -> some View {
        VStack(alignment: .leading) {
            Text("7-Day Forecast")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                ForEach(0..<7) { day in
                    HStack {
                        Text("Day \(day + 1)")
                        Spacer()
                        Image(systemName: "cloud.sun")
                        Text("\(Int.random(in: 15...30))°")
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .frame(width: 300)
    }
}

class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var errorMessage: String?
    @Published var isLoading = false
    private let apiKey = "e1648e7a34f3662e40461a54fef629d9" 
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
    
    private func fetchWeatherData(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        isLoading = true
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
                        tempMin: weatherData.main.temp_min,
                        tempMax: weatherData.main.temp_max,
                        description: weatherData.weather.first?.description ?? "",
                        humidity: weatherData.main.humidity,
                        windSpeed: weatherData.wind.speed
                    )
                    self?.errorMessage = nil
                } catch {
                    self?.errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }
    
    func clearWeather() {
        weather = nil
        errorMessage = nil
    }
}

struct Weather: Codable {
    let cityName: String
    let temperature: Double
    let tempMin: Double
    let tempMax: Double
    let description: String
    let humidity: Double
    let windSpeed: Double
}

struct OpenWeatherResponse: Codable {
    let name: String
    let main: MainWeather
    let weather: [WeatherDescription]
    let wind: Wind
}

struct MainWeather: Codable {
    let temp: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Double
}

struct WeatherDescription: Codable {
    let description: String
}

struct Wind: Codable {
    let speed: Double
}


