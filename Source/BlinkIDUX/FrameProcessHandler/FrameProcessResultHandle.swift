//
//  FrameProcessResultHandle.swift
//  BlinkIDUX
//
//  Created by Jura Skrlec on 05.03.2026..
//

import UIKit

#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

/// Delivered to the client on every processed camera frame via `onFrameProcessResult`,
/// and once when the hard step timeout fires.
///
/// Use `resultCompleteness` to inspect how much data has been extracted so far
/// and decide whether to advance the scanning session to the next step.
///
/// > Important: Do not use `BlinkIDScanningResult` for this decision.
/// > `ResultCompleteness` is lightweight, always available per frame, and describes
/// > extraction status and presence requirements without constructing a full result.
///
/// > Warning: This handle is delivered on the frame processing context, not on the main thread.
/// > Dispatch any UI work to `DispatchQueue.main` or `@MainActor` as needed.
public struct FrameProcessResultHandle: Sendable {

    /// Completeness of the extraction process for the current frame.
    ///
    /// Inspect `mrz`, `viz`, `barcode`, `faceImage`, and `documentImages` to determine
    /// what has been extracted and whether mandatory components are satisfied.
    ///
    /// `nil` when the handle is delivered as a timeout notification rather than a frame result.
    public let processResult: BlinkIDSDK.ProcessResult?

    /// Advances the scanning session to the next step by calling `resolveCurrentStep()` internally.
    ///
    /// Safe to call at any point during an active scanning step. No-op if the session
    /// is already complete or paused. No-op when called from a timeout notification handle —
    /// `scanInterrupted` will fire regardless.
    public let advanceToNextStep: @Sendable () async -> Void

    /// Returns the last processed camera frame.
    ///
    /// Intended for image collection use cases where recognition yields no usable result.
    /// Available on both per-frame and timeout notification handles.
    /// May return `nil` if no frame has been stored yet.
    public let getLastFrame: @Sendable () -> LastFrameResult?

    /// Called when the hard step timeout fires.
    ///
    /// This is a notification only — `scanInterrupted(with: .timeout)` always executes
    /// after this closure regardless of what the client does inside it. Use this to react
    /// to the timeout (e.g. collect the last frame, log state) before the session is interrupted.
    ///
    /// This closure is a no-op on per-frame handles. It is only meaningful on the
    /// handle delivered when the hard timeout fires.
    public let triggerStepTimeout: @Sendable () -> Void
}

/// Represents the last captured camera frame at the moment of delivery.
///
/// Delivered via `getLastFrame` on ``FrameProcessResultHandle``, either during active
/// frame processing or when the hard step timeout fires.
///
/// Intended for image collection use cases where recognition yields no usable result —
/// for example, capturing the last frame before a timeout to display to the user or
/// upload for manual review.
///
/// - Note: `image` may be `nil` if no frame has been processed yet at the time of delivery.
public struct LastFrameResult: Sendable {

    /// The last processed camera frame as a `UIImage`, or `nil` if no frame
    /// has been captured yet.
    public let image: UIImage?

    /// The video orientation of the camera at the time the frame was captured.
    ///
    /// Use this to correctly orient the image for display or upload, as `UIImage`
    /// does not automatically account for device rotation during camera capture.
    public let orientation: CameraFrameVideoOrientation

    init(image: UIImage?, orientation: CameraFrameVideoOrientation) {
        self.image = image
        self.orientation = orientation
    }
}
