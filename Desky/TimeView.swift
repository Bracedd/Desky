//
//  TimeView.swift
//  Desky
//
//  Created by Divpreet Singh on 11/10/24.
//

import SwiftUI

struct TimeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                Text("Time View")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}
