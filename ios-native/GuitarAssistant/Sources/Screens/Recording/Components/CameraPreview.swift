import SwiftUI
import AVFoundation

/// 相机预览：用 UIViewController 容纳 AVCaptureVideoPreviewLayer。
/// session 由 RecordingViewModel.prepareVideo() 提供。
struct CameraPreview: UIViewControllerRepresentable {
    let session: AVCaptureSession?

    func makeUIViewController(context: Context) -> PreviewController {
        PreviewController()
    }

    func updateUIViewController(_ uiViewController: PreviewController, context: Context) {
        uiViewController.update(session: session)
    }
}

final class PreviewController: UIViewController {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    func update(session: AVCaptureSession?) {
        guard let session else {
            previewLayer?.session = nil
            return
        }
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            previewLayer = layer
        } else {
            previewLayer?.session = session
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}
