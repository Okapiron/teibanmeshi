import SwiftData
import SwiftUI

enum OrderFormMode {
    case create(prefilledShopName: String?, fixedShopId: String? = nil)
    case edit(order: OrderSet)
}

struct OrderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var shops: [Shop]

    let mode: OrderFormMode
    var onSave: ((String) -> Void)?

    @State private var shopName: String
    @State private var itemDrafts: [String]
    @State private var selectedStatus: OrderStatus
    @State private var memo: String
    @State private var imageUri: String?
    @State private var selectedSuggestionShopId: String?
    @State private var allowsNewShopDespiteSuggestions = false
    @State private var showingDeleteConfirmation = false
    @State private var validationMessage: String?
    @State private var persistenceErrorMessage: String?
    @State private var didCommit = false
    @FocusState private var focusedItemIndex: Int?

    private let originalImageUri: String?

    init(mode: OrderFormMode, onSave: ((String) -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create(let prefilledShopName, _):
            originalImageUri = nil
            _shopName = State(initialValue: prefilledShopName ?? "")
            _itemDrafts = State(initialValue: [""])
            _selectedStatus = State(initialValue: .tried)
            _memo = State(initialValue: "")
            _imageUri = State(initialValue: nil)
        case .edit(let order):
            originalImageUri = order.imageUri
            _shopName = State(initialValue: "")
            _itemDrafts = State(initialValue: order.items + [""])
            _selectedStatus = State(initialValue: order.status)
            _memo = State(initialValue: order.memo ?? "")
            _imageUri = State(initialValue: order.imageUri)
        }
    }

    private var title: String {
        switch mode {
        case .create:
            "新しく記録"
        case .edit:
            "記録を編集"
        }
    }

    private var isShopNameEditable: Bool {
        if case .create(_, let fixedShopId) = mode {
            return fixedShopId == nil
        }
        return false
    }

    private var trimmedShopName: String {
        ShopNameMatcher.trimmed(shopName)
    }

    private var selectedSuggestionShop: Shop? {
        guard let selectedSuggestionShopId else { return nil }
        return shops.first(where: { $0.id == selectedSuggestionShopId })
    }

    private var suggestedShops: [Shop] {
        matchingShops(for: trimmedShopName)
    }

    private var shopNameBinding: Binding<String> {
        Binding(
            get: { shopName },
            set: { value in
                shopName = value
                validationMessage = nil
                allowsNewShopDespiteSuggestions = false

                if let selectedSuggestionShop, value != selectedSuggestionShop.name {
                    selectedSuggestionShopId = nil
                }
            }
        )
    }

    private var shopNameCaption: String {
        switch mode {
        case .create(_, let fixedShopId) where fixedShopId != nil:
            "この店の注文として追加します。"
        case .edit:
            "店名は店詳細のメニューから変更できます。"
        default:
            ""
        }
    }

    private var fixedTargetShopId: String? {
        switch mode {
        case .create(_, let fixedShopId):
            fixedShopId
        case .edit(let order):
            order.shopId
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("店名") {
                    if isShopNameEditable {
                        TextField("例: 松屋", text: shopNameBinding)
                            .textInputAutocapitalization(.never)

                        if let selectedSuggestionShop {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                                Text("\(selectedSuggestionShop.name) に追加します")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }

                        if !suggestedShops.isEmpty {
                            Text("登録済みの店")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(suggestedShops) { shop in
                                Button {
                                    selectSuggestedShop(shop)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(shop.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            Text("この店に注文メモを追加")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedSuggestionShopId == shop.id {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        HStack {
                            Text(shopName.isEmpty ? "店名を読み込み中" : shopName)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !shopNameCaption.isEmpty {
                            Text(shopNameCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("注文内容") {
                    ForEach(itemDrafts.indices, id: \.self) { index in
                        TextField("注文内容", text: itemBinding(for: index), axis: .vertical)
                            .lineLimit(1...3)
                            .focused($focusedItemIndex, equals: index)
                            .submitLabel(.next)
                            .onSubmit {
                                moveFocusAfterSubmit(from: index)
                            }
                    }
                }

                Section("注文写真") {
                    PhotoEditor(
                        title: "注文を見分ける写真",
                        helper: "料理やメニューの写真を1枚登録できます。",
                        placeholderSystemImage: "fork.knife",
                        originalImageUri: originalImageUri,
                        imageUri: $imageUri
                    )
                }

                Section("状態") {
                    Picker("状態", selection: $selectedStatus) {
                        ForEach(OrderStatus.allCases) { status in
                            Text(status.title)
                                .tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("メモ") {
                    TextField("例：980円、味濃い、疲れてる日に良い、次は卵なし", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)

                        if shouldShowCreateNewShopButton {
                            Button {
                                allowsNewShopDespiteSuggestions = true
                                save()
                            } label: {
                                Label("新しい店として保存", systemImage: "plus")
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                }

                if case .edit = mode {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .onAppear {
                hydrateShopNameIfNeeded()
                normalizeDraftRows()
            }
            .onDisappear(perform: discardUncommittedPhoto)
            .confirmationDialog("この記録を削除しますか？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    deleteOrder()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
            .persistenceErrorAlert(message: $persistenceErrorMessage)
        }
    }

    private func itemBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                itemDrafts.indices.contains(index) ? itemDrafts[index] : ""
            },
            set: { value in
                guard itemDrafts.indices.contains(index) else { return }
                itemDrafts[index] = value
                normalizeDraftRows()
            }
        )
    }

    private func normalizeDraftRows() {
        while itemDrafts.count > 1,
              itemDrafts.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true,
              itemDrafts.dropLast().last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            itemDrafts.removeLast()
        }

        if itemDrafts.isEmpty || itemDrafts.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            itemDrafts.append("")
        }
    }

    private func moveFocusAfterSubmit(from index: Int) {
        if index == itemDrafts.count - 1 {
            normalizeDraftRows()
        }
        focusedItemIndex = min(index + 1, itemDrafts.count - 1)
    }

    private func hydrateShopNameIfNeeded() {
        guard case .edit(let order) = mode, shopName.isEmpty else { return }
        shopName = shops.first(where: { $0.id == order.shopId })?.name ?? ""
    }

    private var shouldShowCreateNewShopButton: Bool {
        guard isShopNameEditable,
              selectedSuggestionShopId == nil,
              !suggestedShops.isEmpty,
              shops.first(where: { ShopNameMatcher.isExactMatch($0.name, trimmedShopName) }) == nil else {
            return false
        }
        return true
    }

    private func normalizedItems() -> [String] {
        itemDrafts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        let normalizedShopName = trimmedShopName
        let items = normalizedItems()
        let normalizedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedShopName.isEmpty else {
            validationMessage = "店名を入力してください。"
            return
        }

        guard !items.isEmpty else {
            validationMessage = "注文内容を1行以上入力してください。"
            return
        }

        if shouldWarnAboutSimilarShops {
            let names = suggestedShops.map(\.name).joined(separator: "、")
            validationMessage = "似た店名があります: \(names)。既存の店を選ぶか、新しい店として保存してください。"
            return
        }

        let now = Date()
        let shop = targetShop(named: normalizedShopName, now: now)

        switch mode {
        case .create:
            let order = OrderSet(
                shopId: shop.id,
                status: selectedStatus,
                items: items,
                memo: normalizedMemo.isEmpty ? nil : normalizedMemo,
                imageUri: imageUri,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(order)
            if selectedStatus == .favorite, shop.primaryOrderId == nil {
                shop.primaryOrderId = order.id
            }
        case .edit(let order):
            order.status = selectedStatus
            order.items = items
            order.memo = normalizedMemo.isEmpty ? nil : normalizedMemo
            order.imageUri = imageUri
            order.updatedAt = now
            if selectedStatus == .favorite, shop.primaryOrderId == nil {
                shop.primaryOrderId = order.id
            } else if selectedStatus != .favorite, shop.primaryOrderId == order.id {
                shop.primaryOrderId = nil
            }
        }

        shop.updatedAt = now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = "記録を保存できませんでした。入力内容は画面に残っています。もう一度お試しください。"
            return
        }
        if originalImageUri != imageUri {
            LocalImageStore.delete(originalImageUri)
        }
        didCommit = true
        onSave?(shop.id)
        dismiss()
    }

    private func targetShop(named name: String, now: Date) -> Shop {
        if let fixedShopId = fixedTargetShopId,
           let fixedShop = shops.first(where: { $0.id == fixedShopId }) {
            return fixedShop
        }

        if let selectedSuggestionShopId,
           let selectedShop = shops.first(where: { $0.id == selectedSuggestionShopId }) {
            return selectedShop
        }

        if let existingShop = shops.first(where: { ShopNameMatcher.isExactMatch($0.name, name) }) {
            return existingShop
        }

        let shop = Shop(name: name, createdAt: now, updatedAt: now)
        modelContext.insert(shop)
        return shop
    }

    private var shouldWarnAboutSimilarShops: Bool {
        isShopNameEditable
            && selectedSuggestionShopId == nil
            && !allowsNewShopDespiteSuggestions
            && shops.first(where: { ShopNameMatcher.isExactMatch($0.name, trimmedShopName) }) == nil
            && !suggestedShops.isEmpty
    }

    private func selectSuggestedShop(_ shop: Shop) {
        selectedSuggestionShopId = shop.id
        shopName = shop.name
        validationMessage = nil
        allowsNewShopDespiteSuggestions = false
    }

    private func matchingShops(for input: String) -> [Shop] {
        let normalizedInput = ShopNameMatcher.similarityKey(input)
        guard isShopNameEditable, !normalizedInput.isEmpty else { return [] }

        return shops
            .compactMap { shop -> (shop: Shop, score: Int)? in
                let score = suggestionScore(input: normalizedInput, shopName: ShopNameMatcher.similarityKey(shop.name))
                guard score > 0 else { return nil }
                return (shop, score)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.shop.name.localizedStandardCompare($1.shop.name) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .prefix(5)
            .map(\.shop)
    }

    private func suggestionScore(input: String, shopName: String) -> Int {
        guard !input.isEmpty, !shopName.isEmpty else { return 0 }
        if input == shopName { return 100 }
        if shopName.hasPrefix(input) { return 90 }
        if input.hasPrefix(shopName) { return 85 }
        if shopName.contains(input) || input.contains(shopName) { return 75 }

        let commonPrefixLength = zip(input, shopName).prefix { pair in pair.0 == pair.1 }.count
        if commonPrefixLength >= 2 { return 55 + commonPrefixLength }
        if commonPrefixLength == 1, min(input.count, shopName.count) <= 4 { return 35 }

        return 0
    }

    private func deleteOrder() {
        guard case .edit(let order) = mode else { return }
        let persistedImageUri = order.imageUri
        if let shop = shops.first(where: { $0.id == order.shopId }),
           shop.primaryOrderId == order.id {
            shop.primaryOrderId = nil
            shop.updatedAt = Date()
        }
        modelContext.delete(order)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = "記録を削除できませんでした。もう一度お試しください。"
            return
        }
        LocalImageStore.delete(persistedImageUri)
        if imageUri != persistedImageUri {
            LocalImageStore.delete(imageUri)
        }
        didCommit = true
        dismiss()
    }

    private func cancel() {
        dismiss()
    }

    private func discardUncommittedPhoto() {
        guard !didCommit, imageUri != originalImageUri else { return }
        LocalImageStore.delete(imageUri)
    }
}
