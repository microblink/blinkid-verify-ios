//  Created by Toni Krešo on 25.02.2025..
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import BlinkIDVerify

/// Scanning alert type
public enum BlinkIDVerifyScanningAlertType: Int, Sendable, AlertTypeProtocol {
    public var id: Int { rawValue }
    
    /// Scanning session timed out.
    case timeout
    
    /// Scanned document currently not supported by the recognizer
    case unsupportedDocument
    
    /// Nothing on screen changed for the session's `inactivityTimeoutDuration`.
    case inactivityTimeout
    
    public var title: String {
        switch self {
        case .timeout, .inactivityTimeout:
            return "mb_recognition_timeout_dialog_title".localizedString
        case .unsupportedDocument:
            return "mb_unsupported_document_title".localizedString
        }
    }
    
    public var description: String {
        switch self {
        case .timeout, .inactivityTimeout:
            return "mb_recognition_timeout_dialog_message".localizedString
        case .unsupportedDocument:
            return "mb_unsupported_document_message".localizedString
        }
    }
    
    public var buttonTitle: String {
        switch self {
        case .timeout, .unsupportedDocument, .inactivityTimeout:
            return "mb_recognition_timeout_dialog_retry_button".localizedString
        }
    }
    
    public var pingletAlertType: UxEventPinglet.AlertType {
        switch self {
        case .timeout:
            return .steptimeout
        case .unsupportedDocument:
            return .documentnotsupported
        case .inactivityTimeout:
            return .inactivitytimeout
        }
    }
}
