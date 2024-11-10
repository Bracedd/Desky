//
//  TimeView.swift
//  Desky
//
//  Created by Divpreet Singh on 11/10/24.
//

import SwiftUI

struct TimeView: View {
    @State private var currentTime = Date()
    
    var body: some View {
        Text(formatDate(currentTime))
            .font(.system(size: 92))
            .fontWeight(.heavy)
            .frame(width: 750, height: 50)
            .onAppear {
                // Update the time every second
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    currentTime = Date()
                }
            }
    
        }
    }
    
    // Format the date into a time string
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

