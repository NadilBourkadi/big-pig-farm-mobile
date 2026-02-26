/// Bloodline — Bloodline tracking for breeding programs and adoption.
/// Maps from: entities/bloodline.py
// TODO: Implement in doc 02
import Foundation

/// Category of bloodline specialization.
enum BloodlineType: String, Codable, CaseIterable, Sendable {
    case standard
    // TODO: Add remaining types in doc 02
}

/// A tracked breeding bloodline.
struct Bloodline: Identifiable, Codable, Sendable {
    let id: UUID
    // TODO: Implement in doc 02
}
