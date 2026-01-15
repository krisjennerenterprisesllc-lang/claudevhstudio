//
//  MusicGenre.swift
//  VocalHeat
//
//  Genre-aware scoring system for culturally appropriate feedback
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

// MARK: - Music Genre

enum MusicGenre: String, Codable, CaseIterable, Identifiable {
    case pop = "Pop"
    case mariachi = "Mariachi"
    case ranchera = "Ranchera"
    case bolero = "Bolero"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var rules: GenreRules {
        switch self {
        case .pop:
            return .pop
        case .mariachi:
            return .mariachi
        case .ranchera:
            return .ranchera
        case .bolero:
            return .bolero
        }
    }

    var description: String {
        switch self {
        case .pop:
            return "Modern pop with controlled technique"
        case .mariachi:
            return "Traditional Mexican mariachi style"
        case .ranchera:
            return "Mexican ranchera with emotional delivery"
        case .bolero:
            return "Romantic Latin bolero style"
        }
    }
}

// MARK: - Genre Rules

struct GenreRules {
    let name: String

    // Vibrato expectations
    let vibratoExpected: Bool
    let vibratoExtentMin: Double        // cents (minimum for "good" vibrato)
    let vibratoExtentMax: Double        // cents (maximum acceptable)
    let noVibratoIsPenalty: Bool        // Is lack of vibrato a problem?

    // Pitch tolerances
    let pitchAccuracyTolerance: Double  // cents (±) for "on pitch"
    let allowsIntentionalSlides: Bool   // Are scoops/slides technique?

    // Expression factors
    let rubatoExpected: Bool            // Is tempo flexibility artistry?
    let vocalBreaksAcceptable: Bool     // Are vocal breaks acceptable?
    let gritosTechnique: Bool           // Mariachi/Ranchera cry technique

    // Tone expectations
    let straightToneAcceptable: Bool    // Is straight tone OK?

    // Coaching language
    let culturalReferences: [String]    // Artist examples for coaching

    // MARK: - Preset Genres

    static let pop = GenreRules(
        name: "Pop",
        vibratoExpected: true,
        vibratoExtentMin: 25,               // Moderate vibrato
        vibratoExtentMax: 50,
        noVibratoIsPenalty: false,          // Optional
        pitchAccuracyTolerance: 25,         // Tight pitch accuracy
        allowsIntentionalSlides: true,      // R&B influence common
        rubatoExpected: false,
        vocalBreaksAcceptable: false,
        gritosTechnique: false,
        straightToneAcceptable: true,
        culturalReferences: ["Selena", "Whitney Houston", "Ariana Grande"]
    )

    static let mariachi = GenreRules(
        name: "Mariachi",
        vibratoExpected: true,
        vibratoExtentMin: 50,               // Wide dramatic vibrato
        vibratoExtentMax: 100,              // Very wide acceptable
        noVibratoIsPenalty: true,           // Vibrato is essential
        pitchAccuracyTolerance: 35,         // Emotion > strict precision
        allowsIntentionalSlides: true,      // Scoops are technique
        rubatoExpected: true,               // Tempo flexibility expected
        vocalBreaksAcceptable: false,
        gritosTechnique: true,              // Gritos celebrated!
        straightToneAcceptable: false,      // Vibrato expected
        culturalReferences: ["Vicente Fernández", "Pedro Infante", "Antonio Aguilar"]
    )

    static let ranchera = GenreRules(
        name: "Ranchera",
        vibratoExpected: true,
        vibratoExtentMin: 50,               // Wide emotional vibrato
        vibratoExtentMax: 100,
        noVibratoIsPenalty: true,           // Vibrato essential
        pitchAccuracyTolerance: 35,         // Emotion first
        allowsIntentionalSlides: true,      // Scoops common
        rubatoExpected: true,               // Emotional phrasing
        vocalBreaksAcceptable: false,
        gritosTechnique: true,              // Gritos are hallmark
        straightToneAcceptable: false,
        culturalReferences: ["Vicente Fernández", "Lola Beltrán", "José Alfredo Jiménez"]
    )

    static let bolero = GenreRules(
        name: "Bolero",
        vibratoExpected: true,
        vibratoExtentMin: 40,               // Wide romantic vibrato
        vibratoExtentMax: 75,
        noVibratoIsPenalty: true,           // Vibrato essential
        pitchAccuracyTolerance: 30,         // Romantic style
        allowsIntentionalSlides: true,      // Emotional slides
        rubatoExpected: true,               // Rubato is artistry
        vocalBreaksAcceptable: false,
        gritosTechnique: false,             // Not typical for bolero
        straightToneAcceptable: false,      // Vibrato expected
        culturalReferences: ["Luis Miguel", "Eydie Gormé", "Lucho Gatica"]
    )
}

