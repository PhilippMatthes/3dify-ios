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

class BilateralFilter: CIFilter {
    /// The source for the bilateral filtering.
    private var source: CIImage

    /// The target image to be blurred.
    private var target: CIImage

    private var sigmaR: NSNumber
    private var sigmaS: NSNumber

    init(
        source: CIImage,
        target: CIImage,
        sigmaR: NSNumber = 15,
        sigmaS: NSNumber = 0.2
    ) {
        self.source = source
        self.target = target
        self.sigmaR = sigmaR
        self.sigmaS = sigmaS
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var kernel: CIKernel = { () -> CIKernel in
        guard
            let filterPath = Bundle.main.path(
                forResource: "BilateralFilter",
                ofType: "cikernel"
            ),
            let filterContents = try? String(contentsOfFile: filterPath),
            let kernel = CIKernel(source: filterContents)
        else { fatalError("Bilateral Filter could not be built!") }
        return kernel
    }()

    override var outputImage: CIImage? {
        get {
            let rangeOfInterestCallback = { (index: Int32, rect: CGRect) -> CGRect in
                rect.insetBy(
                    dx: CGFloat(-self.sigmaR.floatValue),
                    dy: CGFloat(-self.sigmaR.floatValue)
                )
            }
            let arguments = [
                CISampler(image: source),
                CISampler(image: target),
                sigmaR,
                sigmaS
            ]
            return kernel.apply(
                extent: source.extent,
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
