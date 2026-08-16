import SwiftData
import SwiftUI

struct ShopDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var orderSets: [OrderSet]

    let shop: Shop

    @State private var isShowingAddOrder = false
    @State private var isShowingRenameShop = false
    @State private var isShowingShopPhoto = false
    @State private var editingOrder: OrderSet?
    @State private var persistenceErrorMessage: String?

    private var shopOrders: [OrderSet] {
        orderSets
            .filter { $0.shopId == shop.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    LocalPhotoView(uri: shop.imageUri, placeholderSystemImage: "storefront")
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 8) {
                        Text(shop.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)

                        if shop.pinnedAt != nil {
                            Image(systemName: "pin.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.amber)
                                .accessibilityLabel("ピン留め済み")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            orderSection(status: .favorite)
            orderSection(status: .wantToTry)
            orderSection(status: .tried)

            Section {
                Button {
                    isShowingAddOrder = true
                } label: {
                    Label("この店で追加", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .listRowBackground(AppTheme.surface)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .tint(AppTheme.accent)
        .navigationTitle(shop.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isShowingRenameShop = true
                    } label: {
                        Label("店名を変更", systemImage: "pencil")
                    }
                    Button {
                        isShowingShopPhoto = true
                    } label: {
                        Label("店の写真を変更", systemImage: "photo")
                    }
                    Button {
                        togglePin()
                    } label: {
                        Label(
                            shop.pinnedAt == nil ? "店をピン留め" : "ピン留めを外す",
                            systemImage: shop.pinnedAt == nil ? "pin.fill" : "pin.slash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("店の操作")
            }
        }
        .onAppear(perform: updateLastViewedAt)
        .sheet(isPresented: $isShowingAddOrder) {
            OrderFormView(mode: .create(prefilledShopName: shop.name, fixedShopId: shop.id))
        }
        .sheet(isPresented: $isShowingRenameShop) {
            ShopNameEditView(shop: shop)
        }
        .sheet(isPresented: $isShowingShopPhoto) {
            ShopPhotoEditView(shop: shop)
        }
        .sheet(item: $editingOrder) { order in
            OrderFormView(mode: .edit(order: order))
        }
        .persistenceErrorAlert(message: $persistenceErrorMessage)
    }

    private func orderSection(status: OrderStatus) -> some View {
        let orders = shopOrders.filter { $0.status == status }

        return Section {
            if orders.isEmpty {
                Text(status == .favorite ? "定番はまだありません" : "\(status.title)はまだありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .listRowBackground(AppTheme.surface)
            } else {
                ForEach(orders) { order in
                    Button {
                        editingOrder = order
                    } label: {
                        OrderRow(order: order, isPrimary: shop.primaryOrderId == order.id)
                            .contentShape(Rectangle())
                    }
                    .contextMenu {
                        Button {
                            editingOrder = order
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }

                        Button {
                            duplicateOrder(order)
                        } label: {
                            Label("複製", systemImage: "plus.square.on.square")
                        }

                        if order.status == .favorite {
                            Button {
                                togglePrimaryOrder(order)
                            } label: {
                                Label(
                                    shop.primaryOrderId == order.id ? "第一定番を解除" : "第一定番にする",
                                    systemImage: shop.primaryOrderId == order.id ? "bookmark.slash" : "bookmark.fill"
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ForEach(OrderStatus.allCases.filter { $0 != order.status }) { status in
                            Button {
                                moveOrder(order, to: status)
                            } label: {
                                Text(status.title)
                            }
                            .tint(status.tint)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            duplicateOrder(order)
                        } label: {
                            Label("複製", systemImage: "plus.square.on.square")
                        }
                        .tint(AppTheme.sage)

                        if order.status == .favorite {
                            Button {
                                togglePrimaryOrder(order)
                            } label: {
                                Label(
                                    shop.primaryOrderId == order.id ? "第一定番を解除" : "第一定番",
                                    systemImage: shop.primaryOrderId == order.id ? "bookmark.slash" : "bookmark.fill"
                                )
                            }
                            .tint(AppTheme.amber)
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                }
            }
        } header: {
            StatusLabel(status: status)
        }
    }

    private func updateLastViewedAt() {
        let now = Date()
        shop.lastViewedAt = now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func moveOrder(_ order: OrderSet, to status: OrderStatus) {
        let now = Date()
        order.status = status
        if status != .favorite, shop.primaryOrderId == order.id {
            shop.primaryOrderId = nil
        }
        order.updatedAt = now
        shop.updatedAt = now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = "状態を変更できませんでした。もう一度お試しください。"
        }
    }

    private func togglePin() {
        if shop.pinnedAt != nil {
            setPinned(false)
            return
        }

        setPinned(true)
    }

    private func setPinned(_ isPinned: Bool) {
        shop.pinnedAt = isPinned ? Date() : nil
        shop.updatedAt = Date()
        saveShop(message: "ピン留めを変更できませんでした。もう一度お試しください。")
    }

    private func togglePrimaryOrder(_ order: OrderSet) {
        shop.primaryOrderId = shop.primaryOrderId == order.id ? nil : order.id
        shop.updatedAt = Date()
        saveShop(message: "第一定番を変更できませんでした。もう一度お試しください。")
    }

    private func duplicateOrder(_ order: OrderSet) {
        let now = Date()
        let duplicateImageUri = try? LocalImageStore.copy(order.imageUri)
        let duplicate = OrderSet(
            shopId: shop.id,
            status: order.status,
            items: order.items,
            memo: order.memo,
            imageUri: duplicateImageUri,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(duplicate)
        shop.updatedAt = now
        do {
            try modelContext.save()
            editingOrder = duplicate
        } catch {
            modelContext.rollback()
            LocalImageStore.delete(duplicateImageUri)
            persistenceErrorMessage = "注文メモを複製できませんでした。もう一度お試しください。"
        }
    }

    private func saveShop(message: String) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = message
        }
    }
}

private struct ShopPhotoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let shop: Shop

    @State private var imageUri: String?
    @State private var didCommit = false
    @State private var persistenceErrorMessage: String?
    private let originalImageUri: String?

    init(shop: Shop) {
        self.shop = shop
        originalImageUri = shop.imageUri
        _imageUri = State(initialValue: shop.imageUri)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("店の代表写真") {
                    PhotoEditor(
                        title: shop.name,
                        helper: "店一覧や店詳細で見分けるための写真です。",
                        placeholderSystemImage: "storefront",
                        originalImageUri: originalImageUri,
                        imageUri: $imageUri
                    )
                }
            }
            .navigationTitle("店の写真")
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
            .onDisappear {
                if !didCommit, imageUri != originalImageUri {
                    LocalImageStore.delete(imageUri)
                }
            }
            .persistenceErrorAlert(message: $persistenceErrorMessage)
        }
    }

    private func save() {
        shop.imageUri = imageUri
        shop.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = "店の写真を保存できませんでした。もう一度お試しください。"
            return
        }
        if originalImageUri != imageUri {
            LocalImageStore.delete(originalImageUri)
        }
        didCommit = true
        dismiss()
    }
}

struct ShopNameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var shops: [Shop]

    let shop: Shop

    @State private var name: String
    @State private var validationMessage: String?
    @State private var persistenceErrorMessage: String?

    init(shop: Shop) {
        self.shop = shop
        _name = State(initialValue: shop.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("店名") {
                    TextField("例: 松屋", text: $name)
                        .textInputAutocapitalization(.never)

                    Text("この店に紐づく定番、次試す、試した記録の店名をまとめて変更します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("店名を変更")
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .persistenceErrorAlert(message: $persistenceErrorMessage)
        }
    }

    private func save() {
        let trimmedName = ShopNameMatcher.trimmed(name)

        guard !trimmedName.isEmpty else {
            validationMessage = "店名を入力してください。"
            return
        }

        if shops.contains(where: { $0.id != shop.id && ShopNameMatcher.isExactMatch($0.name, trimmedName) }) {
            validationMessage = "同じ店名がすでにあります。注文メモの移動や統合は今後対応予定です。"
            return
        }

        if shops.contains(where: { $0.id != shop.id && ShopNameMatcher.differsOnlyByFormatting($0.name, trimmedName) }) {
            validationMessage = "空白や文字幅だけが異なる店名がすでにあります。重複を避けるため、別の店名を入力してください。"
            return
        }

        shop.name = trimmedName
        shop.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = "店名を保存できませんでした。入力内容を確認して、もう一度お試しください。"
            return
        }
        dismiss()
    }
}
