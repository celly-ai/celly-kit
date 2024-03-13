//
//  CellyKit_DemoApp.swift
//  CellyKit-Demo
//
//  Created by Amin Benarieb on 3/13/24.
//

import SwiftUI
import CellyCore
import CellyUtils
import CellyCV
import CellyUI

@main
struct CellyKit_DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(CellyError(message: "Welcoming error", code: .unauthorized).localizedDescription)
            Text(MicroscropeModel.cx21.rawValue)
            AnalysisTerminationInfoListView(infos: [.init(slide: "1", id: "1", duration: "10", reason: "WAAH", objectsCount: 3, backgroundColor: .purple)]) {
                
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
