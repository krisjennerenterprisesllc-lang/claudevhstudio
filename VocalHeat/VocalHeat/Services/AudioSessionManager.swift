//
//  AudioSessionManager.swift
//  VocalHeat
//
//  Manages AVAudioSession lifecycle and configuration
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioSessionManager: ObservableObject {
    @Published var isSessionActive = false
    @Published var currentLatencyProfile: LatencyProfile?

    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Public Methods

    func configureSession() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true)
            isSessionActive = true

            measureLatency()
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func deactivateSession() {
        do {
            try audioSession.setActive(false)
            isSessionActive = false
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Private Methods

    private func measureLatency() {
        let inputLatency = Int(audioSession.inputLatency * 1000)
        let outputLatency = Int(audioSession.outputLatency * 1000)

        currentLatencyProfile = LatencyProfile(
            input: inputLatency,
            output: outputLatency
        )
    }
}
