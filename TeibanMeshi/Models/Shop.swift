import Foundation
import SwiftData

enum ShopNameMatcher {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isExactMatch(_ lhs: String, _ rhs: String) -> Bool {
        trimmed(lhs) == trimmed(rhs)
    }

    static func similarityKey(_ value: String) -> String {
        trimmed(value)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            .filter { !$0.isWhitespace }
    }

    static func differsOnlyByFormatting(_ lhs: String, _ rhs: String) -> Bool {
        !isExactMatch(lhs, rhs) && similarityKey(lhs) == similarityKey(rhs)
    }
}

enum SearchMatcher {
    static func normalized(_ value: String) -> String {
        let widthAndCaseFolded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "ja_JP")
        )
        return (widthAndCaseFolded.applyingTransform(.hiraganaToKatakana, reverse: false) ?? widthAndCaseFolded)
            .localizedLowercase
    }

    static func terms(in query: String) -> [String] {
        normalized(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func matches(query: String, values: [String]) -> Bool {
        let queryTerms = terms(in: query)
        guard !queryTerms.isEmpty else { return false }
        let haystack = normalized(values.joined(separator: " "))
        return queryTerms.allSatisfy(haystack.contains)
    }
}

@Model
final class Shop: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var logoKey: String?
    var imageUri: String?
    var pinnedAt: Date?
    var primaryOrderId: String?
    var createdAt: Date
    var updatedAt: Date
    var lastViewedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        logoKey: String? = nil,
        imageUri: String? = nil,
        pinnedAt: Date? = nil,
        primaryOrderId: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastViewedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.logoKey = logoKey
        self.imageUri = imageUri
        self.pinnedAt = pinnedAt
        self.primaryOrderId = primaryOrderId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastViewedAt = lastViewedAt
    }
}
