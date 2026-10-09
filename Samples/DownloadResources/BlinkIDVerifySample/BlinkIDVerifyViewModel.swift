// Created by Toni Krešo on 13.01.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION 
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS, 
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING 
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED! 
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT 
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI
import Combine
import BlinkIDVerify
import BlinkIDVerifyUX

enum UIState {
    case loading
    case home
    case scanBuiltin(ScanningUXModel)
    case scanCustom(CustomScanningViewModel)
    case error(String)
    case success(BlinkIDVerifyCaptureResult)
    case serverSuccess(BlinkIDVerifyEndpointResponse)
}

@MainActor
final class BlinkIDVerifyViewModel: ObservableObject {
    private let licenseKey = "sRwDAAEpY29tLm1pY3JvYmxpbmsuRG9jdW1lbnRWZXJpZmljYXRpb25TYW1wbGUBKWNvbS5taWNyb2JsaW5rLkRvY3VtZW50VmVyaWZpY2F0aW9uU2FtcGxl/cT+zgvB/gf4RsGVb+HRVHYAbkV3n5JR3POH8yYfTT6GLXytg33Nxj32++B7rWEhq+oMeCXl/tuqbjil3VrmfsnkU75RPmThZzj9bLA2iSa5S2m4xO0JROIhhaVc4OZQvLIyvGsVn/NNfWBtQF4="
    private var sdkInstance: BlinkIDVerifySdk?
    private var cancellables = Set<AnyCancellable>()
    @Published var state: UIState = .loading
    
    init() {
        Task {
            await initializeSdk()
        }
    }
    
    func initializeSdk() async {
        do {
            let settings = BlinkIDVerifySdkSettings(licenseKey: licenseKey)
            sdkInstance = try await BlinkIDVerifySdk.createBlinkIDVerifySdk(withSettings: settings)
        } catch {
            state = .error(error.localizedDescription)
        }
        state = .home
    }
    
    func performScan(customScan: Bool = false) async {
        guard let sdkInstance = sdkInstance
        else {
            state = .error("Failed to perform scan due to missing sdk")
            return
        }
        // The built-in UI asks for consent before scanning. A custom UI has to collect
        // it in its own screens and pass it on as external consent.
        let consentConfig: BlinkIDVerifyConsentUxConfig = customScan
            ? .provideExternalConsent(userId: "my_user_id", durationDays: 10)
            : .setConsentWithUi(userId: "my_user_id", durationDays: 10, note: nil)
        let analyzer = try? await BlinkIDVerifyAnalyzer(
            sdk: sdkInstance,
            blinkIdVerifySessionSettings: makeSessionSettings(),
            consentConfig: consentConfig,
            eventStream: BlinkIDVerifyEventStream()
        )
        if let analyzer = analyzer {
            if customScan {
                let scanningUxModel = CustomScanningViewModel(analyzer: analyzer)
                scanningUxModel.$captureResult
                    .sink { [weak self] captureResult in
                        if let captureResult = captureResult {
                            self?.state = .success(captureResult)
                        } else {
                            self?.state = .home
                        }
                    }
                    .store(in: &cancellables)
                state = .scanCustom(scanningUxModel)
            } else {
                let scanningUxModel = ScanningUXModel(analyzer: analyzer)
                scanningUxModel.$captureResult
                    .sink { [weak self] captureResultState in
                        if let captureResultState {
                            if let captureResult = captureResultState.captureResult {
                                self?.state = .success(captureResult)
                            }
                            else {
                                self?.state = .home
                            }
                        }
                    }
                    .store(in: &cancellables)
                
                state = .scanBuiltin(scanningUxModel)
            }
        }
    }
    
    /// The verification is configured when the session starts and travels in the captured payload.
    private func makeSessionSettings() -> BlinkIDVerifySessionSettings {
        var verificationSettings = VerificationSettings()
        verificationSettings.rejectExpiredDocuments = true
        verificationSettings.screenPresenceSensitivity = .level5
        verificationSettings.photocopySensitivity = .level5
        verificationSettings.barcodeAuthenticitySensitivity = .level4
        
        var scanningSettings = BlinkIDVerifySDK.ScanningSettings()
        scanningSettings.documentImageReturnEnabled = true
        scanningSettings.faceImageExtractionEnabled = true
        scanningSettings.verificationSettings = verificationSettings
        scanningSettings.useCase = VerificationUseCase(
            verificationPolicy: .highAssurance,
            verificationContext: .inPerson,
            manualReviewStrategy: .acceptedOnly
        )
        return BlinkIDVerifySessionSettings(scanningSettings: scanningSettings)
    }
    
    func processOnServer(result: BlinkIDVerifyCaptureResult) {
        guard let payload = result.payload else {
            state = .error("The scan produced nothing to verify")
            return
        }
        state = .loading
        let docVerSettings = BlinkIDVerifyServiceSettings(
            verificationServiceBaseUrl: "us-east.verify.microblink.com",
            accessClientId: "<insert_your_client_id_here>",
            accessClientSecret: "<insert_your_client_secret_here>"
        )
        let docVerService = BlinkIDVerifyService(settings: docVerSettings)
        
        Task {
            do {
                if let response = try await docVerService.verify(payload: payload) {
                    state = .serverSuccess(response)
                } else {
                    state = .home
                }
            }
            catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
