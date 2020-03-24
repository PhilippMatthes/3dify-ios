//
//  ImagePickerViewController.swift
//  3Dify
//
//  Created by It's free real estate on 24.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import Photos


extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}


extension PHAsset {
    func getURL(completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
        if self.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            self.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
                completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
            })
        } else if self.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: self, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }
    
    func requestDepthImage(completion: @escaping (DepthImage?) -> Void) {
        
        self.getURL() {url in
            guard
                let url = url,
                let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                let disparityPixelBuffer = imageSource.getDisparityData()?.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32).depthDataMap
            else {
                completion(nil)
                return
            }
            
            disparityPixelBuffer.normalize()
            
            guard
                let depthMapImage = UIImage(pixelBuffer: disparityPixelBuffer),
                let depthCGImage = depthMapImage.cgImage,
                let image = UIImage(contentsOfFile: url.path),
                let rotatedDepthImage = UIImage(cgImage: depthCGImage, scale: 1.0, orientation: image.imageOrientation)
                    .rotate(radians: 0),
                let rotatedImage = image.rotate(radians: 0)
            else {
                completion(nil)
                return
            }
            
            completion(DepthImage(diffuse: rotatedImage, depth: rotatedDepthImage))
        }
    }
}


class ImageCell: UICollectionViewCell {
    public static let reuseIdentifier = "ImageCell"
    
    private let imageView = UIImageView()
    
    public var asset: PHAsset? {
        didSet {
            guard let asset = asset else {return}
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            option.isSynchronous = false
            manager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFit, options: option) { (result, info) -> Void in
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
    }
}


final class ImagePickerViewController: UIViewController {
    
    private let onPicked: ((DepthImage) -> ())
    
    private lazy var collectionView: UICollectionView = {
        let collectionViewFlowLayout = UICollectionViewFlowLayout()
        collectionViewFlowLayout.estimatedItemSize = .init(width: 100, height: 100)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewFlowLayout)
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = .init(top: 12, left: 12, bottom: 12, right: 12)
        return collectionView
    }()
    
    private var allPhotos : [PHAsset]? = nil {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    init(onPicked: @escaping ((DepthImage) -> ())) {
        self.onPicked = onPicked
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.frame = view.bounds
        view.addSubview(collectionView)
        
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                self.allPhotos = PHAsset.fetchAssetsWithDepth()
            case .denied, .restricted:
                print("Not allowed")
            case .notDetermined:
                print("Not determined yet")
            @unknown default:
                print("Unknown default")
            }
        }
    }
}


extension ImagePickerViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allPhotos?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseIdentifier, for: indexPath) as! ImageCell
        cell.asset = allPhotos?[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = allPhotos?[indexPath.row] else {return}
        
        asset.requestDepthImage() { depthImage in
            guard let depthImage = depthImage else {return}
            self.onPicked(depthImage)
        }
    }
}

struct ImagePickerViewControllerRepresenable: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ImagePickerViewController
    
    let onPicked: ((DepthImage) -> ())
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImagePickerViewControllerRepresenable>
    ) -> ImagePickerViewController {
        return ImagePickerViewController(onPicked: onPicked)
    }
    
    public func updateUIViewController(_ uiViewController: ImagePickerViewController, context: UIViewControllerRepresentableContext<ImagePickerViewControllerRepresenable>) {
        // Do nothing
    }
}
