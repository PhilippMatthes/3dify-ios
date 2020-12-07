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

import CoreImage

class SobelFilter: CIFilter {
    private var image: CIImage

    init(image: CIImage) {
        self.image = image
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var kernel: CIKernel = { () -> CIKernel in
        guard
            let filterPath = Bundle.main.path(
                forResource: "SobelFilter",
                ofType: "cikernel"
            ),
            let filterContents = try? String(contentsOfFile: filterPath),
            let kernel = CIKernel(source: filterContents)
        else { fatalError("Sobel Filter could not be built!") }
        return kernel
    }()

    override var outputImage: CIImage? {
        get {
            let rangeOfInterestCallback = { (index: Int32, rect: CGRect) -> CGRect in
                rect
            }
            let arguments = [
                CISampler(image: image),
            ]
            return kernel.apply(
                extent: image.extent,
                roiCallback: rangeOfInterestCallback,
                arguments: arguments
            )
        }
    }

    func outputCGImage(withContext context: CIContext) -> CGImage? {
        guard
            let outputImage = outputImage,
            let outputCGImage = context.createCGImage(
                outputImage, from: outputImage.extent
            )
        else { return nil }
        return outputCGImage
    }

    override var attributes: [String : Any] {
        [
            kCIAttributeFilterDisplayName: "Sobel Filter",
            kCIAttributeFilterCategories: [
                kCICategoryColorEffect
            ],
            "image": [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Image",
                kCIAttributeType: kCIAttributeTypeImage
            ],
        ]
    }
}
