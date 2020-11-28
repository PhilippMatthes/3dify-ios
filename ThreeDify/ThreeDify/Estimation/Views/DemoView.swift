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

import SwiftUI
import Vision

struct DemoView: View {
    @State private var image = UIImage(named: "test_1")!

    private func runInference() {
        let context = CIContext()
        let model = try! VNCoreMLModel(for: FCRN().model)
        let cgImage = image.cgImage!

        var result: MLMultiArray?

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        let request = VNCoreMLRequest(model: model) { request, error in
            guard
                error == nil,
                let observations = request.results as? [VNCoreMLFeatureValueObservation],
                let value = observations.first?.featureValue.multiArrayValue
            else { fatalError() }
            result = value
            dispatchGroup.leave()
        }
        request.imageCropAndScaleOption = .scaleFill

        try! VNImageRequestHandler(
            cgImage: cgImage, options: [:]
        ).perform([request])

        dispatchGroup.wait()

        guard let array = result else { fatalError() }

        var minValue: Double = .greatestFiniteMagnitude
        var maxValue: Double = 0

        for i in 0 ..< 128 {
            for j in 0 ..< 160 {
                let index = i * 128 + j
                let value = array[index].doubleValue
                minValue = min(minValue, value)
                maxValue = max(maxValue, value)
            }
        }

        let depthCGImage = array.cgImage(min: maxValue, max: minValue)!

        let filter = BilateralFilter(
            diffuse: CIImage(cgImage: cgImage),
            depth: CIImage(cgImage: depthCGImage),
            sigmaR: 20,
            sigmaS: 0.05
        )
        let outputImage = filter.outputImage!
        let outputCGImage = context.createCGImage(
            outputImage, from: outputImage.extent
        )!

        image = UIImage(cgImage: outputCGImage)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .onAppear(perform: runInference)
    }
}

struct DemoView_Previews: PreviewProvider {
    static var previews: some View {
        DemoView()
    }
}
