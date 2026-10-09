# Release notes

## 4000.0.0

### What's new
- Update to BlinkID v8002.0.0 for document capturing and extraction
- New Injection Attack Check: Added sdkPayloadIntegrityCheck for multipart SDK payloads, validating signed images and request fields and returning Reject when tampering is detected during API processing.
- Capture resolver: When a document is successfully captured, a resolver is provided. That resolver can submit the verification request, and it can also return a v3-compliant payload for manual submission. 
Previously, a result was provided on capture completion as images to be sent to the API. 
- Facilitated API submission: The captured frame can be submitted immediately by the SDK when scanning finishes, or submitted later through the resolver. Requests are sent to `{base_url}/api/v3/verify`. The page origin is used when no base URL is set. The receiving server forwards the body unchanged and adds the API key in the `Authorization` header.
Note: A failed automatic submit is not retried. The same resolver can be used to resubmit while the session is still active.
- Improved capture feedback: Each processed frame reports the document side and whether the background is interfering with verification. The warning shown by the feedback UI is “Move the document to a plain background”.
- Most up to date document coverage: The full list of newly supported documents can be found here, below the release notes for October 2026: https://docs.microblink.com/blinkid/release-notes
- The capture pipeline is replaced with the v3 session, consent, and Verify API flow. Setup, capture, and submit are covered by a single component.
Note, more information on the v3 API can be found here: https://docs.microblink.com/verify/migrate-v3 
### 1. Verification setup
Session settings accept a `configuration` object in the same shape as the v3 API. The configuration covers the verification policy, sensitivity thresholds, image-quality handling, extraction, and redaction.
### 2. Consent and Consent UI
From the roll out of the v3 API, explicit end-user consent is required for verifications prior to capture. Three options are provided, in all cases, when that dialog is declined, the SDK is terminated.
a. The built-in consent dialog can be shown. 
b. The built-in consent dialog can be customised. 
c. When consent has already been gathered before Verify is started, a consent object can be supplied before capture and the consent dialog is skipped.
More information on Consent Management can be found here: https://docs.microblink.com/verify/consent 
## Bugfixes & Improvements
- Updated additional number format checks for Western Australia driver licenses.
- Resolved false rejection issue with Philippine eIDs, now both digital and physical versions are accepted.
- Added new date formats for Irish passports and passport cards.
- Removed documentNumber logic check for AUSTRIA//DL/2006 which was causing false rejections.
- Fixed an issue where extraction processingStatus was returning incorrect values for certain multi-side documents.
- Fixed an issue where barcode ExtractionResult was returned for certain documents without barcode.
- Fixed a validation issue for dateOfIssue on Ireland rigid passports, and dateOfBirth and dateOfExpiry on Ireland residence permits.
- Fixed an issue where barcode read checks for Tennessee 2018 and North Carolina 2008 Under 21 driver licenses was previously returning NotPerformed.
- Fixed an issue where NONE would sometimes appear as part of the firstName extraction result.
- Fixed issues with document number formats for Wyoming DLs and Indonesia passports.
- Fixed issue with date formats for Brazil IDs.
- Fixed issue with barcode authenticity checks for Ontario DLs.

### How the v3 flow works on iOS
- Capture resolver: when a document is captured, `BlinkIDVerifyAnalyzer` returns a `BlinkIDVerifyCaptureResult` whose `payload` is the v3-compliant request. Send it with `BlinkIDVerifyService.verify(payload:)`, or submit it to the API yourself.
- API submission: the iOS SDK never submits automatically; your app calls `verify(payload:)`, which sends the request to `https://{verificationServiceBaseUrl}/api/v3/verify`. `BlinkIDVerifyServiceSettings` authenticates with your client ID and secret, or with an `Authorization` header value you provide, for example from your own backend. It can also send no credentials, for self-hosted deployments.
- Capture feedback: each frame's `resultCompleteness.scanningStatus` reports the side being scanned, and `frameAnalysisResult.screenPresenceDetected` drives the "Move the document to a plain background" warning.
- Verification setup: `BlinkIDVerifySessionSettings.scanningSettings` carries the v3 configuration as typed properties:
  - `useCase`: verification policy, verification context and manual review strategy
  - `verificationSettings`: sensitivity thresholds, image-quality retry policy, expired-document rejection and crop handling
  - `imageQualitySensitivity` and `redactionMode`
  - which images to return: face, cropped document, signature and barcode
