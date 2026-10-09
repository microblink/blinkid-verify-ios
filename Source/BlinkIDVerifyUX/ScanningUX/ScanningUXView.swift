//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import SwiftUI
import BlinkIDVerify

/// Main scanning view.
/// This view consists of `CameraView` and `Reticle`.
///
/// For `UIEvent` stream, and UX logic, see ``ScanningUXModel``.
public struct ScanningUXView: View, ScanningUXProtocol, PassportAnimatableView {
    typealias GenericContentView = AnyView
    typealias ScanResult = BlinkIDVerifyCaptureResult
    typealias AlertType = BlinkIDVerifyScanningAlertType
    typealias UXModel = ScanningUXModel
    typealias EventType = UIEvent
    typealias ReticleStateMachineType = ReticleStateMachine

    // TODO: copied from BlinkID UX just to enable building, needs to be implemented properly
    var onboardingSteps: [any OnboardingStepProtocol] {
        return Array(FullDocumentOnboardingStep.allCases)
    }

    // TODO: copied from BlinkID UX just to enable building, needs to be implemented properly
    var onboardingAlert: OnboardingAlertContent {
        return OnboardingAlertContent(
            title: "mb_onboarding_dialog_title",
            description: "mb_onboarding_dialog_message",
            image: Image.allDetailsVisibleImage
        )
    }

    @ObservedObject var viewModel: ScanningUXModel
            
    let theme = BlinkIDVerifyTheme.shared
        
    public init(viewModel: ScanningUXModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        MainView(reticleStateMachine: viewModel.reticleStateMachine, isTorchOn: $viewModel.isTorchOn, showToast: $viewModel.isToastVisible, showSheet: $viewModel.showSheet, showLicenseErrorAlert: $viewModel.showLicenseErrorAlert, flashlightWarningMessage: "mb_flashlight_warning_message".localizedString)
            .onAppear { viewModel.presentConsentIfNeeded() }
            .sheet(isPresented: $viewModel.showConsent) {
                BlinkIDVerifyConsentView(
                    note: viewModel.consentNote,
                    onConsent: { optimizationConsent in
                        viewModel.consentGranted(optimizationConsent: optimizationConsent)
                    },
                    onDecline: {
                        viewModel.consentDeclined()
                    }
                )
                // Consent cannot be swiped away: dismissing it has to be an answer.
                .interactiveDismissDisabled()
            }
    }
}

// Override the ReticleView implementation in BlinkIDUXView, we have some custom things for BlinkID
extension ScanningUXView {
    @ViewBuilder
    func ReticleView(reticleStateMachine: ReticleStateMachineType) -> GenericContentView {
        AnyView(
            Group {
                VStack {
                    ZStack {
                        Reticle<ReticleStateMachineType>(diameter: Self.reticleDiameter, reticleStateMachine: reticleStateMachine)
                        if viewModel.showCardImage,
                           let cardImage = viewModel.cardImage {
                            cardImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .rotation3DEffect(.degrees(viewModel.flipCardDegrees), axis: (x: 0, y: 1, z: 0))
                                .scaleEffect(viewModel.flipCardScale)
                                .accessibilityHidden(true)
                        }
                        if viewModel.showRippleView {
                            Circle()
                                .fill(.white)
                                .frame(height: Self.reticleDiameter)
                                .scaleEffect(viewModel.rippleViewScale)
                                .opacity(viewModel.rippleViewOpacity)
                                .accessibilityHidden(true)
                        }
                        if viewModel.showSuccessImage {
                            viewModel.successImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: Self.reticleDiameter)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.black, .white)
                                .scaleEffect(viewModel.successImageScale)
                                .accessibilityHidden(true)
                        }
                        if viewModel.passportState.showAnimation {
                            if let orientation = viewModel.passportState.orientation {
                                switch orientation {
                                case .none:
                                    PassportAnimationView()
                                case .left90:
                                    PassportAnimationRotatedBy90LeftView()
                                case .right90:
                                    PassportAnimationRotatedBy90RightView()
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    
                    MessageContainer<ReticleStateMachineType>(theme: self.theme, stateMachine: viewModel.reticleStateMachine)
                }
            }
        )
    }
}
