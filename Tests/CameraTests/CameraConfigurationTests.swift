import Testing
import AVFoundation
@testable import Camera

@Suite("CameraConfiguration tests")
struct CameraConfigurationTests {

    @Test("buildPhotoSettings default config does not crash")
    func testBuildPhotoSettingsDefault() async {
        let config = CameraConfiguration()
        let settings = await config.buildPhotoSettings()
        #expect(settings.photoQualityPrioritization == config.quality)
    }

    @Test("buildPhotoSettings with 24MP resolution does not exceed photoOutput maxPhotoDimensions")
    func testBuildPhotoSettings24MP() async {
        var config = CameraConfiguration(resolution: .mp24)
        let settings = await config.buildPhotoSettings()
        if #available(iOS 16.0, *) {
            let outputMaxPixels = config.photoOutput.maxPhotoDimensions.width * config.photoOutput.maxPhotoDimensions.height
            let settingsMaxPixels = settings.maxPhotoDimensions.width * settings.maxPhotoDimensions.height
            #expect(settingsMaxPixels <= outputMaxPixels, "Settings maxPhotoDimensions must never exceed photoOutput.maxPhotoDimensions")
        }
    }

    @Test("buildPhotoSettings with 48MP resolution does not exceed photoOutput maxPhotoDimensions")
    func testBuildPhotoSettings48MP() async {
        var config = CameraConfiguration(resolution: .mp48)
        let settings = await config.buildPhotoSettings()
        if #available(iOS 16.0, *) {
            let outputMaxPixels = config.photoOutput.maxPhotoDimensions.width * config.photoOutput.maxPhotoDimensions.height
            let settingsMaxPixels = settings.maxPhotoDimensions.width * settings.maxPhotoDimensions.height
            #expect(settingsMaxPixels <= outputMaxPixels, "Settings maxPhotoDimensions must never exceed photoOutput.maxPhotoDimensions")
        }
    }

    @Test("updatePhotoOutputMaxDimensions safe without deviceInput")
    func testUpdatePhotoOutputMaxDimensionsSafe() {
        let config = CameraConfiguration()
        config.updatePhotoOutputMaxDimensions()
        // Should execute cleanly without error or crash
    }
}
