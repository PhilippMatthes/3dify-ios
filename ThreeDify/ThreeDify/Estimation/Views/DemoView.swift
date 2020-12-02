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
    @State private var image = UIImage(named: "test_3")!

    private func runInference() {
        try! EstimationPipeline(image: image).estimate { result in
            switch result {
            case .success(let depthImage):
                self.image = depthImage
            case .failure(let error):
                fatalError(error.localizedDescription)
            }
        }
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .onAppear(perform: runInference)
            .edgesIgnoringSafeArea(.all)
    }
}

struct DemoView_Previews: PreviewProvider {
    static var previews: some View {
        DemoView().edgesIgnoringSafeArea(.all)
    }
}
