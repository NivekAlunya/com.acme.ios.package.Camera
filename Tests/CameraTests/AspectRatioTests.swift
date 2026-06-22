import Testing
import CoreImage
import Foundation
@testable import Camera

@Suite("AspectRatio tests")
struct AspectRatioTests {
    
    @Test("CaptureSessionAspectRatio.targetSize for 4:3")
    func testTargetSize43() {
        let ratio = CaptureSessionAspectRatio.ratio_4_3
        
        // Portrait input matching exact 3:4 ratio (3000x4000) — no crop needed.
        let portraitInput = CGSize(width: 3000, height: 4000)
        let portraitTarget = ratio.targetSize(for: portraitInput)
        #expect(portraitTarget?.width == 3000)
        #expect(portraitTarget?.height == 4000)
        
        // Wider portrait input (3500x4000): the image is wider than 3:4.
        // Policy: cannot fill 3:4 without side-cropping → return nil (keep full image).
        let widerPortraitInput = CGSize(width: 3500, height: 4000)
        let widerPortraitTarget = ratio.targetSize(for: widerPortraitInput)
        #expect(widerPortraitTarget == nil, "Should return nil when side-cropping would be required")
        
        // Taller portrait input (3000x4500): image is narrower than 3:4, crop height only.
        let tallerPortraitInput = CGSize(width: 3000, height: 4500)
        let tallerPortraitTarget = ratio.targetSize(for: tallerPortraitInput)
        #expect(tallerPortraitTarget?.width == 3000)
        #expect(tallerPortraitTarget?.height == 4000)
    }
    
    @Test("CaptureSessionAspectRatio.targetSize for 1:1")
    func testTargetSize11() {
        let ratio = CaptureSessionAspectRatio.ratio_1_1
        
        let portraitInput = CGSize(width: 3000, height: 4000)
        let portraitTarget = ratio.targetSize(for: portraitInput)
        #expect(portraitTarget?.width == 3000)
        #expect(portraitTarget?.height == 3000)
        
        let landscapeInput = CGSize(width: 4000, height: 3000)
        let landscapeTarget = ratio.targetSize(for: landscapeInput)
        #expect(landscapeTarget?.width == 3000)
        #expect(landscapeTarget?.height == 3000)
    }
    
    @Test("CIImage.cropped(to:) produces expected size")
    func testCIImageCropping() {
        let image = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4000, height: 3000))
        let cropped = image.cropped(to: .ratio_1_1)
        
        #expect(cropped.extent.size.width == 3000)
        #expect(cropped.extent.size.height == 3000)
        #expect(cropped.extent.origin.x == 500)
        #expect(cropped.extent.origin.y == 0)
    }
}
