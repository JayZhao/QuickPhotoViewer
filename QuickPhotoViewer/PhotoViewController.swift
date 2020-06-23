//
//  PhotoViewController.swift
//  QuickPhotoViewer
//
//  Created by 洪鑫 on 2017/3/15.
//  Copyright © 2017年 Teambition. All rights reserved.
//

import UIKit
import Kingfisher

internal protocol PhotoViewControllerDelegate: class {
    func photoViewControllerDidTapPhoto(_ controller: PhotoViewController)
    func photoViewController(_ controller: PhotoViewController, didDoubleTapPhotoAt point: CGPoint, in view: UIView)
    func photoViewControllerDidTapBackground(_ controller: PhotoViewController)
    func photoViewController(_ controller: PhotoViewController, didDoubleTapBackgroundAt point: CGPoint, in view: UIView)
}

internal protocol PhotoViewControllerDownloadDelegate: class {
    func photoViewController(_ controller: PhotoViewController, willStartDownloading photo: QPhoto)
    func photoViewController(_ controller: PhotoViewController, isDownloading photo: QPhoto, with progress: QPhotoDownloadProgress)
    func photoViewController(_ controller: PhotoViewController, didFinishDownloading photo: QPhoto)
}

internal class PhotoViewController: UIViewController {
    internal weak var delegate: PhotoViewControllerDelegate?
    internal weak var downloadDelegate: PhotoViewControllerDownloadDelegate?
    internal weak var parentPhotoViewer: QuickPhotoViewer?
    internal var photo: QPhoto!
    internal var pageIndex = 0

    fileprivate(set) lazy var scrollView: UIScrollView = self.makeScrollView()
    fileprivate(set) lazy var imageView: UIImageView = self.makeImageView()

    fileprivate var imageViewLeading: NSLayoutConstraint!
    fileprivate var imageViewTrailing: NSLayoutConstraint!
    fileprivate var imageViewTop: NSLayoutConstraint!
    fileprivate var imageViewBottom: NSLayoutConstraint!

    fileprivate var panGestureRecognizer: UIPanGestureRecognizer!
    fileprivate var imageViewPanningStartRect: CGRect?

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestureRecognizers()
        loadPhoto()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        zoomImageViewToMinimum(animated: true)
        coordinator.animate(alongsideTransition: { (_) in
            self.updateScrollViewZoomScale()
            }) { (_) in

        }
    }

    // MARK: - Public
    internal func zoomPhotoToFit(from point: CGPoint, in view: UIView) {
        if scrollView.zoomScale == scrollView.minimumZoomScale {
            zoomImageViewToFit(from: view.convert(point, to: imageView))
        } else {
            zoomImageViewToMinimum(animated: true)
        }
    }
}

extension PhotoViewController {
    // MARK: - Helpers
    fileprivate func setupUI() {
        extendedLayoutIncludesOpaqueBars = true
        automaticallyAdjustsScrollViewInsets = false
        edgesForExtendedLayout = .top

        scrollView.delegate = self

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)

        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: [], metrics: nil, views: ["scrollView": scrollView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView]|", options: [], metrics: nil, views: ["scrollView": scrollView]))

        imageViewLeading = NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal, toItem: scrollView, attribute: .leading, multiplier: 1, constant: 0)
        imageViewTrailing = NSLayoutConstraint(item: scrollView, attribute: .trailing, relatedBy: .equal, toItem: imageView, attribute: .trailing, multiplier: 1, constant: 0)
        imageViewTop = NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1, constant: 0)
        imageViewBottom = NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: imageView, attribute: .bottom, multiplier: 1, constant: 0)
        scrollView.addConstraints([imageViewLeading, imageViewTrailing, imageViewTop, imageViewBottom])
    }

    fileprivate func setupGestureRecognizers() {
        imageView.isUserInteractionEnabled = true

        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        imageView.addGestureRecognizer(singleTapGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(imageDoubleTapped(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapGesture)

        singleTapGesture.require(toFail: doubleTapGesture)

        view.isUserInteractionEnabled = true

        let backgroundSingleTapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        backgroundSingleTapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(backgroundSingleTapGesture)

        let backgroundDoubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundDoubleTapped(_:)))
        backgroundDoubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(backgroundDoubleTapGesture)

        backgroundSingleTapGesture.require(toFail: backgroundDoubleTapGesture)

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(backgroundPanned(_:)))
        panGestureRecognizer.delegate = self
        scrollView.addGestureRecognizer(panGestureRecognizer)
    }

    fileprivate func loadPhoto() {
        photo.localImage { (localImage) in
            if let localImage = localImage {
                self.imageView.image = localImage
                self.updateScrollViewZoomScale()
            } else if let url = self.photo.url {
                self.downloadDelegate?.photoViewController(self, willStartDownloading: self.photo)
                let imageResource = ImageResource(downloadURL: url, cacheKey: url.cacheKey)
                self.photo.localThumbnailImage({ (localThumbnailImage) in
                    if let localThumbnailImage = localThumbnailImage {
                        self.imageView.image = localThumbnailImage
                        self.updateScrollViewZoomScale()
                    }
                    self.imageView.kf.setImage(with: imageResource,
                                               placeholder: localThumbnailImage,
                                               options: nil,
                                               progressBlock: { (downloadedCount, totalCount) in
                                                let progress = QPhotoDownloadProgress(downloadedCount: downloadedCount, totalCount: totalCount)
                                                self.downloadDelegate?.photoViewController(self, isDownloading: self.photo, with: progress)
                    }) { _ in
                        self.updateScrollViewZoomScale()
                        self.downloadDelegate?.photoViewController(self, didFinishDownloading: self.photo)
                    }
                })
            }
        }
    }

    // MARK: - Make functions
    fileprivate func makeScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.maximumZoomScale = PhotoPreview.maximumZoomScale
        scrollView.minimumZoomScale = PhotoPreview.minimumZoomScale
        return scrollView
    }

    fileprivate func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        return imageView
    }
}

