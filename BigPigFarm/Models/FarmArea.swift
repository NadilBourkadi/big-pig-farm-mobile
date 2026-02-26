/// FarmArea — Discrete areas within the farm connected by tunnels.
/// Maps from: entities/farm_area.py
// TODO: Implement in doc 02
import Foundation

/// A connection between two farm areas via a tunnel.
struct TunnelConnection: Codable, Sendable {
    // TODO: Implement in doc 02
}

/// A discrete area of the farm with its own grid region.
struct FarmArea: Identifiable, Codable, Sendable {
    let id: UUID
    // TODO: Implement in doc 02
}