- Consent: pass a `BlinkIDVerifyConsentUxConfig` as `BlinkIDVerifyAnalyzer`'s `consentConfig`:
  - `.setConsentWithUi(userId:durationDays:note:)` shows the built-in consent screen; `note` adds your text below the default text, and its strings can be overridden through `BlinkIDVerifyTheme.shared.localizationBundle`
  - `.provideExternalConsent(userId:durationDays:)` skips the screen when consent was gathered before Verify starts
  - `.noConsentNeeded` sends no consent, for self-hosted deployments only
  - declining the consent screen ends scanning without a result

### Breaking API changes
- Removed `BlinkIDVerifyRequest`, `BlinkIDVerifyRequestSettings` and `BlinkIDVerifyCaptureResult.toBlinkIDVerifyRequest(requestSettings:)`
- `BlinkIDVerifyService.verify(payload:)` replaces `verify(blinkIdVerifyRequest:)`
- `BlinkIDVerifySDK.ScanningSettings`:
  - removed `treatExpirationAsFraud`, `screenAnalysisMatchLevel`, `staticSecurityFeaturesMatchLevel`, `barcodeAnomalyMatchLevel`, `dataMatchMatchLevel` and `imageQualitySettings`
  - `useCase` is now a `VerificationUseCase`
  - added `verificationSettings`, `imageQualitySensitivity`, `redactionMode`, `faceImageExtractionEnabled`, `documentImageReturnEnabled`, `signatureImageExtractionEnabled` and `barcodeImageReturnEnabled`
- The response models follow the v3 API; v2 types such as `VerifyResult`, `VerifyCheck`, `MatchLevel`, `CertaintyLevel`, `BlinkIDVerifySDK.StringResult`, `BlinkIDVerifySDK.DateResult` and `BlinkIDVerifySDK.VerifyClassInfo` are removed
- `BlinkIDVerifyCaptureResult`: removed `orientation`, added `captureSessionId` and `payload`
- `BlinkIDVerifyServiceSettings`:
  - removed `mbClientSdkName`, `mbClientSdkVersion` and `mbRunnerVersion`; the payload now carries the SDK metadata
  - `init(verificationServiceBaseUrl:accessClientId:accessClientSecret:)` authenticates with BlinkID Verify Cloud
  - `init(verificationServiceBaseUrl:token:)` sends `token` as the `Authorization` header, scheme included
  - `init(verificationServiceBaseUrl:)` sends no credentials, for self-hosted deployments
- `RequestError` is no longer `Int`-backed; added `validation(BlinkIDVerifyValidationError)`, `requestTooLarge`, `rateLimited(retryAfter:)` and `decodingFailed(String)`
- `BlinkIDVerifySdkSettings`: the resource options moved to `resourcesConfiguration: ResourcesConfig`
  - `downloadResources` → `download`
  - `resourceDownloadUrl` → `serviceUrl`
  - `resourceLocalFolder` → `localFolder`
  - `resourceRequestTimeout` → `requestTimeout`
  - `bundleURL` → `bundleUrl`
- `BlinkIDVerifyAnalyzer.init` now requires `consentConfig: BlinkIDVerifyConsentUxConfig`
- Custom `CameraFrameAnalyzer` implementations must add `resetStepTimer()` and `inactivityTimeoutDuration`
- `CountryID.virginIslandsBritish` is renamed to `.britishVirginIslands`
- The SDK no longer makes `URL` conform to `Identifiable`; declare the conformance in your app if you relied on it

### New API
- `BlinkIDVerifySessionSettings.traceId` is sent with the request and returned in `RuntimeInformation.traceId`
- `BlinkIDVerifySessionSettings.inactivityTimeoutDuration` (default 10 s, 0 or less disables it) interrupts scanning with the new `BlinkIDVerifyScanningAlertType.inactivityTimeout` when nothing on screen changes
- Localization:
  - `BlinkIDVerifyTheme.shared.localizationBundle` and `localizationTableName` override individual built-in strings
  - `BlinkIDVerifyTheme.shared.language` forces the UI language; right-to-left languages also flip the layout
