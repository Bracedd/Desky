import SwiftUI

struct HomeView: View {
    @EnvironmentObject var loginStatus: LoginStatus
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Desky!")
                .font(.largeTitle)
                .padding()
            
            Text("Connected to Spotify")
                .font(.headline)
                .foregroundColor(.green)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
