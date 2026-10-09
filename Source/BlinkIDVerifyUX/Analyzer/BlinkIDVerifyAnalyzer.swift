//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import Foundation
import BlinkIDVerify
import CoreImage
import UIKit

/// Manages the stream of UI events during document verification.
public actor BlinkIDVerifyEventStream: EventStream {
    private let events: AsyncStream<[UIEvent]>
    private let continuation: AsyncStream<[UIEvent]>.Continuation
    
    public init() {
        var continuation: AsyncStream<[UIEvent]>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }
    
    deinit {
        continuation.finish()
    }
    
    /// Sends UI events to the stream.
    /// - Parameter events: Array of UI events to be processed
    public func send(_ events: [UIEvent]) {
        continuation.yield(events)
    }
    
    /// The underlying async stream of UI events.
    public var stream: AsyncStream<[UIEvent]> {
        events
    }
}

/// How a scanning session obtains the end user's consent, which BlinkID Verify
/// Cloud requires with every verification request.
public enum BlinkIDVerifyConsentUxConfig: Sendable {
    /// You collected consent in your own UI. It is attached to the request as given.
    case provideExternalConsent(userId: String, durationDays: Int)

    /// The scanning screen asks for consent before analyzing any frame. `note`
    /// is shown on a new line below the sheet's text, and is sent as the
    /// consent's note.
    ///
    /// Only for ``ScanningUXModel``. With your own UI, collect consent there and
    /// use ``provideExternalConsent(userId:durationDays:)``.
    case setConsentWithUi(userId: String, durationDays: Int = 10, note: String? = nil)

    /// No consent is sent. Only for self-hosted deployments, which manage consent
    /// themselves: BlinkID Verify Cloud rejects a request without one.
    case noConsentNeeded

    /// The consent to send, or `nil` when there is none yet.
    ///
    /// - Parameter grantedAt: When the user granted consent in the scanning UI, or
    ///   `nil` if they have not. External consent needs no grant: when it was given
    ///   is unknown here, so it is left for the API to record on arrival.
    func consent(grantedAt: Date?) -> BlinkIDVerifyConsent? {
        switch self {
        case let .provideExternalConsent(userId, durationDays):
            return BlinkIDVerifyConsent(durationDays: Int32(clamping: durationDays), userId: userId)
        case let .setConsentWithUi(userId, durationDays, note):
            return grantedAt.map {
                BlinkIDVerifyConsent(durationDays: Int32(clamping: durationDays), userId: userId, note: note, givenOn: $0)
            }
        case .noConsentNeeded:
            return nil
        }
    }
}

