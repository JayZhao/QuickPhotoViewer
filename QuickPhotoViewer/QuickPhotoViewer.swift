//
//  QuickPhotoViewer.swift
//  QuickPhotoViewer
//
//  Created by 洪鑫 on 2017/3/15.
//  Copyright © 2017年 Teambition. All rights reserved.
//

import UIKit

public enum QuickPhotoViewerViewMode {
    case normal
    case fullScreen
}

public enum QuickPhotoViewerToolbarAnimation {
    case none
    case fade
    case slide
}

public enum QuickPhotoViewerPhotoTransitionAnimation {
    case `default`
    case dropDown
}

public class QuickPhotoViewer: UIViewController {
    public weak var dataSource: QuickPhotoViewerDataSource?
    public weak var delegate: QuickPhotoViewerDelegate?
    public weak var downloadDelegate: QuickPhotoViewerDownloadDelegate?

    public var photos = [QPhoto]() {
        didSet {
            if photos.isEmpty {
                dismiss(animated: true, completion: nil)
            } else {
                initialPageIndex = min(currentPageIndex, photos.count - 1)
                initPages()
            }
        }
    }
    public var initialPageIndex = 0
    public var topToolbar: UIView?
    public var bottomToolbar: UIView?
    public var toolbarUpdateAnimation: QuickPhotoViewerToolbarAnimation = .slide
    public var photoTransitionAnimation: QuickPhotoViewerPhotoTransitionAnimation = .dropDown
    public var transitioningSourceView: UIView?

    public fileprivate(set) var viewMode: QuickPhotoViewerViewMode = .normal
    public fileprivate(set) var currentPageIndex = 0
    public var currentPhoto: QPhoto? {
        guard !photos.isEmpty else {
            return nil
        }
        guard 0..<photos.count ~= currentPageIndex else {
            return nil
        }
        return photos[currentPageIndex]
    }
    public var viewControllers: [UIViewController]? {
        return pageViewController.viewControllers
    }

    internal var screenshot: UIImage?

    fileprivate lazy var pageViewController: UIPageViewController = self.makePageViewController()
    fileprivate lazy var topGradientLayer: CAGradientLayer = self.makeTopGradientLayer()
    fileprivate lazy var bottomGradientLayer: CAGradientLayer = self.makeBottomGradientLayer()
    fileprivate lazy var backgroundMaskView: UIView = self.makeBackgroundMaskView()

    fileprivate var topToolbarTop: NSLayoutConstraint?
    fileprivate var bottomToolbarBottom: NSLayoutConstraint?

    // MARK: - Life cycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureToolbars()
        initPages()
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        topGradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: Gradient.height))
        bottomGradientLayer.frame = CGRect(origin: CGPoint(x: 0, y: view.bounds.height - Gradient.height), size: CGSize(width: view.bounds.width, height: Gradient.height))
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if viewMode == .normal {
            topToolbar?.alpha = 1
            bottomToolbar?.alpha = 1
            topGradientLayer.opacity = 1
            bottomGradientLayer.opacity = 1
        }
    }

    // MARK: - Overriding
    public override var prefersStatusBarHidden: Bool {
        return true
    }

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        let transitioningDelegate = QuickPhotoViewerTransitioning(.dismiss(toView: transitioningSourceView))
        self.transitioningDelegate = transitioningDelegate
        prepareForDismiss()
        super.dismiss(animated: flag, completion: completion)
    }
}

extension QuickPhotoViewer {
    // MARK: - Public
    internal func setAlpha(_ alpha: CGFloat) {
        backgroundMaskView.alpha = alpha
        topToolbar?.alpha = alpha
        bottomToolbar?.alpha = alpha
        topGradientLayer.opacity = Float(alpha)
        bottomGradientLayer.opacity = Float(alpha)
    }
}

