//
//  Test.swift
//  BLEScanner
//
//  Created by Siarhei Yakushevich on 17/08/2026.
//

import SwiftUI

struct TestView: View {
    @State private var isPresented: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            Button("Toggle") {
                withAnimation {
                    isPresented.toggle()
                }
            }.foregroundStyle(.primary)
            
            if isPresented {
                Text("Hello, World!")
                    .monospaced()
                    .transition(.move(edge: .leading))
                    .padding(.top, 50)
                    .backgroundStyle(.black.opacity(0.4))
            }
        }
    }
}


#Preview {
    TestView()
}
