//
//  BlinkIDUXTranslator.swift
//  DocumentVerificationUX
//
//  Created by Jura Skrlec on 19.02.2025..
//

#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

import UIKit

final class BlinkIDUXTranslator {
    
    private var backSideDispatched: Bool = false
    private var barcodeDispatched: Bool = false
    private var passportDispatched: Bool = false
    private var barcodeStepNeeded: Bool = false
    private var reticleLocked: Bool = false
    private var barcodeTimerTask: Task<Void, Never>?
    
    @ProcessingActor
    func translate(frameProcessResult: FrameProcessResult, session: BlinkIDSession) -> [UIEvent] {
        var events: [UIEvent] = []
        
        if session.getScanningStatus() == .sideScanned && (!backSideDispatched && !passportDispatched) {
            if let inputImageAnalysisResult = frameProcessResult.processResult?.inputImageAnalysisResult, inputImageAnalysisResult.documentClassInfo.documentType?.documentTypeId == .passport {
                passportDispatched = true
                if [CountryID.usa, CountryID.india].contains(inputImageAnalysisResult.documentClassInfo.country?.countryId) {
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
        
        if frameProcessResult.processResult?.inputImageAnalysisResult.processingStatus == .barcodeRecognitionFailed && !barcodeDispatched {
            
            reticleLocked = true
            barcodeDispatched = true
            
            events.append(.requestDocumentSide(side: .barcode))
            
            if frameProcessResult.processResult?.resultCompleteness.barcode?.parsingSupported == false && canResolveBarcode(session: session) {
                if barcodeTimerTask == nil {
                    startBarcodeScanTimer()
                    
                }
            }
        }
        
        if barcodeStepNeeded {
            barcodeStepNeeded = false
            events.append(.unparsableBarcode)
        }
        
        guard !reticleLocked else {
            return events
        }
        
        switch frameProcessResult.processResult?.inputImageAnalysisResult.processingStatus {
        case .unsupportedDocument:
            events.append(.unsupportedDocument)
        case .scanningWrongSide, .awaitingOtherSide:
            if passportDispatched, let inputImageAnalysisResult = frameProcessResult.processResult?.inputImageAnalysisResult {
                if [CountryID.usa, CountryID.india].contains(inputImageAnalysisResult.documentClassInfo.country?.countryId) {
                    events.append(.wrongSidePassportWithBarcode)
                } else {
                    events.append(.wrongSidePassport(passportOrientation: inputImageAnalysisResult.documentRotation.passportOrientation))
                }
            }
            else {
                events.append(.wrongSide)
            }
            
        case .imageReturnFailed:
            if let processResult = frameProcessResult.processResult {
                if processResult.inputImageAnalysisResult.imageExtractionFailures.contains(.face) {
                    events.append(.facePhotoNotFullyVisible)
                }
            }
        case .mandatoryFieldMissing, .invalidCharactersFound, .mrzParsingFailed:
            events.append(.notFullyVisible)
        case .barcodeDetectionFailed:
            events.append(.undetectedBarcode)
        default:
            break
        }
        
        switch frameProcessResult.processResult?.inputImageAnalysisResult.documentDetectionStatus {
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
        
        if frameProcessResult.processResult?.inputImageAnalysisResult.blurDetectionStatus == .detected && session.getResolvedSessionSettings().scanningSettings.documentCaptureModule?.imageWithBlurRejected == true {
            events.append(.blur)
        }
        if frameProcessResult.processResult?.inputImageAnalysisResult.glareDetectionStatus == .detected && session.getResolvedSessionSettings().scanningSettings.documentCaptureModule?.imageWithGlareRejected == true {
            events.append(.glare)
        }
        if frameProcessResult.processResult?.inputImageAnalysisResult.documentHandOcclusionStatus == .detected && session.getResolvedSessionSettings().scanningSettings.documentCaptureModule?.imageWithHandOcclusionRejected == true {
            events.append(.occlusion)
        }
        if frameProcessResult.processResult?.inputImageAnalysisResult.documentLightingStatus == .tooDark && session.getResolvedSessionSettings().scanningSettings.documentCaptureModule?.imageWithPoorLightingRejected == true {
            events.append(.tooDark)
        }
        if frameProcessResult.processResult?.inputImageAnalysisResult.documentLightingStatus == .tooBright && session.getResolvedSessionSettings().scanningSettings.documentCaptureModule?.imageWithPoorLightingRejected == true {
            events.append(.tooBright)
        }
        
        return events
    }
    
    func resetState() {
        passportDispatched = false
        backSideDispatched = false
        barcodeDispatched = false
        barcodeStepNeeded = false
        reticleLocked = false
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
    
    @ProcessingActor
    private func canResolveBarcode(session: BlinkIDSession) -> Bool {
        let settings = session.getResolvedSessionSettings().scanningSettings
        
        if settings.barcodeModule?.presenceMandatory == true {
            return false
        }
        
        if settings.documentCaptureModule == nil,
           settings.vizModule == nil,
           settings.mrzModule == nil,
           settings.barcodeModule != nil {
            return false
        }
        
        return true
    }
}

extension DocumentRotation {
    public var passportOrientation: PassportOrientation {
        let currentOrientation = UIDevice.current.orientation
        let isPortrait = currentOrientation.isPortrait || currentOrientation == .unknown
        let isFlat = currentOrientation.isFlat
        if isPortrait {
            if self == .zero {
                return PassportOrientation.right90
            }
            if self == .upsideDown {
                return PassportOrientation.left90
            }
        }
        else if isFlat {
            return PassportOrientation.none
        }
        else {
            if currentOrientation.isLandscape {
                if self == .zero {
                    return PassportOrientation.none
                }
                else if self == .clockwise90 {
                    if currentOrientation == .landscapeLeft {
                        return PassportOrientation.right90
                    }
                    else if currentOrientation == .landscapeRight {
                        return PassportOrientation.right90
                    }
                }
                else if self == .counterClockwise90 {
                    if currentOrientation == .landscapeLeft {
                        return PassportOrientation.left90
                    }
                    else if currentOrientation == .landscapeRight {
                        return PassportOrientation.right90
                    }
                }
                else if self == .upsideDown {
                    return PassportOrientation.none
                }
            }
        }

        return PassportOrientation.none
    }
}

