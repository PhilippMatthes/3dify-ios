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

class FusionFilter: CIFilter {
    private var originalImageSobelImage: CIImage
    private var fcrnDepthImage: CIImage
    private var fcrnDepthSobelImage: CIImage
    private var pydnetDepthImage: CIImage
    private var pydnetDepthSobelImage: CIImage
    private var fastDepthDepthImage: CIImage
    private var fastDepthDepthSobelImage: CIImage

    init(
        originalImageSobelImage: CIImage,
        fcrnDepthImage: CIImage,
        fcrnDepthSobelImage: CIImage,
        pydnetDepthImage: CIImage,
        pydnetDepthSobelImage: CIImage,
        fastDepthDepthImage: CIImage,
        fastDepthDepthSobelImage: CIImage
    ) {
        self.originalImageSobelImage = originalImageSobelImage
        self.fcrnDepthImage = fcrnDepthImage
        self.fcrnDepthSobelImage = fcrnDepthSobelImage
        self.pydnetDepthImage = pydnetDepthImage
        self.pydnetDepthSobelImage = pydnetDepthSobelImage
        self.fastDepthDepthImage = fastDepthDepthImage
        self.fastDepthDepthSobelImage = fastDepthDepthSobelImage
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var kernel: CIKernel = { () -> CIKernel in
        guard
            let filterPath = Bundle.main.path(
                forResource: "FusionFilter",
                ofType: "cikernel"
            ),
            let filterContents = try? String(contentsOfFile: filterPath),
            let kernel = CIKernel(source: filterContents)
        else { fatalError("Fusion Filter could not be built!") }
        return kernel
    }()

    override var outputImage: CIImage? {
        get {
            let rangeOfInterestCallback = { (index: Int32, rect: CGRect) -> CGRect in
                rect
            }
            let arguments = [
                CISampler(image: originalImageSobelImage),
                CISampler(image: fcrnDepthImage),
                CISampler(image: fcrnDepthSobelImage),
                CISampler(image: pydnetDepthImage),
                CISampler(image: pydnetDepthSobelImage),
                CISampler(image: fastDepthDepthImage),
                CISampler(image: fastDepthDepthSobelImage),
            ]
            return kernel.apply(
                extent: originalImageSobelImage.extent,
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
}
