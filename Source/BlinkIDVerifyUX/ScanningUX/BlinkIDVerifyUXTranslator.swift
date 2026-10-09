//  Created by Toni Krešo on 13.11.2024..
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import BlinkIDVerify
import UIKit

final class BlinkIDVerifyUXTranslator {

    private var backSideDispatched: Bool = false
    private var barcodeDispatched: Bool = false
    private var passportDispatched: Bool = false
    private var barcodeStepNeeded: Bool = false
    private var reticleLocked: Bool = false
    private var barcodeTimerTask: Task<Void, Never>?

    func translate(frameProcessResult: BlinkIDVerifySDK.FrameProcessResult) -> [UIEvent] {
        var events: [UIEvent] = []

        if frameProcessResult.processResult?.resultCompleteness.scanningStatus == .scannedFirst && (!backSideDispatched && !passportDispatched) {
            if let inputImageAnalysisResult = frameProcessResult.processResult?.frameAnalysisResult.extractionInputImageAnalysisResult, inputImageAnalysisResult.documentClassInfo.documentType?.documentTypeId == .passport {
                passportDispatched = true
                if let countryId = inputImageAnalysisResult.documentClassInfo.country?.countryId,
                   [CountryID.usa, CountryID.india].contains(countryId) {
                    events.append(.requestDocumentSide(side: .passportBarcode))
                } else {
                    events.append(.requestDocumentSide(side: .passport(inputImageAnalysisResult.documentRotation.passportOrientation)))
                }

            }
            else {
                backSideDispatched = true
                events.append(.requestDocumentSide(side: .back))
            }
        }
        if frameProcessResult.processResult?.frameAnalysisResult.hasBarcodeReadingIssue == true && !barcodeDispatched {
            reticleLocked = true
            if barcodeTimerTask == nil {
                startBarcodeScanTimer()
            }
            if barcodeStepNeeded {
                barcodeDispatched = true
                events.append(.requestDocumentSide(side: .barcode))
            }
        }

        guard !reticleLocked else {
            return events
        }

        switch frameProcessResult.processResult?.frameAnalysisResult.extractionInputImageAnalysisResult.processingStatus {
        case .unsupportedDocument:
            events.append(.unsupportedDocument)
        case .scanningWrongSide, .awaitingOtherSide:
            if passportDispatched,
               let extractionInputImageAnalysisResult = frameProcessResult.processResult?.frameAnalysisResult.extractionInputImageAnalysisResult {
                if let countryId = extractionInputImageAnalysisResult.documentClassInfo.country?.countryId,
                   [CountryID.usa, CountryID.india].contains(countryId) {
                    events.append(.wrongSidePassportWithBarcode)
                } else {
                    events.append(.wrongSidePassport(passportOrientation: extractionInputImageAnalysisResult.documentRotation.passportOrientation))
                }
            } else {
                events.append(.wrongSide)
            }
        case .mandatoryFieldMissing, .invalidCharactersFound, .mrzParsingFailed:
            events.append(.notFullyVisible)
        default:
            break
        }

        switch frameProcessResult.processResult?.frameAnalysisResult.extractionInputImageAnalysisResult.detectionStatus {
        case .cameraTooFar:
            events.append(.tooFar)
        case .cameraTooClose:
            events.append(.tooClose)
        case .cameraAngleTooSteep:
            events.append(.tilt)
        case .documentTooCloseToCameraEdge:
            events.append(.tooCloseToEdge)
        case .documentPartiallyVisible:
            events.append(.notFullyVisible)
        default:
            break
        }

        if frameProcessResult.processResult?.frameAnalysisResult.blurDetected == true {
            events.append(.blur)
        }
        if frameProcessResult.processResult?.frameAnalysisResult.glareDetected == true {
            events.append(.glare)
        }
        if frameProcessResult.processResult?.frameAnalysisResult.screenPresenceDetected == true {
            events.append(.screenDetected)
        }
        if frameProcessResult.processResult?.frameAnalysisResult.occlusionDetected == true {
            events.append(.occlusion)
        }
        if frameProcessResult.processResult?.frameAnalysisResult.tiltDetected == true {
            events.append(.tilt)
        }
        return events
    }

    deinit {
        barcodeTimerTask?.cancel()
        barcodeTimerTask = nil
    }

    private func startBarcodeScanTimer() {
        barcodeTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(3.0 * 1_000_000_000))
            if !Task.isCancelled {
                self?.barcodeStepNeeded = true
            }
        }
    }

    func resetState() {
        backSideDispatched = false
        barcodeDispatched = false
        barcodeStepNeeded = false
        passportDispatched = false
        reticleLocked = false
        barcodeTimerTask?.cancel()
        barcodeTimerTask = nil
    }
}
