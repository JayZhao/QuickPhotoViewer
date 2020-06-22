//
//  QPhoto.swift
//  QuickPhotoViewer
//
//  Created by 洪鑫 on 2017/3/15.
//  Copyright © 2017年 Teambition. All rights reserved.
//

import UIKit
import Kingfisher

public struct QPhoto {
    public var image: UIImage?
    public var thumbnailImage: UIImage?
    public var url: URL?
    public var thumbnailUrl: URL?

    public init(image: UIImage, thumbnailImage: UIImage?) {
        self.image = image
        self.thumbnailImage = thumbnailImage
    }

    public init(url: URL, thumbnailUrl: URL?) {
        self.url = url
        self.thumbnailUrl = thumbnailUrl
    }
}

public extension QPhoto {
    func localImage(_ completionHandler: @escaping (UIImage?) -> Void) {
        if let image = image {
            completionHandler(image)
        } else if let url = url {
            if let retrieveImage = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: url.cacheKey) {
                completionHandler(retrieveImage)
            } else {
                KingfisherManager.shared.cache.retrieveImageInDiskCache(forKey: url.cacheKey) { (result) in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let value):
                            completionHandler(value)
                        case .failure:
                            completionHandler(nil)
                        }
                    }
                }
            }
        }
        completionHandler(nil)
    }

    func localThumbnailImage(_ completionHandler: @escaping (UIImage?) -> Void) {
        if let thumbnailImage = thumbnailImage {
            completionHandler(thumbnailImage)
        } else if let thumbnailUrl = thumbnailUrl {
            if let retrieveImage = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: thumbnailUrl.cacheKey) {
                completionHandler(retrieveImage)
            } else {
                KingfisherManager.shared.cache.retrieveImageInDiskCache(forKey: thumbnailUrl.cacheKey) { (result) in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let value):
                            completionHandler(value)
                        case .failure:
                            completionHandler(nil)
                        }
                    }
                }
            }
        }
        completionHandler(nil)
    }
}

public struct QPhotoDownloadProgress {
    public var downloadedCount: Int64
    public var totalCount: Int64

    public init(downloadedCount: Int64, totalCount: Int64) {
        self.downloadedCount = downloadedCount
        self.totalCount = totalCount
    }
}

internal extension URL {
    var cacheKey: String {
        var cacheKey = absoluteString
        if let query = query {
            cacheKey = cacheKey.replacingOccurrences(of: query, with: "")
        }
        return cacheKey
    }
}
