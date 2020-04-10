//
//  CustomPhotoAlbum.swift
//  3Dify
//
//  Created by It's free real estate on 10.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import Photos
import UIKit

class CustomPhotoAlbum {
    
    enum CustomPhotoAlbumError: Error {
        case saveVideoFailed
        case savePhotoFailed
    }
    
    let assetCollection: PHAssetCollection
    
    private init(assetCollection: PHAssetCollection) {
        self.assetCollection = assetCollection
    }
    
    private static func fetchAssetCollectionForAlbum(
        withName albumName: String
    ) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions
        )
        return collection.firstObject
    }
    
    static func getOrCreate(
        albumWithName albumName: String,
        completion: @escaping (CustomPhotoAlbum?, Error?) -> ()
    ) {
        if let firstObject = fetchAssetCollectionForAlbum(withName: albumName) {
            completion(CustomPhotoAlbum(assetCollection: firstObject), nil)
            return
        }
        
        // Create photo album
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        }) { success, error in
            guard error == nil, success else {
                completion(nil, error)
                return
            }
            if let assetCollection = fetchAssetCollectionForAlbum(withName: albumName) {
                completion(CustomPhotoAlbum(assetCollection: assetCollection), nil)
                return
            } else {
                completion(nil, nil)
                return
            }
        }
    }
    
    func saveVideo(atUrl url: URL, completion: @escaping (Error?) -> ()) {
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            guard
                let assetPlaceholder = assetChangeRequest?.placeholderForCreatedAsset,
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection)
            else {
                completion(CustomPhotoAlbumError.saveVideoFailed)
                return
            }
            
            albumChangeRequest.addAssets([assetPlaceholder] as NSFastEnumeration)
        }) { saved, error in
            guard error == nil else {
                completion(error)
                return
            }
            if saved {
                completion(nil)
                return
            } else {
                completion(CustomPhotoAlbumError.saveVideoFailed)
                return
            }
        }
    }

    func save(image: UIImage, completion: @escaping (Error?) -> ()) {
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
           
            guard
                let assetPlaceholder = assetChangeRequest.placeholderForCreatedAsset,
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection)
            else {
                completion(CustomPhotoAlbumError.savePhotoFailed)
                return
            }
    
            albumChangeRequest.addAssets([assetPlaceholder] as NSFastEnumeration)
        }) { saved, error in
            guard error == nil else {
                completion(error)
                return
            }
            if saved {
                completion(nil)
                return
            } else {
                completion(CustomPhotoAlbumError.savePhotoFailed)
                return
            }
        }
    }


}
