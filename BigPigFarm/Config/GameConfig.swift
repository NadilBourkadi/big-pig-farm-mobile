/// GameConfig — All balance constants organized in enum namespaces.
/// Maps from: data/config.py
// TODO: Implement in doc 02
import Foundation

/// Top-level namespace for all game balance constants.
/// Uses caseless enums as namespaces (Swift convention for pure constants).
enum GameConfig {
    /// Tick rate and speed settings.
    enum Timing {
        static let baseTPS: Int = 10
        // TODO: Implement in doc 02
    }

    /// Pig need decay and recovery rates.
    enum Needs {
        // TODO: Implement in doc 02
    }

    /// Breeding parameters.
    enum Breeding {
        // TODO: Implement in doc 02
    }

    /// Economy balance values.
    enum Economy {
        // TODO: Implement in doc 02
    }
}
