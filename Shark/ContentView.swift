//
//  ContentView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainWorkspaceView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthorizationManager.shared)
}
