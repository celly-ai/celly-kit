import CellyCore
import Foundation
import Photos
import UIKit

public final class PhotoLibraryWrapper {
    public typealias Completion = (Result<String, Error>) -> Void

    public enum Status {
        case authorized
        case permissionDenied
        case failed
    }

    public init() {}

    public func authorizatePhotoLibrary(
        completion: @escaping (Status) -> Void
    ) {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            completion(.authorized)
            return
        }

        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                completion(.authorized)
            default:
                completion(.permissionDenied)
            }
        }
    }

    public func save(
        outputURL: URL,
        name: String,
        _ completion: Completion?
    ) {
        // I. Request authorization
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion?(
                    .failure(
                        CellyError(
                            message: "Unable to save recording to photo library, Access denied"
                        )
                    )
                )
                return
            }
            // II.2 Save video
            do {
                try self.saveVideo(url: outputURL, fileName: name)
                completion?(.success(name))
            }
            catch {
                completion?(.failure(error))
            }
        }
    }

    public func save(
        image: CGImage,
        albumName: String,
        _ completion: Completion?
    ) {
        // I. Request authorization
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion?(
                    .failure(
                        CellyError(
                            message: "Unable to save recording to photo library, Access denied"
                        )
                    )
                )
                return
            }
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            let fetchResult = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .any, options: fetchOptions
            )
            guard let album: PHAssetCollection = fetchResult.firstObject else {
                // II.0 Create album collection
                self.createAlbum(albumName: albumName) { [weak self] result in
                    switch result {
                    case let .success(album):
                        // II.1 Save video in album collection‘
                        self?.savePhotoForAlbum(photo: image, album: album, completion)
                    case let .failure(error):
                        completion?(.failure(error))
                    }
                }
                return
            }

            // II.2 Save photo in album collection‘
            self.savePhotoForAlbum(photo: image, album: album, completion)
        }
    }

    public func images(identifiers: [String]) throws -> [(image: UIImage, localIdentifier: String)] {
        var error: CellyError?
        var images = [(image: UIImage, localIdentifier: String)]()
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true),
        ]
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: identifiers, options: fetchOptions
        )
        fetchResult.enumerateObjects { asset, _, stop in
            let imageRequestOptions = PHImageRequestOptions()
            imageRequestOptions.deliveryMode = .highQualityFormat
            imageRequestOptions.isSynchronous = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelWidth),
                contentMode: .aspectFit, options: imageRequestOptions
            ) { image, _ in
                guard let image = image else {
                    error = CellyError(
                        message: "Unable to find images from photo library"
                    )
                    return
                }
                images.append((image: image, localIdentifier: asset.localIdentifier))
            }
            if error != nil {
                stop.pointee = true
            }
        }
        if let error = error {
            throw error
        }
        return images
    }

    // MARK: Private

    private func createAlbum(
        albumName: String,
        _ completion: ((Result<PHAssetCollection, Error>) -> Void)?
    ) {
        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let assetRequest =
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                    withTitle: albumName
                )
            albumPlaceholder = assetRequest.placeholderForCreatedAssetCollection

        }) { success, error in
            // II.1 Process errors
            if let error = error {
                completion?(
                    .failure(
                        CellyError(
                            message:
                            "Failed to perfom change request: \(error.localizedDescription)"
                        )
                    )
                )
                return
            }
            guard success else {
                completion?(
                    .failure(CellyError(message: "Unable to perfom change request"))
                )
                return
            }

            guard let placeholder = albumPlaceholder else {
                completion?(.failure(CellyError(message: "Album placeholder is empty")))
                return
            }

            // II.2 Get album
            let fetchResult = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [placeholder.localIdentifier], options: nil
            )
            guard let album: PHAssetCollection = fetchResult.firstObject else {
                completion?(
                    .failure(CellyError(message: "Unable to get album after creation"))
                )
                return
            }
            completion?(.success(album))
        }
    }

    private func saveVideoOnAlbum(
        url: URL, album: PHAssetCollection, _ completion: Completion?
    ) {
        var localIdentifier: String?
        PHPhotoLibrary.shared().performChanges(
            {
                guard
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                else {
                    completion?(
                        .failure(
                            CellyError(message: "Unable to create album change request")
                        )
                    )
                    return
                }
                let createAssetRequest =
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                guard
                    let videoPlaceholder = createAssetRequest?.placeholderForCreatedAsset
                else {
                    completion?(
                        .failure(
                            CellyError(message: "Unable to get placeholder for asset request")
                        )
                    )
                    return
                }
                localIdentifier = videoPlaceholder.localIdentifier
                albumChangeRequest.addAssets([videoPlaceholder] as NSArray)
            },
            completionHandler: { success, error in
                if let error = error {
                    completion?(
                        .failure(
                            CellyError(
                                message:
                                "Failed to perfom change request: \(error.localizedDescription)"
                            )
                        )
                    )
                    return
                }
                guard let identifier = localIdentifier, success else {
                    completion?(
                        .failure(CellyError(message: "Unable to perfom change request"))
                    )
                    return
                }
                completion?(.success(identifier))
            }
        )
    }

    private func savePhotoForAlbum(
        photo: CGImage,
        album: PHAssetCollection,
        _ completion: Completion?
    ) {
        var localIdentifier: String?
        PHPhotoLibrary.shared().performChanges(
            {
                guard
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                else {
                    completion?(
                        .failure(
                            CellyError(message: "Unable to create album change request")
                        )
                    )
                    return
                }

                let createAssetRequest =
                    PHAssetChangeRequest.creationRequestForAsset(from: UIImage(cgImage: photo))
                guard
                    let placeholder = createAssetRequest.placeholderForCreatedAsset
                else {
                    completion?(
                        .failure(
                            CellyError(message: "Unable to get placeholder for asset request")
                        )
                    )
                    return
                }
                localIdentifier = placeholder.localIdentifier
                albumChangeRequest.addAssets([placeholder] as NSArray)
            },
            completionHandler: { success, error in
                if let error = error {
                    completion?(
                        .failure(
                            CellyError(
                                message:
                                "Failed to perfom change request: \(error.localizedDescription)"
                            )
                        )
                    )
                    return
                }
                guard let identifier = localIdentifier, success else {
                    completion?(
                        .failure(CellyError(message: "Unable to perfom change request"))
                    )
                    return
                }
                completion?(.success(identifier))
            }
        )
    }

    private func saveVideo(
        url: URL,
        fileName: String
    ) throws {
        try PHPhotoLibrary.shared().performChangesAndWait {
            let request = PHAssetCreationRequest.forAsset()
            let creationOptions = PHAssetResourceCreationOptions()
            creationOptions.originalFilename = fileName
            request.addResource(with: .video, fileURL: url, options: creationOptions)
        }
    }
}
