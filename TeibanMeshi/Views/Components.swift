import SwiftUI

enum AppTheme {
    static let background = Color(red: 1.0, green: 0.97, blue: 0.90)
    static let surface = Color(red: 1.0, green: 0.99, blue: 0.95)
    static let accent = Color(red: 0.86, green: 0.29, blue: 0.06)
    static let accentSoft = Color(red: 1.0, green: 0.86, blue: 0.66)
    static let text = Color(red: 0.23, green: 0.17, blue: 0.12)
}

extension OrderStatus {
    var tint: Color {
        switch self {
        case .favorite:
            Color(red: 0.90, green: 0.32, blue: 0.07)
        case .wantToTry:
            Color(red: 0.72, green: 0.46, blue: 0.19)
        case .tried:
            Color(red: 0.36, green: 0.49, blue: 0.42)
        }
    }

    var softTint: Color {
        tint.opacity(0.12)
    }
}

struct StatusLabel: View {
    let status: OrderStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.symbol)
                .font(.caption.weight(.bold))
            Text(status.title)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(status.softTint, in: Capsule())
    }
}

struct OrderRow: View {
    let order: OrderSet

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: order.status.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(order.status.tint)
                .frame(width: 22, height: 22)
                .background(order.status.softTint, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(order.items.joined(separator: " / "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)

                if let memo = order.memo, !memo.isEmpty {
                    Text("メモ: \(memo)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct EmptyHintView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
