import Foundation
import SwiftData

enum OrderStatus: String, CaseIterable, Identifiable, Codable {
    case favorite
    case wantToTry = "want_to_try"
    case tried

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorite:
            "定番"
        case .wantToTry:
            "次試す"
        case .tried:
            "試した"
        }
    }

    var symbol: String {
        switch self {
        case .favorite:
            "star.fill"
        case .wantToTry:
            "eye.fill"
        case .tried:
            "testtube.2"
        }
    }

}

@Model
final class OrderSet: Identifiable {
    @Attribute(.unique) var id: String
    var shopId: String
    var statusRawValue: String
    var items: [String]
    var memo: String?
    var imageUri: String?
    var createdAt: Date
    var updatedAt: Date

    var status: OrderStatus {
        get { OrderStatus(rawValue: statusRawValue) ?? .tried }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        shopId: String,
        status: OrderStatus = .tried,
        items: [String],
        memo: String? = nil,
        imageUri: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.shopId = shopId
        self.statusRawValue = status.rawValue
        self.items = items
        self.memo = memo
        self.imageUri = imageUri
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