- `ScanningUXSettings`: added `allowScanSound`, `helpTooltipShowDelay` (default 10 s) and `helpTooltipHideDelay` (default 5 s)

### Behavior changes
- Default `stepTimeoutDuration` raised from 15 s to 60 s
- The step timer continues from where it stopped after a pause, such as the help screen, instead of restarting; a new side or returning to the app starts a full step

### Bugfixes & Improvements
- Consent screen accessibility: VoiceOver labels and heading, Dynamic Type with scrolling, localized privacy notice title and back button
- HTTP 401 responses, for example for an `Authorization` header without its `Basic ` prefix, now return `RequestError.unauthorized` instead of `.unknown`
- Added `FieldType` cases `vehicleNumber`, `passportNumber`, `trafficParticipantNumber`, `ethnicity` and `parentFullName`

## 3.21.1

- Added support for setting a custom localization bundle and switching the in-app language at runtime

## 3.21.0

### What's New
- Update to BlinkID v7.8 for document capturing and extraction

## 3.20.0

### What's New
- Update to BlinkID v7.7 for document capturing and extraction

### Minor API changes
- added new settings to `ScanningSettings`:
  - `scanPassportDataPageOnly` - when enabled, only the passport data page (containing `MRZ`) is scanned; when disabled, scanning of the second page is required for certain passports
  - `scanUnsupportedBack` - when enabled, the back side of documents whose back side is not supported will also be scanned
- added new properties to `BlinkIDVerifyRequestSettings`:
  - `photocopyMatchLevel`
  - `photoForgeryMatchLevel`
  - `generativeAiMatchLevel`
- added new properties to `ExtractionFrameAnalysisResult`:
  - `documentClassInfo`
  - `documentOrientation`
  - `documentRotation`

### Improvements and bug fixes
- Added custom passport animations - users are now guided with tailored animations when scanning passports, improving the scanning experience for passport documents
- Refactored and extracted the reticle state into a dedicated state machine for cleaner separation and easier customization
- Added a "document not supported" alert - when an unsupported document is detected during scanning, the user is now clearly notified via an alert
- UI localization coverage has been expanded with additional languages
- Other miscellaneous improvements

## 3.14.0

### What's New
- Update to BlinkID v7.4 for document capturing and extraction
- Improved document coverage globally with new document version support and new document types
- Improved data extraction accuracy for Quebec and Ontario Healthcare cards

### Bugfixes
- Fixed document number extraction from Canada/Nunavut barcodes
- Fixed core data concurrency crash when using com.apple.CoreData.ConcurrencyDebug flag

#### Platform API changes
- Complete scanning instruction messages revamp - the scanning session is now more stable and cleaner, which ensures a better scanning experience
- Added "Demo" overlay for the demo licenses (non-production)
- Added "Powered by Microblink" overlay option for licenses with this enabled
- Added a separate timeout timer for the Barcode step
- Updated help screens with new illustrations
- Updated "Need help?" tooltip triggers
- Updated translations for Croatian language
- `dependentsInfo` in `VizResult` is now nullable
- Fixed data match overall result

#### Breaking API changes
- Removed `stepTimeoutDuration` from `BlinkIDVerifyAnalyzer` init as it is stored in `CaptureSessionSettings`
  - fix by setting `stepTimeoutDuration` in `CaptureSessionSettings`, remove from `BlinkIDVerifyAnalyzer` init

## 3.9.1

- Bug fixes:
    - Fix `lastName` BlinkID extraction 

## 3.9.0

### BlinkID integration
- *BlinkID SDK* is now fully integrated into BlinkID Verify SDK. 
    - All BlinkID-specific functionalities, like document extraction, may now be used in a session completely independent of the Verify session.
    - There is no need to declare BlinkID dependencies as all of the files are automatically included.

### API changes:
- added UI localization for 22 additional languages

## 3.8.1

- Fix nested package results:
    - Correct issues with returning results when the package is embedded inside another framework
- Implement timeout error for downloads:
    - Introduce a specific `timeout` error to handle cases where resource downloads exceed the expected duration.
- Extend download timeout duration:
    - Increase the default timeout from 3 to 30 seconds to better support weak internet connections.

## 3.8.0

- BlinkIDVerify initial release
