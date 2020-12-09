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

/// A reusable card view with a subtle shadow.
struct CardView<Content>: View where Content: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color("Background"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color("Shadow"), radius: 12, x: 0, y: 6)
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView {
            VStack(alignment: .leading) {
                Text("Card Title")
                    .font(.title)
                    .padding()
                Divider()
                Text("Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.")
                    .padding()
            }
        }
        .preferredColorScheme(.light)
        .padding()
    }
}
