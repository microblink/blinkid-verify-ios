# Transition Guide: BlinkID to BlinkID Verify SDK

This guide will help you migrate your application from BlinkID to the new BlinkID Verify SDK. The BlinkID Verify SDK provides a modernized approach to document scanning and verification with improved architecture and SwiftUI support.

## Key Differences

### 1. Architecture Changes

- **New Core Components**: Instead of MBRecognizer-based architecture, BlinkID Verify uses a streamlined CaptureSession-based approach
- **Modern Swift Features**: Built with Swift 6, leveraging latest concurrency features
- **SwiftUI First**: Native SwiftUI support through BlinkIDVerifyUX package
- **Simplified Flow**: More straightforward API with clearer separation of concerns

### 2. Integration Methods

#### BlinkID (Old):
```swift
// Multiple integration methods
- CocoaPods
- Carthage
- Swift Package Manager
- Manual Integration
```

#### BlinkID Verify (New):
```swift
// Two primary methods
1. Swift Package Manager (Recommended)
2. Manual Integration
```

## Migration Guide

### 1. Update Dependencies

#### Remove Old Dependencies:
```ruby
# Remove from Podfile if using CocoaPods
pod 'PPBlinkID'

# Remove from Cartfile if using Carthage
binary "https://github.com/BlinkID/blinkid-ios/blob/master/blinkid-ios.json"
```

#### Add New Dependencies:

```swift
// Add to Swift Package Manager
dependencies: [
    .package(url: "https://github.com/BlinkID/blinkid-verify-ios.git", 
             .upToNextMajor(from: "3.8.0"))
]
```

### 2. Update Import Statements

#### Old:
```swift
import BlinkID
```

#### New:
```swift
import BlinkIDVerify
import BlinkIDVerifyUX  // If using the UX components
```

### 3. Initialization Changes

#### Old (BlinkID):
```swift
// Old initialization
MBMicroblinkSDK.shared().setLicenseKey("license-key")

// Creating recognizer
let blinkIdMultiSideRecognizer = MBBlinkIdMultiSideRecognizer()
let recognizerCollection = MBRecognizerCollection(recognizers: [blinkIdMultiSideRecognizer])
```

#### New (BlinkID Verify):
```swift
// New initialization
let settings = DocumentVerifySdkSettings(
    licenseKey: "your-license-key",
    downloadResources: true
)

let sdk = try await DocumentVerifySdk.createDocumentVerifySdk(withSettings: settings)
let session = await sdk.createScanningSession()
```

### 4. UI Implementation Changes

#### Old (BlinkID):

```swift
// Using BlinkID overlay controller
let settings = MBBlinkIdOverlaySettings()
let blinkIdOverlayViewController = MBBlinkIdOverlayViewController(
    settings: settings,
    recognizerCollection: recognizerCollection,
    delegate: self
)

let recognizerRunnerViewController = MBViewControllerFactory.recognizerRunnerViewController(
    withOverlayViewController: blinkIdOverlayViewController
)
```

#### New (BlinkID Verify):

```swift
// Using BlinkIDVerifyUX
let analyzer = try await BlinkIDVerifyAnalyzer(
    sdk: sdk,
    consentConfig: .setConsentWithUi(userId: "your-unique-user-id"),
    eventStream: BlinkIDVerifyEventStream()
)

let viewModel = ScanningUXModel(analyzer: analyzer)

// In SwiftUI
struct ContentView: View {
    var body: some View {
        ScanningUXView(viewModel: viewModel)
    }
}
```

### 5. Result Handling

#### Old (BlinkID):
```swift
// BlinkID delegate method
func blinkIdOverlayViewControllerDidFinishScanning( _ blinkIdOverlayViewController: MBBlinkIdOverlayViewController, state: MBRecognizerResultState) {
    if state == .valid {
        // Access results through recognizer
        let result = blinkIdMultiSideRecognizer.result
    }
}
```

#### New (BlinkID Verify):

```swift
// Process results
let result = await session.process(inputImage: capturedImage)
if result.resultCompleteness.overallFlowFinished {
    let finalResult = await session.getResult()
    // Handle the result
}

// Or using SwiftUI binding
viewModel.$captureResult
    .sink { captureResult in
        if let result = captureResult {
            // Handle the verification result
        }
    }
    .store(in: &cancellables)
```

### 6. Custom UI Implementation

#### Old (BlinkID):
```swift
class CustomOverlayViewController: MBCustomOverlayViewController {
    // Custom overlay implementation
}
```

#### New (BlinkID Verify):

```swift
// Create custom ViewModel
class CustomViewModel: ObservableObject {
    let camera: Camera = Camera()
    let analyzer: CameraFrameAnalyzer
    
    @Published var captureResult: BlinkIDVerifyCaptureResult?
    
    init(analyzer: CameraFrameAnalyzer) {
        self.analyzer = analyzer
    }
}

// Create custom SwiftUI View
struct CustomScanView: View {
    @StateObject var viewModel: CustomViewModel
    
    var body: some View {
        CameraView(camera: viewModel.camera)
            .task {
                await viewModel.camera.start()
                await viewModel.analyze()
            }
    }
}
```

## Additional Considerations

### Resource Management

- BlinkID Verify SDK supports both downloaded and bundled resources
- Configure resource handling through `DocumentVerifySdkSettings`:
  ```swift
  let settings = DocumentVerifySdkSettings(
      licenseKey: "your-license-key",
      downloadResources: true,  // Set to false for bundled resources
      resourceLocalFolder: "CustomFolder"  // Optional custom storage location
  )
  ```

### Backend Verification Integration

- BlinkID Verify SDK provides built-in support for backend verification:

  ```swift
  let docVerSettings = BlinkIDVerifyServiceSettings(
      verificationServiceBaseUrl: "docver.microblink.com",
      accessClientId: "your-access-client-id",
      accessClientSecret: "your-client-secret"
  )
  
  let docVerService = BlinkIDVerifyService(settings: docVerSettings)
  ```

## Best Practices for Migration

1. **Gradual Migration**:
   - Consider migrating feature by feature if possible
   - Test thoroughly in a development environment before production deployment

2. **Resource Management**:
   - Decide between downloaded or bundled resources early in the migration
   - Set up proper resource paths and verify resource loading

3. **UI/UX Considerations**:
   - Take advantage of SwiftUI if possible
   - Consider reimplementing custom UI components using the new architecture

4. **Error Handling**:
   - Update error handling to work with the new async/await pattern
   - Implement proper error handling for resource downloading if used

## Support and Resources

- For API documentation: Visit the [BlinkIDVerify](http://blinkid.github.io/blinkid-verify-sp/docs/blinkidverify/) and [BlinkIDVerifyUX](http://blinkid.github.io/blinkid-verify-ios/docs/blinkidverifyux/) documentation
- For backend verification: Check the [BlinkID Verify API](https://blinkidverify.docs.microblink.com/docs/api/request/)
- For support: Contact technical support through the support portal
