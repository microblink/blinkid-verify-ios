// Created by Toni Krešo on 13.01.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION 
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS, 
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING 
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED! 
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT 
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI
import BlinkIDVerify

struct VerificationResultView : View {
    @EnvironmentObject private var viewModel: BlinkIDVerifyViewModel
    private let verificationResult: BlinkIDVerifyEndpointResponse

    init(verificationResult: BlinkIDVerifyEndpointResponse) {
        self.verificationResult = verificationResult
    }

    var body : some View {
        VStack {
            HStack {
                Button {
                    viewModel.state = .home
                    
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                }
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 0, trailing: 0))
                
                Spacer()
            }
            ScrollView {
                VStack(
                    alignment: .center,
                    spacing: 10.0
                ) {
                    ForEach(returnedImages) { returned in
                        Text(returned.name)
                        Image(uiImage: returned.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    
                    ScrollView {
                        Text(verificationResult.description)
                    }
                    
                    Button("OK") {
                        viewModel.state = .home
                    }
                }
            }
        }
    }
    
    /// The images the API returned, decoded from base64.
    private var returnedImages: [ReturnedImage] {
        guard let images = verificationResult.images else { return [] }
        let all: [(String, String?)] = [
            ("First side", images.firstSideCropped),
            ("Second side", images.secondSideCropped),
            ("Face", images.face),
            ("Signature", images.signature),
            ("Barcode", images.barcode),
        ]
        return all.compactMap { name, base64 in
            guard let base64,
                  let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
                  let image = UIImage(data: data) else { return nil }
            return ReturnedImage(name: name, image: image)
        }
    }
}

private struct ReturnedImage: Identifiable {
    let name: String
    let image: UIImage
    var id: String { name }
}
