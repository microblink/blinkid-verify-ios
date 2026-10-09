//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import AVFoundation
import Foundation
import CoreImage
import BlinkIDVerify
import Combine
import SwiftUI

#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

/// A view model that manages the user experience flow for document scanning.
/// Handles camera preview, document detection, user guidance, and scanning state transitions.
@MainActor
public final class ScanningUXModel: ScanningViewModel<BlinkIDVerifyCaptureResult, UIEvent, ReticleStateMachine, BlinkIDVerifyScanningAlertType>, PassportAnimatable {

    /// The result of the document verification capture process.
    /// Contains the captured document images and associated data.
    @Published public var captureResult: BlinkIDVerifyCaptureResultState?

    @Published var passportState = PassportAnimationState()
    
    /// Set when the model drives a ``BlinkIDVerifyAnalyzer``, the only analyzer that
    /// attaches consent to the request.
    private let verifyAnalyzer: BlinkIDVerifyAnalyzer?

    /// Supplied by the analyzer, which builds the request the consent goes into.
    private let consentUxConfig: BlinkIDVerifyConsentUxConfig

    /// Drives the consent sheet over the scanning screen. Only `setConsentWithUi`
    /// collects consent in the UI; the other contexts start scanning straight away.
    @Published var showConsent: Bool = false

    /// Set once the user has answered, so returning to the screen does not ask again.
    private var consentAnswered = false

    /// Title and body supplied with the consent context, when it carries one.
    /// `nil` means the consent view keeps its own default copy.
    var consentNote: String? {
        if case let .setConsentWithUi(_, _, note) = consentUxConfig {
            return note
        }
        return nil
    }

    private var consentNeededInUI: Bool {
        if case .setConsentWithUi = consentUxConfig {
            return true
        }
        return false
    }

    private var cancellables = Set<AnyCancellable>()

