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
///
/// La imagen compuesta es solo para archivo y vista previa —el reconocimiento
/// trabaja sobre cada página por separado—, así que se acota su tamaño: cinco
/// páginas a resolución completa arman un lienzo de más de 100 MB y el sistema
/// termina cerrando la app.
enum ReceiptImageComposer {
    /// Presupuesto del lienzo en píxeles (~24 MP): sobra para leer la foto
    /// guardada y evita picos de memoria en boletas de muchas páginas.
    static let maximumPixels: CGFloat = 24_000_000

    static func stitchVertically(_ images: [UIImage]) -> UIImage? {
        guard !images.isEmpty else { return nil }
        if images.count == 1 { return images[0] }

        // `size` va en puntos; el lienzo se arma en píxeles para no perder
        // resolución con imágenes de escala distinta de 1.
        let pixelSizes = images.map { CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale) }
        let targetWidth = pixelSizes.map(\.width).max() ?? 0
        guard targetWidth > 0 else { return images.first }

        var scaledSizes = pixelSizes.map { size -> CGSize in
            let ratio = targetWidth / size.width
            return CGSize(width: targetWidth, height: size.height * ratio)
        }
        var canvasWidth = targetWidth
        var totalHeight = scaledSizes.map(\.height).reduce(0, +)

        if canvasWidth * totalHeight > maximumPixels {
            let shrink = (maximumPixels / (canvasWidth * totalHeight)).squareRoot()
            canvasWidth *= shrink
            scaledSizes = scaledSizes.map { CGSize(width: $0.width * shrink, height: $0.height * shrink) }
            totalHeight = scaledSizes.map(\.height).reduce(0, +)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasWidth, height: totalHeight),
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
