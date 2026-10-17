import Foundation

/// Fills habits linked to Apple Health from Health data. Implemented in a later step.
enum HealthSync {
    /// Health needs the HealthKit capability; the build turns it on with `COIL_HEALTH=true xcodegen`.
    static var isSupported: Bool {
        #if HEALTHKIT
        return true
        #else
        return false
        #endif
    }
}
