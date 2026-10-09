//
//  PassportAnimatable.swift
//  DocumentVerificationUX
//
//  Shared passport animation logic for view models.
//

import SwiftUI

// MARK: - Passport Animation State
struct PassportAnimationState {
    var showAnimation: Bool = false
    var isAnimating: Bool = false
    var fromImage = Image.passportBottomImage
    var toImage = Image.passportTopImage
    var highlightImage = Image.passportHighlightImage
    var topImageOpacity: Double
    var bottomImageOpacity: Double
    var highlightOffset: CGFloat = 0
    var orientation: PassportOrientation? = nil
    var highlightDistance: CGFloat = 0

    let beginAlpha: Double = 0.4
    let endAlpha: Double = 1.0
    let animationDuration: Double = 2.0
    let relativeDuration: Double = 0.5

    var isDocumentPassport: Bool {
        orientation != nil
    }

    init() {
        self.topImageOpacity = beginAlpha
        self.bottomImageOpacity = endAlpha
    }

    mutating func reset() {
        topImageOpacity = beginAlpha
        bottomImageOpacity = endAlpha
        highlightOffset = 0
        orientation = nil
    }
}

// MARK: - Protocol
@MainActor
protocol PassportAnimatable: AnyObject {
    var passportState: PassportAnimationState { get set }

    // Required from ScanningViewModel base class
    var showSuccessImage: Bool { get set }
    var successImageScale: Double { get set }
    var successImageAnimationDuration: Double { get }
    var reticleStateMachine: ReticleStateMachine { get }

    func setReticleState(_ state: ReticleState, force: Bool)
    func pauseScanning()
    func resumeScanning()
    func resetStepTimer()
}

// MARK: - Default Implementations
extension PassportAnimatable {

    func passportSideScanned(_ orientation: PassportOrientation) {
        pauseScanning()

        let remainingTime = reticleStateMachine.calculateRemainingTime(stateDuration: 1.0)

        if remainingTime > 0 {
            Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task {
                    await self?.animateFirstSidePassportScanned(orientation)
                }
            }
        } else {
            Task {
                await animateFirstSidePassportScanned(orientation)
            }
        }
    }

    func passportWithBarcodeSideScanned() {
        pauseScanning()

        let remainingTime = reticleStateMachine.calculateRemainingTime(stateDuration: 1.0)

        if remainingTime > 0 {
            Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task {
                    await self?.animateFirstSidePassportWithBarcodeScanned()
                }
            }
        } else {
            Task {
                await animateFirstSidePassportWithBarcodeScanned()
            }
        }
    }

    func animateFirstSidePassportScanned(_ orientation: PassportOrientation) async {
        showSuccessImage = true
        setReticleState(.inactiveState, force: true)
        
        passportState.orientation = orientation

        withAnimation(.easeOutExpo(duration: successImageAnimationDuration)) {
            successImageScale = 1.0
        }

        try? await Task.sleep(for: .seconds(successImageAnimationDuration))

        withAnimation(.linear(duration: 0.2)) {
            showSuccessImage = false
        }

        try? await Task.sleep(for: .seconds(0.2))

        switch orientation {
        case .none:
            setReticleState(.inactiveWithMessage("mb_instructions_turn_page_top".localizedString), force: true)
        case .left90:
            setReticleState(.inactiveWithMessage("mb_instructions_turn_page_left".localizedString), force: true)
        case .right90:
            setReticleState(.inactiveWithMessage("mb_instructions_turn_page_right".localizedString), force: true)
        }
        
        passportState.showAnimation = true
        passportState.isAnimating = true

        try? await Task.sleep(for: .seconds(passportState.animationDuration * passportState.relativeDuration))

        withAnimation(.easeInOut(duration: passportState.animationDuration * passportState.relativeDuration)) {
            self.passportState.highlightOffset = self.passportState.highlightDistance
            self.passportState.topImageOpacity = self.passportState.endAlpha
            self.passportState.bottomImageOpacity = self.passportState.beginAlpha
        }

        try? await Task.sleep(for: .seconds(passportState.animationDuration * passportState.relativeDuration + 2.0))

        passportState.showAnimation = false

        resetStepTimer()
        resumeScanning()
        switch orientation {
        case .none:
            setReticleState(.passport("mb_top_page_instructions".localizedString), force: true)
        case .left90:
            setReticleState(.passport("mb_left_page_instructions".localizedString), force: true)
        case .right90:
            setReticleState(.passport("mb_right_page_instructions".localizedString), force: true)
        }
    }

    func animateFirstSidePassportWithBarcodeScanned() async {
        showSuccessImage = true
        setReticleState(.inactiveState, force: true)
        
        withAnimation(.easeOutExpo(duration: successImageAnimationDuration)) {
            successImageScale = 1.0
        }

        try? await Task.sleep(for: .seconds(successImageAnimationDuration))

        withAnimation(.linear(duration: 0.2)) {
            showSuccessImage = false
        }

        resetStepTimer()
        resumeScanning()
        setReticleState(.passport("mb_instructions_scan_barcode_last_page".localizedString), force: true)
    }
}
