//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - It's free real estate 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
// 

import UIKit

protocol SelectionImage: Equatable {
    var diffuseImage: UIImage { get }
    var depthImage: UIImage? { get }
}
