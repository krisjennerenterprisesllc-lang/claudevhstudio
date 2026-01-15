//
//  VocalHeatApp.swift
//  VocalHeat
//
//  Main app entry point
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import SwiftUI

@main
struct VocalHeatApp: App {
    @StateObject private var persistenceManager = PersistenceManager()
    @StateObject private var audioSessionManager = AudioSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(persistenceManager)
                .environmentObject(audioSessionManager)
                .onAppear {
                    setupAudioSession()
                }
        }
    }

    private func setupAudioSession() {
        audioSessionManager.configureSession()
    }
}
