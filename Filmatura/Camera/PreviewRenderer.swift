import Metal
import MetalKit
import CoreImage
import SwiftUI

/// Renderizza i frame elaborati (CIImage) su una MTKView con aspect fill.
/// Riceve un'immagine alla volta dal thread di elaborazione della fotocamera.
final class PreviewRenderer: NSObject {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let lock = NSLock()
    private var currentImage: CIImage?

    init(mtkView: MTKView) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice() else {
            fatalError("Metal non disponibile su questo dispositivo.")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.ciContext = CIContext(mtlDevice: device,
                                   options: [.cacheIntermediates: false])
        super.init()

        mtkView.device = device
        mtkView.framebufferOnly = false
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = self
    }

    /// Accoda il frame elaborato piu' recente (chiamato dal thread camera).
    func enqueue(_ image: CIImage) {
        lock.lock()
        currentImage = image
        lock.unlock()
    }
}

extension PreviewRenderer: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        lock.lock()
        let image = currentImage
        lock.unlock()

        guard let image else {
            commandBuffer.commit()
            return
        }

        let drawableSize = view.drawableSize
        guard image.extent.width > 0, image.extent.height > 0 else {
            commandBuffer.commit()
            return
        }

        // aspect fill centrato
        let scale = max(drawableSize.width / image.extent.width,
                        drawableSize.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let offset = CGPoint(
            x: (drawableSize.width - scaled.extent.width) / 2 - scaled.extent.origin.x,
            y: (drawableSize.height - scaled.extent.height) / 2 - scaled.extent.origin.y)
        let final = scaled.transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y))

        ciContext.render(final,
                         to: drawable.texture,
                         commandBuffer: commandBuffer,
                         bounds: CGRect(origin: .zero, size: drawableSize),
                         colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

/// Vista SwiftUI che ospita la preview Metal.
struct CameraPreviewView: UIViewRepresentable {

    let controller: CameraController

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.backgroundColor = .black
        let renderer = PreviewRenderer(mtkView: view)
        controller.previewRenderer = renderer
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