extension PhotoViewController {
    // MARK: - Zooming
    fileprivate func updateScrollViewZoomScale() {
        guard let image = imageView.image, image.size.width > 0 && image.size.height > 0 else {
            return
        }

        let minimumZoomScale = min(view.bounds.width / image.size.width, view.bounds.height / image.size.height)
        scrollView.minimumZoomScale = minimumZoomScale

        let maximumZoomScale = max(max(view.bounds.width / image.size.width, view.bounds.height / image.size.height), PhotoPreview.maximumZoomScale)
        scrollView.maximumZoomScale = maximumZoomScale

        scrollView.zoomScale = minimumZoomScale
        zoomImageView()
    }

    fileprivate func zoomImageView() {
        guard let image = imageView.image else {
            return
        }
        let horizontalPadding = max((view.bounds.width - image.size.width * scrollView.zoomScale) / 2, 0)
        let verticalPadding = max((view.bounds.height - image.size.height * scrollView.zoomScale) / 2, 0)
        imageViewLeading.constant = horizontalPadding
        imageViewTrailing.constant = horizontalPadding
        imageViewTop.constant = verticalPadding
        imageViewBottom.constant = verticalPadding
        view.layoutIfNeeded()
    }

    fileprivate func zoomImageViewToFit(from point: CGPoint) {
        guard let image = imageView.image else {
            return
        }
        let minimumZoomScaleForFit: CGFloat = 2

        let scaleX = view.bounds.width / image.size.width
        let scaleY = view.bounds.height / image.size.height

        let scale: CGFloat = {
            if min(scaleX, scaleY) > 1 {
                return max(min(scaleX, scaleY), minimumZoomScaleForFit) * scrollView.minimumZoomScale
            } else {
                return max(max(scaleX, scaleY) / min(scaleX, scaleY), minimumZoomScaleForFit) * scrollView.minimumZoomScale
            }
        }()

        let newWidth = scrollView.bounds.width / scale
        let newHeight = scrollView.bounds.height / scale
        let newRect = CGRect(x: point.x - newWidth / 2, y: point.y - newHeight / 2, width: newWidth, height: newHeight)
        scrollView.zoom(to: newRect, animated: true)
    }

    fileprivate func zoomImageViewToMinimum(animated: Bool) {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
    }
}

extension PhotoViewController {
    // MARK: - Actions
    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
        delegate?.photoViewControllerDidTapPhoto(self)
    }

    @objc func imageDoubleTapped(_ sender: UITapGestureRecognizer) {
        delegate?.photoViewController(self, didDoubleTapPhotoAt: sender.location(in: imageView), in: imageView)
    }

    @objc func backgroundTapped(_ sender: UITapGestureRecognizer) {
        delegate?.photoViewControllerDidTapBackground(self)
    }

    @objc func backgroundDoubleTapped(_ sender: UITapGestureRecognizer) {
        delegate?.photoViewController(self, didDoubleTapBackgroundAt: sender.location(in: view), in: view)
    }

    @objc func backgroundPanned(_ sender: UIPanGestureRecognizer) {
        guard scrollView.zoomScale == scrollView.minimumZoomScale else {
            return
        }

        switch sender.state {
        case .began:
            imageViewPanningStartRect = imageView.frame
        case .changed:
            guard let startRect = imageViewPanningStartRect else {
                return
            }
            let translation = sender.translation(in: view)
            imageView.center = CGPoint(x: startRect.midX + translation.x, y: startRect.midY + translation.y)

            let scale = min(max(1 - translation.y / view.bounds.height, PhotoPanning.gestureMinimumZoomScale), 1)
            imageView.frame.size = CGSize(width: startRect.width * scale, height: startRect.height * scale)

            let alpha = min(max(1 - translation.y / (view.bounds.height / 2), PhotoPanning.gestureMinimumAlpha), 1)
            parentPhotoViewer?.setAlpha(alpha)
        default:
            let velocity = sender.velocity(in: view)
            let translation = sender.translation(in: view)

            if velocity.y > 0 && translation.y > 0 {
                imageViewPanningStartRect = nil
                parentPhotoViewer?.dismiss(animated: true, completion: nil)
            } else {
                UIView.animate(withDuration: 0.2,
                               delay: 0,
                               options: [.beginFromCurrentState, .curveEaseOut],
                               animations: {
                    if let imageViewPanningStartRect = self.imageViewPanningStartRect {
                        self.imageView.frame = imageViewPanningStartRect
                    }
                    self.parentPhotoViewer?.setAlpha(1)
                    }, completion: { (_) in
                        self.imageViewPanningStartRect = nil
                })
            }
        }
    }
}

extension PhotoViewController: UIGestureRecognizerDelegate {
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard scrollView.zoomScale == scrollView.minimumZoomScale else {
            return false
        }
        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer, gestureRecognizer == panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: view)

            let radian = atan(velocity.x / velocity.y)
            let angle = radian * 180 / .pi
            let triggerAngle = PhotoPanning.gestureMaximumTriggerAngle
            return -triggerAngle...triggerAngle ~= angle
        }
        return false
    }
}

extension PhotoViewController: UIScrollViewDelegate {
    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        zoomImageView()
    }
}
