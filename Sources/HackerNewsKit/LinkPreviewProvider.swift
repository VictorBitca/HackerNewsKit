import LinkPresentation
import Combine

/// Provides a preview image if possble for the URL.
///
/// It uses `LPMetadataProvider` that in turn uses Safari to access and generate the thumbnail.
/// The number of concurrent tasks is limited to four because the preview generation is rather slow and only runs on the main thread.
@MainActor
public class LinkPreviewProvider {
    static public let shared = LinkPreviewProvider()
    
    private let taskQueue = TaskQueue(concurrency: 4)
    
    public func previewImage(for url: URL, imageTargetSize: CGSize = CGSize(width: 300, height: 300)) async -> UIImage? {
        let imageKey = "image+\(url.absoluteString.sanitizedFileName)"
        
        if let cachedImage = DiskPersistor.imageFromCache(for: imageKey) { return cachedImage }
        
        return try? await taskQueue.enqueue(operation: {
            return await self.loadImage(url: url, imageKey: imageKey, imageTargetSize: imageTargetSize)
        })
    }
    
    private func loadImage(url: URL, imageKey: String, imageTargetSize: CGSize) async -> UIImage? {
        try? Task.checkCancellation()
        guard let linkMetadata = try? await LPMetadataProvider().startFetchingMetadata(for: url) else { return nil }
        
        let imageScalingTask: Task<UIImage?, Never> = Task.detached(priority: .background) {
            guard let image = await linkMetadata.imageProvider?.loadObject(ofClass: UIImage.self) as? UIImage else { return nil }
            let scaledImage = image.scalePreservingAspectRatio(targetSize: CGSize(width: 300, height: 300))
            let imageData = scaledImage.jpegData(compressionQuality: 1)?.base64EncodedString()
            DiskPersistor.save(value: imageData, for: imageKey)
            
            return scaledImage
        }
        
        return await imageScalingTask.value
    }
}

extension NSItemProvider {
    func loadObject(ofClass aClass: NSItemProviderReading.Type) async -> NSItemProviderReading? {
        await withCheckedContinuation { continuation in
            loadObject(ofClass: aClass) { (thing, error) in
                if error != nil { return continuation.resume(returning: nil) }
                return continuation.resume(returning: thing)
            }
        }
    }
}
