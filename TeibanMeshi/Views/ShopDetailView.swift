import SwiftData
import SwiftUI

struct ShopDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var orderSets: [OrderSet]

    let shop: Shop

    @State private var isShowingAddOrder = false
    @State private var isShowingRenameShop = false
    @State private var editingOrder: OrderSet?

    private var shopOrders: [OrderSet] {
        orderSets
            .filter { $0.shopId == shop.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accentSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(shop.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                    }
                }
                .padding(.vertical, 2)
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
        .sheet(item: $editingOrder) { order in
            OrderFormView(mode: .edit(order: order))
        }
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
                        OrderRow(order: order)
                            .contentShape(Rectangle())
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
        shop.updatedAt = now
        try? modelContext.save()
    }

    private func moveOrder(_ order: OrderSet, to status: OrderStatus) {
        let now = Date()
        order.status = status
        order.updatedAt = now
        shop.updatedAt = now
        try? modelContext.save()
    }
}

struct ShopNameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var shops: [Shop]

    let shop: Shop

    @State private var name: String
    @State private var validationMessage: String?

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
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "店名を入力してください。"
            return
        }

        if shops.contains(where: { $0.id != shop.id && $0.name == trimmedName }) {
            validationMessage = "同じ店名がすでにあります。注文メモの移動や統合は今後対応予定です。"
            return
        }

        shop.name = trimmedName
        shop.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
