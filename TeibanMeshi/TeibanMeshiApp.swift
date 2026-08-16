import SwiftData
import SwiftUI

@main
struct TeibanMeshiApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [Shop.self, OrderSet.self])
    }
}

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var integrityNotice: IntegrityNotice?
    @State private var hasCheckedDataIntegrity = false

    var body: some View {
        MainTabView()
            .task {
                guard !hasCheckedDataIntegrity else { return }
                hasCheckedDataIntegrity = true

                do {
                    let recoveredCount = try DataIntegrityService.repairOrphanedOrders(in: modelContext)
                    if recoveredCount > 0 {
                        integrityNotice = IntegrityNotice(
                            title: "注文メモを復旧しました",
                            message: "店との紐づけが切れていた注文メモを\(recoveredCount)件、「復旧した注文」に移動しました。店一覧から確認できます。"
                        )
                    }
                } catch {
                    integrityNotice = IntegrityNotice(
                        title: "データを確認できませんでした",
                        message: "注文メモは変更していません。アプリを起動し直して、もう一度お試しください。"
                    )
                }
            }
            .alert(item: $integrityNotice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

private struct IntegrityNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
enum DataIntegrityService {
    static let recoveredShopId = "com.okapiron.TeibanMeshi.recovered-orders"
    static let recoveredShopName = "復旧した注文"

    static func repairOrphanedOrders(in modelContext: ModelContext) throws -> Int {
        let shops = try modelContext.fetch(FetchDescriptor<Shop>())
        let orders = try modelContext.fetch(FetchDescriptor<OrderSet>())
        let shopIds = Set(shops.map(\.id))
        let orphanedOrders = orders.filter { !shopIds.contains($0.shopId) }

        guard !orphanedOrders.isEmpty else { return 0 }

        let now = Date()
        let recoveredShop: Shop
        if let existingShop = shops.first(where: { $0.id == recoveredShopId }) {
            recoveredShop = existingShop
            recoveredShop.updatedAt = now
        } else {
            recoveredShop = Shop(
                id: recoveredShopId,
                name: recoveredShopName,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(recoveredShop)
        }

        orphanedOrders.forEach { order in
            order.shopId = recoveredShop.id
        }

        do {
            try modelContext.save()
            return orphanedOrders.count
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
