import SwiftUI

struct TimeView: View {
    @State private var currentTime = Date()
    @AppStorage("use24HourFormat") private var use24HourFormat = true
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                HStack(spacing: geometry.size.width * 0.02) {
                    // Hours
                    HStack(spacing: geometry.size.width * 0.01) {
                        DigitView(number: getHours()[0], size: geometry.size)
                        DigitView(number: getHours()[1], size: geometry.size)
                    }
                    
                    // Separator
                    Text(":")
                        .font(.system(size: geometry.size.width * 0.15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .offset(y: -geometry.size.height * 0.02)
                    
                    // Minutes
                    HStack(spacing: geometry.size.width * 0.01) {
                        DigitView(number: getMinutes()[0], size: geometry.size)
                        DigitView(number: getMinutes()[1], size: geometry.size)
                    }
                    
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
    }
    
    private func getHours() -> [Int] {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourFormat ? "HH" : "hh"
        let hoursStr = formatter.string(from: currentTime)
        return [Int(String(hoursStr.prefix(1)))!, Int(String(hoursStr.suffix(1)))!]
    }
    
    private func getMinutes() -> [Int] {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        let minutesStr = formatter.string(from: currentTime)
        return [Int(String(minutesStr.prefix(1)))!, Int(String(minutesStr.suffix(1)))!]
    }
    
    
    
    struct DigitView: View {
        let number: Int
        let size: CGSize
        
        var body: some View {
            VStack(spacing: size.height * 0.005) {
                // Upper half
                ZStack {
                    RoundedRectangle(cornerRadius: size.width * 0.02)
                        .fill(Color(white: 0.15))
                    Text("\(number)")
                        .font(.system(size: size.width * 0.18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: size.width * 0.2, height: size.height * 0.25)
                        .clipped()
                        .offset(y: size.height * 0.125)
                }
                .frame(width: size.width * 0.2, height: size.height * 0.25)
                .clipped()
                
                // Lower half
                ZStack {
                    RoundedRectangle(cornerRadius: size.width * 0.02)
                        .fill(Color(white: 0.15))
                    Text("\(number)")
                        .font(.system(size: size.width * 0.18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: size.width * 0.2, height: size.height * 0.25)
                        .clipped()
                        .offset(y: -size.height * 0.125)
                }
                .frame(width: size.width * 0.2, height: size.height * 0.25)
                .clipped()
            }
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        }
    }
    
    
}
