import CoreGraphics
import SwiftUI
import XCTest
@testable import Parkking

final class SplashScreenViewTests: XCTestCase {
    func testLogoColorsAreDefined() {
        XCTAssertNotNil(ParkkingLogoColors.background)
        XCTAssertNotNil(ParkkingLogoColors.redLine)
        XCTAssertNotNil(ParkkingLogoColors.greenLine)
        XCTAssertNotNil(ParkkingLogoColors.title)
    }

    func testShapePathsAreNonEmpty() {
        let testRect = CGRect(x: 0, y: 0, width: 200, height: 200)

        let redPath = ParkkingRedLinesShape().path(in: testRect)
        XCTAssertFalse(redPath.isEmpty, "Red lines path should not be empty")

        let greenPath = ParkkingGreenLinesShape().path(in: testRect)
        XCTAssertFalse(greenPath.isEmpty, "Green lines path should not be empty")

        let shieldPath = ParkkingShieldAndPShape().path(in: testRect)
        XCTAssertFalse(shieldPath.isEmpty, "Shield and P path should not be empty")

        let crownPath = ParkkingCrownShape().path(in: testRect)
        XCTAssertFalse(crownPath.isEmpty, "Crown path should not be empty")
    }

    func testAnimatedLogoViewInitialization() {
        let logo = ParkkingAnimatedLogoView(
            redProgress: 0.5,
            greenTransitProgress: 0.5,
            shieldProgress: 0.5,
            crownProgress: 0.5,
            lineWidthRatio: 0.047
        )
        XCTAssertEqual(logo.redProgress, 0.5)
        XCTAssertEqual(logo.greenTransitProgress, 0.5)
        XCTAssertEqual(logo.shieldProgress, 0.5)
        XCTAssertEqual(logo.crownProgress, 0.5)
    }

    func testSplashScreenViewInitialization() {
        var finishedCalled = false
        let splash = SplashScreenView(
            isDataReady: true,
            minimumDisplayDuration: 0.1,
            onFinished: { finishedCalled = true }
        )
        XCTAssertTrue(splash.isDataReady)
        XCTAssertEqual(splash.minimumDisplayDuration, 0.1)
        XCTAssertFalse(finishedCalled)
    }
}
