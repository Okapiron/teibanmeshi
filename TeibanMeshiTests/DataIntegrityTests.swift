import SwiftData
import XCTest
@testable import TeibanMeshi

final class ShopNameMatcherTests: XCTestCase {
    func testExactMatchOnlyTrimsOuterWhitespace() {
        XCTAssertTrue(ShopNameMatcher.isExactMatch(" 松屋 ", "松屋"))
        XCTAssertFalse(ShopNameMatcher.isExactMatch("松屋 渋谷店", "松屋渋谷店"))
    }

    func testFormattingDifferenceIsDetectedAsSimilarButNotExact() {
        XCTAssertTrue(ShopNameMatcher.differsOnlyByFormatting("松屋 渋谷店", "松屋渋谷店"))
        XCTAssertTrue(ShopNameMatcher.differsOnlyByFormatting("ＳＴＡＲ", "star"))
        XCTAssertFalse(ShopNameMatcher.differsOnlyByFormatting("松屋", "松のや"))
    }
}

final class SearchMatcherTests: XCTestCase {
    func testSearchIgnoresKanaWidthAndCaseDifferences() {
        XCTAssertTrue(SearchMatcher.matches(query: "さいぜりや", values: ["サイゼリヤ"] ))
        XCTAssertTrue(SearchMatcher.matches(query: "star", values: ["ＳＴＡＲ"] ))
    }

    func testAllSearchTermsMustMatchAcrossValues() {
        XCTAssertTrue(
            SearchMatcher.matches(
                query: "松屋 卵",
                values: ["松屋", "牛めし並", "生卵"]
            )
        )
        XCTAssertFalse(
            SearchMatcher.matches(
                query: "松屋 チーズ",
                values: ["松屋", "牛めし並", "生卵"]
            )
        )
    }
}

@MainActor
final class DataIntegrityServiceTests: XCTestCase {
    func testOptionalGrowthFieldsPersistWithoutChangingExistingRelationships() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Shop.self,
            OrderSet.self,
            configurations: configuration
        )
        let context = container.mainContext

        let shop = Shop(name: "サイゼリヤ")
        let order = OrderSet(shopId: shop.id, status: .favorite, items: ["ミラノ風ドリア"])
        shop.imageUri = "shop.jpg"
        shop.pinnedAt = Date(timeIntervalSince1970: 1_000)
        shop.primaryOrderId = order.id
        order.imageUri = "order.jpg"
        context.insert(shop)
        context.insert(order)
        try context.save()

        let savedShop = try XCTUnwrap(context.fetch(FetchDescriptor<Shop>()).first)
        let savedOrder = try XCTUnwrap(context.fetch(FetchDescriptor<OrderSet>()).first)
        XCTAssertEqual(savedShop.imageUri, "shop.jpg")
        XCTAssertEqual(savedShop.primaryOrderId, savedOrder.id)
        XCTAssertNotNil(savedShop.pinnedAt)
        XCTAssertEqual(savedOrder.shopId, savedShop.id)
        XCTAssertEqual(savedOrder.imageUri, "order.jpg")
    }

    func testOrphanedOrdersAreRecoveredWithoutMovingValidOrders() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Shop.self,
            OrderSet.self,
            configurations: configuration
        )
        let context = container.mainContext

        let shop = Shop(name: "松屋")
        let validOrder = OrderSet(shopId: shop.id, items: ["牛めし並"])
        let orphanedOrder = OrderSet(shopId: "missing-shop", items: ["復旧対象"])
        context.insert(shop)
        context.insert(validOrder)
        context.insert(orphanedOrder)
        try context.save()

        let recoveredCount = try DataIntegrityService.repairOrphanedOrders(in: context)

        XCTAssertEqual(recoveredCount, 1)
        XCTAssertEqual(validOrder.shopId, shop.id)
        XCTAssertEqual(orphanedOrder.shopId, DataIntegrityService.recoveredShopId)

        let recoveredShops = try context.fetch(FetchDescriptor<Shop>())
            .filter { $0.id == DataIntegrityService.recoveredShopId }
        XCTAssertEqual(recoveredShops.count, 1)
        XCTAssertEqual(recoveredShops.first?.name, DataIntegrityService.recoveredShopName)

        XCTAssertEqual(try DataIntegrityService.repairOrphanedOrders(in: context), 0)
    }
}
