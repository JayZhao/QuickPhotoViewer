//
//  UIViewController+Extension.swift
//  QuickPhotoViewer
//
//  Created by 洪鑫 on 2017/3/16.
//  Copyright © 2017年 Teambition. All rights reserved.
//

import UIKit

public extension UIViewController {
    func present(_ photoViewer: QuickPhotoViewer,
                 from view: UIView,
                 animated flag: Bool = true,
                 completion: (() -> Void)? = nil) {
        let screenshot: UIImage? = {
            guard let layer = UIApplication.shared.keyWindow?.layer else {
                return nil
            }
            UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, UIScreen.main.scale)
            layer.render(in: UIGraphicsGetCurrentContext()!)
            let screenshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return screenshot
        }()
        photoViewer.screenshot = screenshot
        let transitioningDelegate = QuickPhotoViewerTransitioning(.present(fromView: view))
        photoViewer.transitioningDelegate = transitioningDelegate
        present(photoViewer, animated: flag, completion: completion)
    }
}
