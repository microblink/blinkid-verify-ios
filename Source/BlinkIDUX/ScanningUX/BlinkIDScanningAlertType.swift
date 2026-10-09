//  Created by Toni Krešo on 24.02.2025..
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

/// Scanning alert type
public enum BlinkIDScanningAlertType: Int, Sendable, AlertTypeProtocol {
    public var id: Int { rawValue }
    
    /// Scanning session timed out.
    case timeout
    /// Class was filtered out with ClassFilter.
    case disallowedClass
    /// Scanned document currently not supported by the recognizer
    case unsupportedDocument
    case inactivityTimeout
    case unsupportedBarcodeTimeout
    
    
    public var title: String {
        switch self {
        case .timeout:
            return "mb_recognition_timeout_dialog_title".localizedString
        case .disallowedClass:
            return "mb_document_class_filtered_dialog_title".localizedString
        case .unsupportedDocument:
            return "mb_unsupported_document_title".localizedString
        case .inactivityTimeout:
            return "mb_recognition_timeout_dialog_title".localizedString
        case .unsupportedBarcodeTimeout:
            return "mb_recognition_timeout_dialog_title".localizedString
        }
    }
    
    public var description: String {
        switch self {
        case .timeout:
            return "mb_recognition_timeout_dialog_message".localizedString
        case .disallowedClass:
            return "mb_document_class_filtered_dialog_message".localizedString
        case .unsupportedDocument:
            return "mb_unsupported_document_message".localizedString
        case .inactivityTimeout:
            return "mb_recognition_timeout_dialog_message".localizedString
        case .unsupportedBarcodeTimeout:
            return "mb_recognition_timeout_dialog_message".localizedString
        }
    }
    
    public var buttonTitle: String {
        switch self {
        case .timeout, .disallowedClass, .unsupportedDocument, .inactivityTimeout, .unsupportedBarcodeTimeout:
            return "mb_recognition_timeout_dialog_retry_button".localizedString
        }
    }
    
    public var pingletAlertType: UxEventPinglet.AlertType {
        switch self {
        case .timeout:
            return .steptimeout
        case .disallowedClass:
            return .documentclassnotallowed
        case .unsupportedDocument:
            return .documentnotsupported
        case .inactivityTimeout:
            return .inactivitytimeout
        case .unsupportedBarcodeTimeout:
            return .unsupportedbarcodetimeout
        }
    }
}