    public init(analyzer: any CameraFrameAnalyzer<CameraFrame, UIEvent>, uxSettings: ScanningUXSettings = ScanningUXSettings()) {
        let verifyAnalyzer = analyzer as? BlinkIDVerifyAnalyzer
        self.verifyAnalyzer = verifyAnalyzer
        self.consentUxConfig = verifyAnalyzer?.consentConfig ?? .noConsentNeeded
        super.init(analyzer: analyzer, uxSettings: uxSettings, reticleStateMachine: ReticleStateMachine(extractionMode: .fullDocument), firstSideFinishedText: "mb_accessibility_success_first_side_scanned".localizedString, scanFinishedText: "mb_accessibility_success_document_scanned".localizedString)
        startEventHandling()
        self.showConsent = consentNeededInUI
        camera.$status
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Protocol Implementation
    
    public override func processAnalyzerResult() async {
        let result = await analyzer.result()
        if let scanningResult = result as? ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType> {
            switch scanningResult {
            case .completed(let completedResult):
                await finishScan()
                captureResult = BlinkIDVerifyCaptureResultState(captureResult: completedResult)
            case .interrupted(let alertType):
                self.alertType = alertType
            case .cancelled:
                showLicenseErrorAlert = true
            case .ended:
                captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
            }
        }
    }
    
    // MARK: - Consent

    /// The scanning view starts the pipeline from its `.task` as soon as the camera
    /// is up. While consent is outstanding both entry points return early, so the
    /// preview runs but no frame reaches the analyzer. `resumeScanning` already
    /// refuses to run while a sheet is presented, so it needs no gate of its own.
    public override func startScanning() {
        guard !showConsent else { return }
        super.startScanning()
    }

    public override func presentAlert() {
        guard !showConsent else { return }
        super.presentAlert()
    }

    /// `showConsent` is already true before the view first lays out, which SwiftUI
    /// does not reliably turn into a presented sheet. Re-asserting it once the view
    /// has appeared makes the presentation dependable.
    func presentConsentIfNeeded() {
        guard consentNeededInUI, !consentAnswered else { return }
        showConsent = true
    }

    /// Resumes the flow the `.task` would have run had consent not been required.
    ///
    /// The consent is recorded on the analyzer first. Frames reach the analyzer only
    /// once scanning starts, so the request built when the document finishes
    /// scanning always carries it.
    func consentGranted(optimizationConsent: Bool) {
        // `optimizationConsent` is deliberately not sent: the product team decided the
        // optimization toggle is a no-op.
        consentAnswered = true
        showConsent = false
        Task {
            await verifyAnalyzer?.consentGranted()
            if uxSettings.showIntroductionAlert {
                presentAlert()
            } else {
                startScanning()
            }
        }
    }

    /// Declining ends the session without analyzing anything. No request is built,
    /// so there is nothing to tell the analyzer.
    func consentDeclined() {
        consentAnswered = true
        showConsent = false
        
        captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
    }

    public override func timeoutAlertDismised() {
        super.timeoutAlertDismised()
        passportState.reset()
    }
    
    // - MARK: - Handle UIEvents

    private func startEventHandling() {
        eventHandlingTask = Task {
            for await events in await analyzer.events.stream {
                if events.contains(.requestDocumentSide(side: .back)) {
                    firstSideScanned(frontFlipImage: Image.frontIdImage, backFlipImage: Image.backIdImage, flipState: .flip, nextState: .back)
                }
                else if events.contains(.requestDocumentSide(side: .passport(.none))) {
                    passportSideScanned(.none)
                }
                else if events.contains(.requestDocumentSide(side: .passport(.right90))) {
                    passportSideScanned(.right90)
                }
                else if events.contains(.requestDocumentSide(side: .passport(.left90))) {
                    passportSideScanned(.left90)
                }
                else if events.contains(.requestDocumentSide(side: .passportBarcode)) {
                    passportWithBarcodeSideScanned()
                }
                else if events.contains(.requestDocumentSide(side: .barcode)) {
                    self.setReticleState(.barcode, force: true)
                    startTooltipTimer()
                } else if events.contains(.unsupportedDocument) {
                    self.setReticleState(reticleStateMachine.fallbackState)
                } else if events.contains(.wrongSidePassportWithBarcode) {
                    self.setReticleState(.error("mb_instructions_scan_barcode_last_page"))
                    currentErrorMessage = .flipside
                } else if events.contains(.wrongSidePassport(passportOrientation: .left90)) {
                    self.setReticleState(.error("mb_scanning_wrong_page_left"))
                    currentErrorMessage = .flipside
                } else if events.contains(.wrongSidePassport(passportOrientation: .right90)) {
                    self.setReticleState(.error("mb_scanning_wrong_page_right"))
                    currentErrorMessage = .flipside
                } else if events.contains(.wrongSidePassport(passportOrientation: .none)) {
                    self.setReticleState(.error("mb_scanning_wrong_page_top"))
                    currentErrorMessage = .flipside
                } else if events.contains(.wrongSide) {
                    self.setReticleState(.error("mb_scanning_wrong_side"))
                    currentErrorMessage = .flipside
                } else if events.contains(.tilt) {
                    self.setReticleState(.error("mb_keep_document_parallel"))
                    currentErrorMessage = .aligndocument
                } else if events.contains(.tooClose) {
                    self.setReticleState(.error("mb_move_farther"))
                    currentErrorMessage = .movefarther
                } else if events.contains(.tooFar) {
                    self.setReticleState(.error("mb_move_closer"))
                    currentErrorMessage = .movecloser
                } else if events.contains(.tooCloseToEdge) {
                    self.setReticleState(.error("mb_move_farther"))
                    currentErrorMessage = .movefarther
                } else if events.contains(.screenDetected) {
                    self.setReticleState(.error("mb_screen_detected"))
                    currentErrorMessage = .keepvisible
                } else if events.contains(.glare) {
                    self.setReticleState(.error("mb_glare_detected"))
                    currentErrorMessage = .eliminateglare
                } else if events.contains(.occlusion) {
                    self.setReticleState(.error("mb_document_not_fully_visible"))
                    currentErrorMessage = .keepvisible
                } else if events.contains(.notFullyVisible) {
                    self.setReticleState(.error("mb_document_not_fully_visible"))
                    currentErrorMessage = .keepvisible
                } else if events.contains(.blur) {
                    self.setReticleState(.error("mb_blur_detected"))
                    currentErrorMessage = .eliminateblur
                } else {
                    self.setReticleState(reticleStateMachine.fallbackState)
                }
            }
        }
    }
}
