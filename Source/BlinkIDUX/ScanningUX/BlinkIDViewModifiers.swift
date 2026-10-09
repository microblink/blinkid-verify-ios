//
//  BlinkIDViewModifiers.swift
//  BlinkIDUX
//
//  Created by Jura Skrlec on 09.03.2026..
//

import SwiftUI

// MARK: - Environment Keys

private struct UXSettingsKey: EnvironmentKey {
    static let defaultValue: ScanningUXSettings = ScanningUXSettings()
}

private struct FrameProcessResultCallbackKey: EnvironmentKey {
    static let defaultValue: (@Sendable (FrameProcessResultHandle) async -> Void)? = nil
}

extension EnvironmentValues {
    var uxSettings: ScanningUXSettings {
        get { self[UXSettingsKey.self] }
        set { self[UXSettingsKey.self] = newValue }
    }
    
    var frameProcessResultCallback: (@Sendable (FrameProcessResultHandle) async -> Void)? {
        get { self[FrameProcessResultCallbackKey.self] }
        set { self[FrameProcessResultCallbackKey.self] = newValue }
    }
}

// MARK: - View Modifiers

public extension View {
    func uxSettings(_ settings: ScanningUXSettings) -> some View {
        environment(\.uxSettings, settings)
    }
    
    func onFrameProcessResult(_ callback: @escaping @Sendable (FrameProcessResultHandle) async -> Void) -> some View {
        environment(\.frameProcessResultCallback, callback)
    }
}
