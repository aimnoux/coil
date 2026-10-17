import Foundation
import SwiftData
import Testing
@testable import Coil

/// CloudKit (iCloud sync) only accepts models where every attribute is optional or has a default,
/// nothing is unique, and every relationship is optional with an inverse. Breaking these rules
/// makes the iCloud container fail to load, so they are checked here on every build.
struct CloudKitSchemaTests {
    let schema = Schema([Habit.self, Entry.self, HabitGroup.self, HabitPause.self, TimerSession.self])

    @Test func schemaCoversEveryModel() {
        #expect(schema.entities.count == 5)
        #expect(schema.entities.reduce(0) { $0 + $1.attributes.count } > 40)
        #expect(schema.entities.reduce(0) { $0 + $1.relationships.count } >= 8)
    }

    @Test func noUniqueAttributes() {
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) is unique")
            }
        }
    }

    @Test func attributesAreOptionalOrHaveDefaults() {
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(attribute.isOptional || attribute.defaultValue != nil,
                        "\(entity.name).\(attribute.name) needs a default value")
            }
        }
    }

    @Test func relationshipsAreOptionalWithInverses() {
        for entity in schema.entities {
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
                #expect(relationship.inverseName != nil || relationship.inverseKeyPath != nil,
                        "\(entity.name).\(relationship.name) needs an inverse")
                #expect(relationship.deleteRule != .deny, "\(entity.name).\(relationship.name) can't use .deny")
            }
        }
    }
}
