import SwiftUI
import UIKit
import VisionKit

/// Cámara de documentos del sistema para boletas: recorta, corrige perspectiva
/// y permite capturar boletas largas en varias páginas.
struct ReceiptDocumentCamera: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: ReceiptDocumentCamera

        init(parent: ReceiptDocumentCamera) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.dismiss()
            guard !pages.isEmpty else { return }
            parent.onScan(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.dismiss()
        }
    }
}

/// Une las páginas de una boleta larga en una sola imagen vertical para
/// guardarla y mostrarla como una boleta continua.
enum ReceiptImageComposer {
    static func stitchVertically(_ images: [UIImage]) -> UIImage? {
        guard !images.isEmpty else { return nil }
        if images.count == 1 { return images[0] }

        let targetWidth = images.map(\.size.width).max() ?? 0
        guard targetWidth > 0 else { return images.first }

        let scaledSizes = images.map { image -> CGSize in
            let scale = targetWidth / image.size.width
            return CGSize(width: targetWidth, height: image.size.height * scale)
        }
        let totalHeight = scaledSizes.map(\.height).reduce(0, +)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetWidth, height: totalHeight),
            format: format
        )

        return renderer.image { _ in
            var offsetY: CGFloat = 0
            for (image, size) in zip(images, scaledSizes) {
                image.draw(in: CGRect(x: 0, y: offsetY, width: size.width, height: size.height))
                offsetY += size.height
            }
        }
    }
}