extension QuickPhotoViewer {
    // MARK: - Helpers
    fileprivate func setupUI() {
        if let screenshot = screenshot {
            view.backgroundColor = UIColor(patternImage: screenshot)
        }
        extendedLayoutIncludesOpaqueBars = true
        automaticallyAdjustsScrollViewInsets = false
        edgesForExtendedLayout = .top

        backgroundMaskView.alpha = 1
        view.insertSubview(backgroundMaskView, at: 0)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[backgroundMaskView]|", options: [], metrics: nil, views: ["backgroundMaskView": backgroundMaskView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[backgroundMaskView]|", options: [], metrics: nil, views: ["backgroundMaskView": backgroundMaskView]))

        pageViewController.dataSource = self
        pageViewController.delegate = self

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
    }

    fileprivate func configureToolbars() {
        if let topToolbar = topToolbar {
            topToolbar.alpha = 1
            topGradientLayer.opacity = 1

            topToolbar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(topToolbar)
            view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[topToolbar]|", options: [], metrics: nil, views: ["topToolbar": topToolbar]))
            topToolbarTop = NSLayoutConstraint(item: topToolbar, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1, constant: 0)
            view.addConstraint(topToolbarTop!)

            view.bringSubviewToFront(topToolbar)
            view.layer.insertSublayer(topGradientLayer, below: topToolbar.layer)
        }
        if let bottomToolbar = bottomToolbar {
            bottomToolbar.alpha = 1
            bottomGradientLayer.opacity = 1

            bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(bottomToolbar)
            view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[bottomToolbar]|", options: [], metrics: nil, views: ["bottomToolbar": bottomToolbar]))
            bottomToolbarBottom = NSLayoutConstraint(item: bottomToolbar, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1, constant: 0)
            view.addConstraint(bottomToolbarBottom!)

            view.bringSubviewToFront(bottomToolbar)
            view.layer.insertSublayer(bottomGradientLayer, below: bottomToolbar.layer)
        }
        switchViewMode(to: viewMode, with: .none)
    }

    fileprivate func initPages() {
        guard !photos.isEmpty else {
            return
        }
        if !(0..<photos.count ~= initialPageIndex) {
            initialPageIndex = 0
        }
        currentPageIndex = initialPageIndex
        let photoViewController = PhotoViewController()
        photoViewController.delegate = self
        photoViewController.downloadDelegate = self
        photoViewController.parentPhotoViewer = self
        photoViewController.photo = photos[currentPageIndex]
        photoViewController.pageIndex = currentPageIndex
        pageViewController.setViewControllers([photoViewController], direction: .forward, animated: false, completion: nil)
    }

    fileprivate func prepareForDismiss() {
        topToolbar?.alpha = 0
        bottomToolbar?.alpha = 0
    }

    fileprivate func switchViewMode(to newMode: QuickPhotoViewerViewMode, with animation: QuickPhotoViewerToolbarAnimation) {
        guard viewMode != newMode else {
            return
        }
        viewMode = newMode

        switch animation {
        case .none:
            switch newMode {
            case .normal:
                topToolbar?.alpha = 1
                bottomToolbar?.alpha = 1
                topGradientLayer.opacity = 1
                bottomGradientLayer.opacity = 1
            case .fullScreen:
                topToolbar?.alpha = 0
                bottomToolbar?.alpha = 0
                topGradientLayer.opacity = 0
                bottomGradientLayer.opacity = 0
            }
        case .fade:
            switch newMode {
            case .normal:
                UIView.animate(withDuration: 0.3, animations: {
                    self.topToolbar?.alpha = 1
                    self.bottomToolbar?.alpha = 1
                    self.topGradientLayer.opacity = 1
                    self.bottomGradientLayer.opacity = 1
                })
            case .fullScreen:
                UIView.animate(withDuration: 0.3, animations: {
                    self.topToolbar?.alpha = 0
                    self.bottomToolbar?.alpha = 0
                    self.topGradientLayer.opacity = 0
                    self.bottomGradientLayer.opacity = 0
                })
            }
        case .slide:
            switch newMode {
            case .normal:
                if let _ = topToolbar, let topToolbarTop = topToolbarTop {
                    topToolbarTop.constant = 0
                }
                if let _ = bottomToolbar, let bottomToolbarBottom = bottomToolbarBottom {
                    bottomToolbarBottom.constant = 0
                }
                UIView.animate(withDuration: 0.25, animations: {
                    self.topGradientLayer.opacity = 1
                    self.bottomGradientLayer.opacity = 1
                    self.view.layoutIfNeeded()
                })
            case .fullScreen:
                if let topToolbar = topToolbar, let topToolbarTop = topToolbarTop {
                    if UIScreen.main.bounds.height == 812 || UIScreen.main.bounds.height == 896 {
                        topToolbarTop.constant = -topToolbar.frame.height - 40
                    } else {
                        topToolbarTop.constant = -topToolbar.frame.height - 20
                    }
                }
                if let bottomToolbar = bottomToolbar, let bottomToolbarBottom = bottomToolbarBottom {
                    if UIScreen.main.bounds.height == 812 || UIScreen.main.bounds.height == 896 {
                        bottomToolbarBottom.constant = bottomToolbar.frame.height + 40
                    } else {
                        bottomToolbarBottom.constant = bottomToolbar.frame.height
                    }
                }
                UIView.animate(withDuration: 0.25, animations: {
                    self.topGradientLayer.opacity = 0
                    self.bottomGradientLayer.opacity = 0
                    self.view.layoutIfNeeded()
                })
            }
        }
    }

    // MARK: - Make functions
    fileprivate func makePageViewController() -> UIPageViewController {
        let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [UIPageViewController.OptionsKey.interPageSpacing: PhotoPreview.pageSpacing])
        return pageViewController
    }

    fileprivate func makeTopGradientLayer() -> CAGradientLayer {
        let topGradientLayer = CAGradientLayer()
        topGradientLayer.colors = [Gradient.startColor, Gradient.endColor]
        topGradientLayer.startPoint = Gradient.startPoint
        topGradientLayer.endPoint = Gradient.endPoint
        return topGradientLayer
    }

    fileprivate func makeBottomGradientLayer() -> CAGradientLayer {
        let bottomGradientLayer = CAGradientLayer()
        bottomGradientLayer.colors = [Gradient.endColor, Gradient.startColor]
        bottomGradientLayer.startPoint = Gradient.startPoint
        bottomGradientLayer.endPoint = Gradient.endPoint
        return bottomGradientLayer
    }

    fileprivate func makeBackgroundMaskView() -> UIView {
        let backgroundMaskView = UIView()
        backgroundMaskView.translatesAutoresizingMaskIntoConstraints = false
        backgroundMaskView.backgroundColor = .black
        return backgroundMaskView
    }
}

