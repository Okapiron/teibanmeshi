import Foundation
import SwiftData

@Model
final class Shop: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var logoKey: String?
    var createdAt: Date
    var updatedAt: Date
    var lastViewedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        logoKey: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastViewedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.logoKey = logoKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastViewedAt = lastViewedAt
    }
}