/// Analyzes camera frames for document verification.
public actor BlinkIDVerifyAnalyzer: CameraFrameAnalyzer {
    
    public typealias Result = ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType>
    public typealias Frame = CameraFrame
    public typealias Event = UIEvent
    
    private let blinkIdVerifySession: BlinkIDVerifySession
    private let eventStream: BlinkIDVerifyEventStream
    private let translator: BlinkIDVerifyUXTranslator = BlinkIDVerifyUXTranslator()
    private var scanningDone = false
    private var paused = false
    private var resultContinuation: CheckedContinuation<Result, Never>?
    public private(set) var stepTimeoutDuration: TimeInterval
    public private(set) var inactivityTimeoutDuration: TimeInterval
    private var stepTimerTask: Task<Void, Never>?
    private var inactivityTimerTask: Task<Void, Never>?
    private var unsupportedDocumentTimerTask: Task<Void, Never>?

    private var stepTimerStartDate: Date?
    private var stepTimerInterval: TimeInterval?

    /// Last event batch sent to the stream; used to detect UI state changes.
    private var lastSentEvents: [UIEvent] = []

    /// Set once the session moves on to the barcode step. Only the step timer
    /// limits that step, as in BlinkID.
    private var scanningBarcode = false

    /// How consent is obtained for this session's verification request.
    nonisolated public let consentConfig: BlinkIDVerifyConsentUxConfig

    /// The consent the request is built with. Known from the start when it was
    /// collected externally; set when the user grants it in the scanning UI.
    private var consent: BlinkIDVerifyConsent?
    
    
    /// Creates a new document verification analyzer.
    /// - Parameters:
    ///   - sdk: The document verification SDK instance
    ///   - blinkIdVerifySessionSettings: Settings for the capture session
    ///   - consentConfig: How the end user's consent is obtained
    ///   - eventStream: Stream to receive UI events during scanning
    public init(
        sdk: BlinkIDVerifySdk,
        blinkIdVerifySessionSettings: BlinkIDVerifySessionSettings = BlinkIDVerifySessionSettings(),
        consentConfig: BlinkIDVerifyConsentUxConfig,
        eventStream: BlinkIDVerifyEventStream
    ) async throws {
        self.consentConfig = consentConfig
        self.consent = consentConfig.consent(grantedAt: nil)
        self.blinkIdVerifySession = try await sdk.createScanningSession(sessionSettings: blinkIdVerifySessionSettings)
        // Change this
        self._sessionNumber = await blinkIdVerifySession.getSessionNumber()
        self.eventStream = eventStream
        self.stepTimeoutDuration = blinkIdVerifySessionSettings.stepTimeoutDuration
        self.inactivityTimeoutDuration = blinkIdVerifySessionSettings.inactivityTimeoutDuration
    }
    
    private let _sessionNumber: Int
        
    nonisolated public var sessionNumber: Int {
        return _sessionNumber
    }
    
    /// Processes a camera frame for document analysis.
    /// - Parameter image: The camera frame to analyze
    public func analyze(image: Frame) async {
        guard !paused else { return }
        
        if stepTimerTask == nil {
            resumeStepTimer()
        }
        
        if inactivityTimerTask == nil {
            startInactivityTimer(inactivityTimeoutDuration)
        }
        
        let inputImage = InputImage(cameraFrame: image)
        
        do {
            let result = try await blinkIdVerifySession.process(inputImage: inputImage)
            
            let events = translator.translate(frameProcessResult: result)
            
            if events.contains(.unsupportedDocument) {
                startUnsupportedDocumentScanTimer()
            } else {
                unsupportedDocumentTimerTask?.cancel()
            }
            
            if events.contains(UIEvent.requestDocumentSide(side: .barcode)) {
                startStepTimer(stepTimeoutDuration)
                scanningBarcode = true
                cancelInactivityTimer()
                Task { @ProcessingActor in
                    blinkIdVerifySession.allowBarcodeStep()
                }
            }
            
            if events != lastSentEvents {
                lastSentEvents = events
                startInactivityTimer(inactivityTimeoutDuration)
            }
                    
            await eventStream.send(events)

            if result.processResult?.resultCompleteness.scanningStatus == .documentScanned {
                guard !scanningDone else { return }
                scanningDone = true
                let consent = self.consent
                Task { @ProcessingActor in
                    let sessionResult = blinkIdVerifySession.getResult(consent: consent)
                    await finishScanning(with: .completed(sessionResult))
                }
            }
        } catch {
            resultContinuation?.resume(returning: .cancelled)
        }
    }
    
    private func finishScanning(with result: ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType>) {
        cancelAllTimers()
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
    
    /// Records that the user granted consent in the scanning UI.
    ///
    /// Must be called before scanning starts: the request is built with whatever
    /// consent is recorded when the document finishes scanning.
    func consentGranted() {
        consent = consentConfig.consent(grantedAt: Date())
    }

    /// Cancels the current document scanning session.
    public func cancel() {
        self.blinkIdVerifySession.cancelActiveProcessing()
    }
    
    /// Returns the final result of the scanning session.
    public func result() async -> ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType>  {
        await withCheckedContinuation { continuation in
            self.resultContinuation = continuation
        }
    }
    
    /// Pauses the document analysis.
    public func pause() {
        self.paused = true
        self.cancel()
        freezeStepTimerRemaining()
        cancelAllTimers()
    }
    
    private func freezeStepTimerRemaining() {
        guard let startDate = stepTimerStartDate, let interval = stepTimerInterval else { return }
        stepTimerInterval = max(0, interval - Date().timeIntervalSince(startDate))
        stepTimerStartDate = nil
    }
    
    /// Resumes the document analysis after being paused.
    public func resume() {
        guard paused else { return }
        self.blinkIdVerifySession.resumeActiveProcessing()
        
        paused = false
    }
    
    /// Restarts the document analysis after being paused.
    public func restart() {
        Task { @ProcessingActor in
            try self.blinkIdVerifySession.reset()
        }
        translator.resetState()
        lastSentEvents = []
        scanningBarcode = false
        stepTimerStartDate = nil
        stepTimerInterval = nil
        self.resume()
    }
    
    public func resetStepTimer() {
        stepTimerTask?.cancel()
        stepTimerTask = nil
        stepTimerStartDate = nil
        stepTimerInterval = nil
        if !paused {
            startStepTimer(stepTimeoutDuration)
        }
    }
    
    /// Ends the current document scanning session.
    public func end() {
        pause()
        resultContinuation?.resume(returning: .ended)
        resultContinuation = nil
    }
    
    /// Stream of UI events generated during document analysis.
    nonisolated public var events: any EventStream<UIEvent> {
        eventStream
    }
    
    private func startStepTimer(_ interval: TimeInterval) {
        guard interval > 0.0 else { return }
        stepTimerTask?.cancel()
        stepTimerStartDate = Date()
        stepTimerInterval = interval
        stepTimerTask = Task() { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let nanoseconds = UInt64(interval * Double(NSEC_PER_SEC))
                try? await Task.sleep(nanoseconds: nanoseconds)
                if !Task.isCancelled {
                    await scanInterrupted(with: .timeout)
                }
            }
        }
    }
    
    private func resumeStepTimer() {
        guard stepTimerTask == nil else { return }
        if let interval = stepTimerInterval {
            stepTimerInterval = nil
            if interval <= 0 {
                scanInterrupted(with: .timeout)
            } else {
                startStepTimer(interval)
            }
        } else {
            startStepTimer(stepTimeoutDuration)
        }
    }
    
    private func cancelAllTimers() {
        stepTimerTask?.cancel()
        stepTimerTask = nil
        inactivityTimerTask?.cancel()
        inactivityTimerTask = nil
        unsupportedDocumentTimerTask?.cancel()
        unsupportedDocumentTimerTask = nil
    }
    
    /// Starts (or restarts) the inactivity timer.
    /// Must be called every time the UI state changes (i.e. a new distinct event batch).
    private func startInactivityTimer(_ interval: TimeInterval) {
        guard !paused, !scanningBarcode, interval > 0 else { return }
        inactivityTimerTask?.cancel()
        inactivityTimerTask = Task { [weak self] in
            guard let self else { return }
            let nanoseconds = UInt64(interval * Double(NSEC_PER_SEC))
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self.scanInterrupted(with: .inactivityTimeout)
        }
    }
    
    private func cancelInactivityTimer() {
        inactivityTimerTask?.cancel()
        inactivityTimerTask = nil
    }
    
    private func startUnsupportedDocumentScanTimer() {
        guard unsupportedDocumentTimerTask == nil ||
              unsupportedDocumentTimerTask?.isCancelled == true else { return }

        unsupportedDocumentTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
            if !Task.isCancelled {
                await self?.scanInterrupted(with: .unsupportedDocument)
            }
        }
    }
    
    private func scanInterrupted(with alertType: BlinkIDVerifyScanningAlertType) {
        pause()
        resultContinuation?.resume(returning: .interrupted(alertType))
        resultContinuation = nil
        
        Task {
            if alertType == .inactivityTimeout, sessionNumber > 0 {
                let pinglet = UxEventPinglet(eventType: .inactivitytimeout)
                await PingManager.shared.addPinglet(pinglet: pinglet, sessionNumber: sessionNumber)
            }
            await PingManager.shared.sendPinglets()
        }
    }
}
