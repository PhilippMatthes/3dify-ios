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

struct EstimationView: View {
    let inputImage: UIImage

    @State var results: [ProcessorResult]?
    @State var outputImage: UIImage?

    private enum Step: Int, Hashable {
        case inputImage
        case estimation
        case output
    }

    private var inputImageView: some View {
        VStack {
            CardView {
                Image(uiImage: inputImage)
                    .resizable()
                    .scaledToFit()
            }
            .padding(16)
            
            Text("Selected Photo")
            ProgressView()
        }
        .id(Step.inputImage)
    }

    private var estimationView: some View {
        VStack {
            if let results = results {
                ForEach(results) { result in
                    VStack {
                        CardView {
                            Image(uiImage: result.depthImage)
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(maxHeight: 128)
                        Text(result.description)
                            .frame(height: 32)
                    }
                }
            }
            ProgressView()
        }
        .id(Step.estimation)
    }

    private var outputImageView: some View {
        Group {
            if let outputImage = outputImage {
                VStack {
                    CardView {
                        Image(uiImage: outputImage)
                            .resizable()
                            .scaledToFit()
                    }
                    .padding()
                    Text("Final Depth Image")
                }
            } else {
                ProgressView()
            }
        }
        .id(Step.output)
    }

    private var scrollView : some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                ScrollViewReader { scrollViewProxy in
                    HStack(spacing: 24) {
                        inputImageView
                            .frame(width: geometry.size.width)
                        estimationView
                            .frame(width: geometry.size.width)
                        outputImageView
                            .frame(width: geometry.size.width)
                    }
                    .onAppear {
                        scrollViewProxy.scrollTo(Step.inputImage, anchor: .center)

                        let queue = DispatchQueue(label: "interactive", qos: .background)
                        queue.async {
                            try! EstimationPipeline(image: inputImage).estimate { newResults in
                                DispatchQueue.main.async {
                                    self.results = newResults
                                    withAnimation {
                                        scrollViewProxy.scrollTo(Step.estimation, anchor: .center)
                                    }
                                }
                            } completion: { result in
                                switch result {
                                case .success(let depthImage):
                                    DispatchQueue.main.async {
                                        self.outputImage = depthImage
                                        withAnimation {
                                            scrollViewProxy.scrollTo(Step.output, anchor: .center)
                                        }
                                    }
                                case .failure(let error):
                                    fatalError(error.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        VStack {
            Text("Estimation").font(.largeTitle)
                .padding()
            scrollView
        }
    }
}

struct EstimationView_Previews: PreviewProvider {
    static var previews: some View {
        EstimationView(inputImage: UIImage(named: "test_7")!)
    }
}
