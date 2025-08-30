# Camera

A modern, easy-to-use, and customizable camera package for SwiftUI applications. Built with async/await and actors for a robust and thread-safe camera experience.


## Features

- **SwiftUI Native:** Designed from the ground up for SwiftUI, providing a `CameraView` that can be easily integrated into any view hierarchy.
- **Modern Concurrency:** Uses `async/await` and Swift actors to provide a modern, safe, and performant camera implementation.
- **Photo Capture:** Simple photo capture with a completion handler that returns an `AVCapturePhoto`.
- **Camera Controls:**
    - Switch between front and back cameras.
    - Select different capture quality presets.
- **Preview and Confirmation:** After taking a photo, a confirmation screen is shown where the user can accept or discard the photo.
- **Customizable:** The underlying `Camera` actor and `CameraModel` can be customized or replaced for advanced use cases.
- **Mockable:** Includes a `MockCamera` for easy testing and previewing in SwiftUI.

## Installation

You can add the `Camera` package to your Xcode project using the Swift Package Manager.

1. In Xcode, open your project and navigate to **File > Add Packages...**
2. In the "Search or Enter Package URL" field, enter the repository URL: `https://github.com/NivekAlunya/Camera`
3. Xcode will fetch the package and you can add `"Camera"` to your app's target.

## Usage

Here's a basic example of how to present the `CameraView`:

```swift
import SwiftUI
import Camera

struct ContentView: View {
    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("No image captured")
            }

            Button("Open Camera") {
                isShowingCamera = true
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraView { photo, config in
                if let photo = photo, let cgImage = photo.cgImageRepresentation() {
                    // Get the image orientation from metadata
                    let imageOrientation = UIImage.Orientation(cgImage.orientation)
                    // Create the UIImage with the correct orientation
                    self.capturedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
                }
                isShowingCamera = false
            }
        }
    }
}

// Helper to get UIImage.Orientation from CGImagePropertyOrientation
extension UIImage.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
```

## Testing

To run the tests for this package, you can use the following command:

```bash
swift test
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
