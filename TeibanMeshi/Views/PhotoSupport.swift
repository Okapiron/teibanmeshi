import PhotosUI
import SwiftUI
import UIKit

enum LocalImageStore {
    private static let folderName = "Images"

    static func image(for uri: String?) -> UIImage? {
        guard let url = url(for: uri),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func store(_ image: UIImage) throws -> String {
        let directory = try imagesDirectory()
        let fileName = "\(UUID().uuidString).jpg"
        let destination = directory.appendingPathComponent(fileName)
        let preparedImage = image.preparingForStorage(maxDimension: 1_600)

        guard let data = preparedImage.jpegData(compressionQuality: 0.82) else {
            throw LocalImageStoreError.encodingFailed
        }

        try data.write(to: destination, options: .atomic)
        return fileName
    }

    static func copy(_ uri: String?) throws -> String? {
        guard let image = image(for: uri) else { return nil }
        return try store(image)
    }

    static func delete(_ uri: String?) {
        guard let url = url(for: uri) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func url(for uri: String?) -> URL? {
        guard let uri, !uri.isEmpty else { return nil }
        if uri.hasPrefix("/") {
            return URL(fileURLWithPath: uri)
        }
        guard let directory = try? imagesDirectory() else { return nil }
        return directory.appendingPathComponent(uri)
    }

    private static func imagesDirectory() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private enum LocalImageStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "画像を保存できませんでした。"
    }
}

private extension UIImage {
    func preparingForStorage(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct LocalPhotoView: View {
    let uri: String?
    let placeholderSystemImage: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.photoPlaceholder
                    Image(systemName: placeholderSystemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .clipped()
        .task(id: uri) {
            image = LocalImageStore.image(for: uri)
        }
    }
}

struct PhotoEditor: View {
    let title: String
    let helper: String
    let placeholderSystemImage: String
    let originalImageUri: String?
    @Binding var imageUri: String?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingSourceDialog = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                LocalPhotoView(uri: imageUri, placeholderSystemImage: placeholderSystemImage)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(helper)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(imageUri == nil ? "写真を追加" : "写真を変更") {
                        isShowingSourceDialog = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                }

                Spacer(minLength: 0)
            }
        }
        .confirmationDialog("写真を追加", isPresented: $isShowingSourceDialog) {
            Button("写真を撮る") {
                isShowingCamera = true
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            Button("写真ライブラリから選ぶ") {
                isShowingPhotoLibrary = true
            }

            if imageUri != nil {
                Button("写真を削除", role: .destructive) {
                    if imageUri != originalImageUri {
                        LocalImageStore.delete(imageUri)
                    }
                    imageUri = nil
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $selectedItem,
            matching: .images
        )
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadPhoto(from: newItem)
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                persist(image)
            }
            .ignoresSafeArea()
        }
        .alert("写真を保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "もう一度お試しください。")
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem) async {
        defer { selectedItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "選択した画像を読み込めませんでした。"
                return
            }
            persist(image)
        } catch {
            errorMessage = "選択した画像を読み込めませんでした。"
        }
    }

    private func persist(_ image: UIImage) {
        do {
            if imageUri != originalImageUri {
                LocalImageStore.delete(imageUri)
            }
            imageUri = try LocalImageStore.store(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onSelect: (UIImage) -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