extension QuickPhotoViewer: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    // MARK: - UIPageViewControllerDataSource & UIPageViewControllerDelegate
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? PhotoViewController else {
            return nil
        }
        if currentViewController.pageIndex == 0 {
            return nil
        }
        let photoViewController = PhotoViewController()
        photoViewController.delegate = self
        photoViewController.downloadDelegate = self
        photoViewController.parentPhotoViewer = self
        photoViewController.photo = photos[currentViewController.pageIndex - 1]
        photoViewController.pageIndex = currentViewController.pageIndex - 1
        return photoViewController
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? PhotoViewController else {
            return nil
        }
        if currentViewController.pageIndex == photos.count - 1 {
            return nil
        }
        let photoViewController = PhotoViewController()
        photoViewController.delegate = self
        photoViewController.downloadDelegate = self
        photoViewController.parentPhotoViewer = self
        photoViewController.photo = photos[currentViewController.pageIndex + 1]
        photoViewController.pageIndex = currentViewController.pageIndex + 1
        return photoViewController
    }

    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let pendingViewController = pendingViewControllers.first as? PhotoViewController else {
            return
        }
        delegate?.photoViewer(self, willScrollToPageAt: pendingViewController.pageIndex)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            guard let currentViewController = pageViewController.viewControllers?.first as? PhotoViewController else {
                return
            }
            previousViewControllers.forEach {
                guard let previousViewController = $0 as? PhotoViewController else {
                    return
                }
                previousViewController.downloadDelegate = nil
            }
            currentPageIndex = currentViewController.pageIndex
            delegate?.photoViewer(self, didScrollToPageAt: currentPageIndex)
        }
    }
}

extension QuickPhotoViewer: PhotoViewControllerDelegate {
    // MARK: - PhotoViewControllerDelegate
    func photoViewControllerDidTapPhoto(_ controller: PhotoViewController) {
        switch viewMode {
        case .normal:
            switchViewMode(to: .fullScreen, with: toolbarUpdateAnimation)
        case .fullScreen:
            switchViewMode(to: .normal, with: toolbarUpdateAnimation)
        }
    }

    func photoViewController(_ controller: PhotoViewController, didDoubleTapPhotoAt point: CGPoint, in view: UIView) {
        controller.zoomPhotoToFit(from: point, in: view)
    }

    func photoViewControllerDidTapBackground(_ controller: PhotoViewController) {
        switch viewMode {
        case .normal:
            switchViewMode(to: .fullScreen, with: toolbarUpdateAnimation)
        case .fullScreen:
            switchViewMode(to: .normal, with: toolbarUpdateAnimation)
        }
    }

    func photoViewController(_ controller: PhotoViewController, didDoubleTapBackgroundAt point: CGPoint, in view: UIView) {
        controller.zoomPhotoToFit(from: point, in: view)
    }
}

extension QuickPhotoViewer: PhotoViewControllerDownloadDelegate {
    // MARK: - PhotoViewControllerDownloadDelegate
    func photoViewController(_ controller: PhotoViewController, willStartDownloading photo: QPhoto) {
        guard controller.pageIndex == currentPageIndex else {
            return
        }
        downloadDelegate?.photoViewer(self, willStartDownloading: photo)
    }

    func photoViewController(_ controller: PhotoViewController, isDownloading photo: QPhoto, with progress: QPhotoDownloadProgress) {
        guard controller.pageIndex == currentPageIndex else {
            return
        }
        downloadDelegate?.photoViewer(self, isDownloading: photo, with: progress)
    }

    func photoViewController(_ controller: PhotoViewController, didFinishDownloading photo: QPhoto) {
        guard controller.pageIndex == currentPageIndex else {
            return
        }
        downloadDelegate?.photoViewer(self, didFinishDownloading: photo)
    }
}
