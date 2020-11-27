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
    private var diffuse: CIImage
    private var depth: CIImage
    private var sigmaR: NSNumber
    private var sigmaS: NSNumber

    init(
        diffuse: CIImage,
        depth: CIImage,
        sigmaR: NSNumber = 15,
        sigmaS: NSNumber = 0.2
    ) {
        self.diffuse = diffuse
        self.depth = depth
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
                CISampler(image: diffuse),
                CISampler(image: depth),
                sigmaR,
                sigmaS
            ]
            return kernel.apply(
                extent: diffuse.extent,
                roiCallback: rangeOfInterestCallback,
                arguments: arguments
            )
        }
    }

    override var attributes: [String : Any] {
        [
            kCIAttributeFilterDisplayName: "Bilateral Filter",
            kCIAttributeFilterCategories: [
                kCICategoryDistortionEffect
            ],
            "diffuse": [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Diffuse Image",
                kCIAttributeType: kCIAttributeTypeImage
            ],
            "depth": [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Depth Image",
                kCIAttributeType: kCIAttributeTypeImage
            ],
            "sigmaR": [
                kCIAttributeClass: "NSNumber",
                kCIAttributeDisplayName: "Sigma R (Range)",
                kCIAttributeType: kCIAttributeTypeScalar
            ],
            "sigmaS": [
                kCIAttributeClass: "NSNumber",
                kCIAttributeDisplayName: "Sigma S (Spatial)",
                kCIAttributeType: kCIAttributeTypeScalar
            ],
        ]
    }
}