// MARK: - Genre-Aware Scoring Helper

struct GenreAwareScoring {
    let genre: MusicGenre

    var rules: GenreRules {
        genre.rules
    }

    // MARK: - Vibrato Scoring

    func scoreVibratoStability(
        vibrato: VibratoMeasurement
    ) -> (score: Int, message: String) {

        // No vibrato detected
        guard let extent = vibrato.averageRate else {
            if rules.noVibratoIsPenalty {
                return (70, "Consider adding vibrato for authentic \(genre.displayName) style")
            } else {
                return (85, "Clean straight tone")
            }
        }

        // Vibrato detected - check if it matches genre expectations
        let extentCents = extent * 100 // Rough conversion for display

        if vibrato.isHealthy {
            if extentCents >= rules.vibratoExtentMin && extentCents <= rules.vibratoExtentMax {
                return (98, "Authentic \(genre.displayName) vibrato - excellent technique")
            } else if extentCents < rules.vibratoExtentMin {
                return (85, "Vibrato could be wider for \(genre.displayName) style")
            } else {
                // Wide vibrato but genre doesn't expect it
                if genre == .mariachi || genre == .ranchera {
                    return (95, "Passionate wide vibrato - ¡Salón de la Fama!")
                } else {
                    return (80, "Vibrato extent exceeds typical \(genre.displayName) range")
                }
            }
        } else {
            return (75, "Vibrato inconsistency detected - work on control")
        }
    }

    // MARK: - Pitch Accuracy Scoring

    func scorePitchAccuracy(averageDeviation: Double) -> Int {
        let tolerance = rules.pitchAccuracyTolerance
        let absDeviation = abs(averageDeviation)

        if absDeviation <= tolerance * 0.4 {
            return 100  // Well within genre tolerance - perfect
        } else if absDeviation <= tolerance {
            return 95   // Within genre tolerance - great
        } else if absDeviation <= tolerance * 1.5 {
            return 85   // Slightly outside - good
        } else {
            // Beyond tolerance - calculate proportional score
            let extraDeviation = absDeviation - tolerance
            let penalty = Int(extraDeviation * 0.5)
            return max(60, 85 - penalty)
        }
    }

    // MARK: - Coaching Context

    func coachingContext() -> String {
        """
        Genre: \(genre.displayName)
        Expected vibrato: \(rules.vibratoExpected ? "Yes" : "Optional") \
        (\(Int(rules.vibratoExtentMin))-\(Int(rules.vibratoExtentMax)) cents)
        Pitch tolerance: ±\(Int(rules.pitchAccuracyTolerance)) cents
        Special techniques: \(specialTechniques())
        Reference artists: \(rules.culturalReferences.joined(separator: ", "))
        """
    }

    private func specialTechniques() -> String {
        var techniques: [String] = []

        if rules.gritosTechnique {
            techniques.append("gritos/cry technique")
        }
        if rules.allowsIntentionalSlides {
            techniques.append("intentional scoops/slides")
        }
        if rules.rubatoExpected {
            techniques.append("rubato/tempo flexibility")
        }
        if rules.straightToneAcceptable {
            techniques.append("straight tone acceptable")
        }

        return techniques.isEmpty ? "Standard technique" : techniques.joined(separator: ", ")
    }

    // MARK: - AI Prompt Enhancement

    func aiPromptSuffix(language: String) -> String {
        if language == "es" {
            return """

            Género Musical: \(genre.displayName)
            Estilo Esperado:
            - Vibrato: \(rules.vibratoExpected ? "Esencial" : "Opcional") \
            (\(Int(rules.vibratoExtentMin))-\(Int(rules.vibratoExtentMax)) cents)
            - Precisión tonal: ±\(Int(rules.pitchAccuracyTolerance)) cents
            \(rules.gritosTechnique ? "- Gritos y técnica emotiva son celebrados" : "")
            - Artistas de referencia: \(rules.culturalReferences.joined(separator: ", "))

            Ajusta tu retroalimentación según las convenciones del \(genre.displayName).
            """
        } else {
            return """

            Musical Genre: \(genre.displayName)
            Expected Style:
            - Vibrato: \(rules.vibratoExpected ? "Essential" : "Optional") \
            (\(Int(rules.vibratoExtentMin))-\(Int(rules.vibratoExtentMax)) cents)
            - Pitch accuracy: ±\(Int(rules.pitchAccuracyTolerance)) cents
            \(rules.gritosTechnique ? "- Gritos and emotional cry technique are celebrated" : "")
            - Reference artists: \(rules.culturalReferences.joined(separator: ", "))

            Adjust your feedback based on \(genre.displayName) conventions.
            """
        }
    }
}
