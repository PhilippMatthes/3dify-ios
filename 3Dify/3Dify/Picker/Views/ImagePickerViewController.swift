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


final class ImagePickerViewController: UIViewController {
    
    private let onPicked: ((DepthImage) -> ())
    
    private let collectionViewFlowLayout = UICollectionViewFlowLayout()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewFlowLayout)
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .white
        collectionView.contentInset = .init(top: 12, left: 12, bottom: 128, right: 12)
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
        
        view.backgroundColor = .white
        collectionViewFlowLayout.estimatedItemSize = .init(width: (view.frame.width - 48) / 3, height: (view.frame.width - 48) / 3)
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
