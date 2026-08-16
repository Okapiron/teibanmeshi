import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let surface = Color(red: 1.0, green: 0.995, blue: 0.98)
    static let surfaceMuted = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let accent = Color(red: 0.82, green: 0.25, blue: 0.07)
    static let accentSoft = Color(red: 0.98, green: 0.82, blue: 0.61)
    static let amber = Color(red: 0.70, green: 0.43, blue: 0.13)
    static let sage = Color(red: 0.32, green: 0.47, blue: 0.39)
    static let text = Color(red: 0.18, green: 0.14, blue: 0.10)
    static let divider = Color(red: 0.84, green: 0.80, blue: 0.72)
    static let photoPlaceholder = Color(red: 0.96, green: 0.89, blue: 0.76)
}

extension OrderStatus {
    var tint: Color {
        switch self {
        case .favorite:
            Color(red: 0.90, green: 0.32, blue: 0.07)
        case .wantToTry:
            AppTheme.amber
        case .tried:
            AppTheme.sage
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
    var isPrimary = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            LocalPhotoView(uri: order.imageUri, placeholderSystemImage: "fork.knife")
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: order.status.symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 19, height: 19)
                        .background(order.status.tint, in: RoundedRectangle(cornerRadius: 5))
                        .padding(3)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(order.items.joined(separator: " / "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)

                    if isPrimary {
                        Text("第一定番")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentSoft.opacity(0.45), in: Capsule())
                    }
                }

                if let memo = order.memo, !memo.isEmpty {
                    Text("メモ: \(memo)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

struct ShopThumbnail: View {
    let shop: Shop
    var size: CGFloat = 52

    var body: some View {
        LocalPhotoView(uri: shop.imageUri, placeholderSystemImage: "fork.knife")
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.16)))
            .overlay {
                RoundedRectangle(cornerRadius: min(8, size * 0.16))
                    .stroke(AppTheme.divider.opacity(0.45), lineWidth: 0.5)
            }
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

private struct PersistenceErrorAlertModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            "操作を完了できませんでした",
            isPresented: Binding(
                get: { message != nil },
                set: { isPresented in
                    if !isPresented {
                        message = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                message = nil
            }
        } message: {
            Text(message ?? "もう一度お試しください。")
        }
    }
}

extension View {
    func persistenceErrorAlert(message: Binding<String?>) -> some View {
        modifier(PersistenceErrorAlertModifier(message: message))
    }
}
