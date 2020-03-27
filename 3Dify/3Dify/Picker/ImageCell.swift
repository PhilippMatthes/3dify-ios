//
//  ImageCell.swift
//  3Dify
//
//  Created by It's free real estate on 25.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit
import Photos


class ImageCell: UICollectionViewCell {
    public static let reuseIdentifier = "ImageCell"
    
    private let imageView = UIImageView()
    
    public var asset: PHAsset? {
        didSet {
            guard let asset = asset else {return}
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            option.isSynchronous = false
            manager.requestImage(for: asset, targetSize: CGSize(width: frame.width, height: frame.height), contentMode: .aspectFit, options: option) { (result, info) -> Void in
                DispatchQueue.main.async {
                    guard self.asset == asset else {return}
                    self.imageView.image = result
                }
            }
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    private func prepare() {
        contentView.addSubview(imageView)
        imageView.frame = contentView.bounds
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 4
    }
}
