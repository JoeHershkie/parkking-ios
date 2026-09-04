import SwiftUI

@main
struct ParkkingApp: App {
    @State private var isShowingSplash = true

    private var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
        ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    var body: some Scene {
        WindowGroup {
            if isTesting {
                Color.clear
            } else {
                ZStack {
                    ParkingMapScreen(isSplashActive: isShowingSplash)

                    if isShowingSplash {
                        SplashScreenView(
                            onFinished: {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    isShowingSplash = false
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                        .zIndex(1)
                    }
                }
            }
        }
    }
}
