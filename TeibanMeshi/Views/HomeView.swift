import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            ShopListView()
                .tabItem {
                    Label("一覧", systemImage: "list.bullet")
                }
        }
        .tint(AppTheme.accent)
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shops: [Shop]
    @Query private var orderSets: [OrderSet]

    @State private var searchText = ""
    @State private var isShowingNewOrder = false
    @State private var navigationPath: [String] = []

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentShops: [Shop] {
        shops
            .filter { $0.lastViewedAt != nil }
            .sorted { ($0.lastViewedAt ?? .distantPast) > ($1.lastViewedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    private var searchResults: [(shop: Shop, orders: [OrderSet])] {
        guard !trimmedSearchText.isEmpty else { return [] }
        let keyword = trimmedSearchText.localizedLowercase

        return shops
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { shop in
                let shopMatches = shop.name.localizedLowercase.contains(keyword)
                let matchingOrders = orderSets
                    .filter { $0.shopId == shop.id }
                    .filter { order in
                        shopMatches
                            || order.items.joined(separator: " ").localizedLowercase.contains(keyword)
                            || (order.memo ?? "").localizedLowercase.contains(keyword)
                    }
                    .sorted { $0.updatedAt > $1.updatedAt }

                if shopMatches || !matchingOrders.isEmpty {
                    return (shop, matchingOrders)
                }
                return nil
            }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: AppTheme.accent.opacity(0.18), radius: 8, y: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("定番メシ")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("いつもの注文メモ")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if trimmedSearchText.isEmpty {
                    recentSection
                    newOrderSection
                    if shops.isEmpty {
                        Section {
                            EmptyHintView(
                                title: "まだ記録がありません",
                                message: "よく行くお店の「いつもの注文」を登録してみましょう。"
                            )
                        }
                    }
                } else {
                    searchResultSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .tint(AppTheme.accent)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "店名・メニューで検索")
            .navigationDestination(for: String.self) { shopId in
                if let shop = shops.first(where: { $0.id == shopId }) {
                    ShopDetailView(shop: shop)
                } else {
                    Text("店が見つかりませんでした")
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $isShowingNewOrder) {
                OrderFormView(mode: .create(prefilledShopName: trimmedSearchText.isEmpty ? nil : trimmedSearchText)) { shopId in
                    navigationPath.append(shopId)
                }
            }
        }
    }

    private var recentSection: some View {
        Section("最近見た店") {
            if recentShops.isEmpty {
                Text("店詳細を開くとここに表示されます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .listRowBackground(AppTheme.surface)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentShops) { shop in
                            Button {
                                navigationPath.append(shop.id)
                            } label: {
                                Text(shop.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(AppTheme.accentSoft.opacity(0.55), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(AppTheme.surface)
            }
        }
    }

    private var newOrderSection: some View {
        Section {
            Button {
                isShowingNewOrder = true
            } label: {
                Label("新しく記録", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listRowBackground(AppTheme.surface)
    }

    private var searchResultSection: some View {
        Section("検索結果") {
            if searchResults.isEmpty {
                EmptyHintView(title: "見つかりませんでした", message: "新しく記録しますか？")
                Button {
                    isShowingNewOrder = true
                } label: {
                    Label("新しく記録", systemImage: "plus")
                }
            } else {
                ForEach(searchResults, id: \.shop.id) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            navigationPath.append(result.shop.id)
                        } label: {
                            HStack {
                                Text(result.shop.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if result.orders.isEmpty {
                            Text("この店の注文メモはまだありません")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(result.orders) { order in
                                Button {
                                    navigationPath.append(result.shop.id)
                                } label: {
                                    OrderRow(order: order)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .listRowBackground(AppTheme.surface)
                }
            }
        }
    }
}

private enum ShopListSort: String, CaseIterable, Identifiable {
    case name
    case created

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            "五十音順"
        case .created:
            "追加順"
        }
    }
}

struct ShopListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shops: [Shop]
    @Query private var orderSets: [OrderSet]

    @State private var sort: ShopListSort = .name
    @State private var navigationPath: [String] = []
    @State private var shopPendingDeletion: Shop?
    @State private var isShowingDeleteShopConfirmation = false

    private var sortedShops: [Shop] {
        switch sort {
        case .name:
            shops.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .created:
            shops.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    Picker("並び順", selection: $sort) {
                        ForEach(ShopListSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(AppTheme.surface)

                if sortedShops.isEmpty {
                    Section {
                        EmptyHintView(
                            title: "登録済みの店はまだありません",
                            message: "ホームから「新しく記録」で、よく行く店の注文メモを追加しましょう。"
                        )
                    }
                    .listRowBackground(AppTheme.surface)
                } else {
                    Section("登録済みの店") {
                        ForEach(sortedShops) { shop in
                            Button {
                                navigationPath.append(shop.id)
                            } label: {
                                ShopListRow(shop: shop, orderCount: orderCount(for: shop))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    shopPendingDeletion = shop
                                    isShowingDeleteShopConfirmation = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .listRowBackground(AppTheme.surface)
                        }
                    }
                }
            }
            .navigationTitle("店一覧")
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .tint(AppTheme.accent)
            .navigationDestination(for: String.self) { shopId in
                if let shop = shops.first(where: { $0.id == shopId }) {
                    ShopDetailView(shop: shop)
                } else {
                    Text("店が見つかりませんでした")
                        .foregroundStyle(.secondary)
                }
            }
            .confirmationDialog("この店を削除しますか？", isPresented: $isShowingDeleteShopConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    deletePendingShop()
                }
                Button("キャンセル", role: .cancel) {
                    shopPendingDeletion = nil
                }
            } message: {
                if let shopPendingDeletion {
                    Text("「\(shopPendingDeletion.name)」と、この店の注文メモ\(orderCount(for: shopPendingDeletion))件を削除します。この操作は取り消せません。")
                } else {
                    Text("この操作は取り消せません。")
                }
            }
        }
    }

    private func orderCount(for shop: Shop) -> Int {
        orderSets.filter { $0.shopId == shop.id }.count
    }

    private func deletePendingShop() {
        guard let shop = shopPendingDeletion else { return }

        orderSets
            .filter { $0.shopId == shop.id }
            .forEach { modelContext.delete($0) }

        modelContext.delete(shop)
        try? modelContext.save()
        shopPendingDeletion = nil
    }
}

private struct ShopListRow: View {
    let shop: Shop
    let orderCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accentSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)

                Text("\(orderCount)件の注文メモ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}
