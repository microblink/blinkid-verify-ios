// Created by Toni Krešo on 24.08.2026..
// Copyright (c) 2026 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS,
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED!
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI

public struct BlinkIDVerifyConsentView: View {
    static let optimizationConsentText = "mb_consent_privacy_switch".localizedString
    static let optimizationConsentOptional = " (" + "mb_optional".localizedString + ")"
    static var optimizationConsentAccessibilityLabel: String {
        optimizationConsentText + optimizationConsentOptional
    }
    
    static let defaultText = "mb_consent_description".localizedString
    
    let privacyNoticeURL = URL(string: "https://microblink.com/legal/privacy-notice-for-microblink-blinkid-verify/")!
    
    let onConsent: (Bool) -> Void
    let onDecline: () -> Void
    
    @State private var optimizationConsent = false
    @State private var webPage: WebPage?
    
    private let title: String = "mb_consent_title".localizedString
    private let text: String
    
    init(note: String? = nil,
         onConsent: @escaping (Bool) -> Void = { _ in },
         onDecline: @escaping () -> Void = {}) {
        self.text = [Self.defaultText, note]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        self.onConsent = onConsent
        self.onDecline = onDecline
    }
    
    private var infoText: AttributedString {
        let body = "mb_consent_privacy_notice".localizedString
        
        let linkKey = "mb_consent_privacy_link"
        let link = linkKey.localizedString
        
        var attributed = AttributedString(body)
        if let range = attributed.range(of: "{{\(linkKey)}}") {
            var linkAttributed = AttributedString(link)
            linkAttributed.link = privacyNoticeURL
            linkAttributed.underlineStyle = .single
            linkAttributed.foregroundColor = .accentColor
            attributed.replaceSubrange(range, with: linkAttributed)
        }
        
        return attributed
    }
    
    public var body: some View {
        VStack(spacing: 22) {
            // MARK: - Close
            HStack {
                Spacer()
                Button {
                    onDecline()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary)
                        .padding(18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("mb_close".localizedString)
            }
            
            // Scrolls only when the content does not fit, as with large text sizes.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .sheet(item: $webPage) { page in
            WebViewSheet(url: page.url, title: "mb_privacy_notice".localizedString)
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Title
            Text(title)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)
            
            // MARK: - Text
            Text(text)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 48)
            
            // MARK: - Info box
            Text(infoText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.top, 32)
            
            Divider()
                .overlay(.primary)
                .padding(.top, 32)
            
            Spacer(minLength: 24)
            
            // MARK: - Optional switch
            // The system Toggle puts its label first, so the switch is laid out
            // on the leading edge by hand. The control itself is still the
            // platform's, and it carries the accessibility label because the
            // visible copy beside it is hidden from assistive technologies.
            HStack(alignment: .top, spacing: 16) {
                Toggle(isOn: $optimizationConsent) { EmptyView() }
                    .labelsHidden()
                    .accessibilityLabel(Self.optimizationConsentAccessibilityLabel)
                
                Group {
                    Text(Self.optimizationConsentText)
                    + Text(Self.optimizationConsentOptional)
                        .italic()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            }
            
            // MARK: - Actions
            VStack(spacing: 12) {
                OutlineButton(title: "mb_consent_yes".localizedString) {
                    onConsent(optimizationConsent)
                }
                OutlineButton(title: "mb_consent_no".localizedString) {
                    onDecline()
                }
            }
            .padding(.top, 36)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color(.systemBackground))
        .environment(\.openURL, OpenURLAction { url in
            webPage = WebPage(url: url)
            return .handled
        })
    }
}

// MARK: - Bordered blue button
private struct OutlineButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.mbSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mbSecondary, lineWidth: 1)
                )
        }
    }
}
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

private struct WebViewSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            WebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.backward")
                                    .font(.system(size: 17, weight: .semibold))
                                    .accessibilityHidden(true)
                                Text("mb_dialog_back_button".localizedString)
                            }
                        }
                    }
                }
        }
    }
}

/// A link opened from the consent text. Wrapping the URL keeps the sheet's
/// `Identifiable` requirement inside the SDK instead of conforming `URL` itself.
private struct WebPage: Identifiable {
    let url: URL
    var id: URL { url }
}


#Preview {
    BlinkIDVerifyConsentView()
}
