import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var isVisible: Bool
    
    enum Tab {
        case home, time, weather
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach([Tab.home, Tab.time, Tab.weather], id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut) {
                        selectedTab = tab
                    }
                }) {
                    Text(title(for: tab))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selectedTab == tab ? Color(hex: "00E1FF") : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(Color(hex: "00E1FF").opacity(0.2))
                                        .matchedGeometryEffect(id: "TAB", in: namespace)
                                }
                            }
                        )
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color(white: 0.15))
        .opacity(0.7)
        .clipShape(Capsule())
        .frame(height: 40)
        .frame(maxWidth: 300)
        .offset(y: isVisible ? 0 : 100) // Controls the slide up/down
        .opacity(isVisible ? 1 : 0) // Controls the fade in/out
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
    }
    
    @Namespace private var namespace
    
    private func title(for tab: Tab) -> String {
        switch tab {
        case .home:
            return "Music"
        case .time:
            return "Time"
        case .weather:
            return "Weather"
        }
    }
}

