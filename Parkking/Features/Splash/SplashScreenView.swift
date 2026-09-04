import SwiftUI

public struct SplashScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var isDataReady: Bool
    public var minimumDisplayDuration: TimeInterval
    public var onFinished: () -> Void

    @State private var redProgress: CGFloat = 0.0
    @State private var greenTransitProgress: CGFloat = 0.0
    @State private var shieldProgress: CGFloat = 0.0
    @State private var crownProgress: CGFloat = 0.0

    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 18.0

    @State private var animationCompleted = false

    public init(
        isDataReady: Bool = true,
        minimumDisplayDuration: TimeInterval = 1.4,
        onFinished: @escaping () -> Void = {}
    ) {
        self.isDataReady = isDataReady
        self.minimumDisplayDuration = minimumDisplayDuration
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            ParkkingLogoColors.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ParkkingAnimatedLogoView(
                    redProgress: redProgress,
                    greenTransitProgress: greenTransitProgress,
                    shieldProgress: shieldProgress,
                    crownProgress: crownProgress
                )
                .frame(width: 180, height: 180)

                Text("Parkking")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(ParkkingLogoColors.title)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                    .accessibilityAddTraits(.isHeader)
            }
            .offset(y: -24) // Visually centers the emblem + wordmark block
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: isDataReady) { _, ready in
            if ready && animationCompleted {
                notifyFinished()
            }
        }
    }

    private func startAnimation() {
        if reduceMotion {
            redProgress = 1.0
            greenTransitProgress = 1.0
            shieldProgress = 1.0
            crownProgress = 1.0
            textOpacity = 1.0
            textOffset = 0.0
            animationCompleted = true
            checkReadyToFinish()
            return
        }

        // Phase 1: Background red and green transit lines (0.0s -> ~0.6s)
        withAnimation(.easeInOut(duration: 0.6)) {
            redProgress = 1.0
            greenTransitProgress = 1.0
        }

        // Phase 2: Shield and Monogram "P" (0.25s -> ~0.9s)
        withAnimation(.easeInOut(duration: 0.65).delay(0.25)) {
            shieldProgress = 1.0
        }

        // Phase 3: Crown (0.55s -> ~1.05s)
        withAnimation(.easeInOut(duration: 0.5).delay(0.55)) {
            crownProgress = 1.0
        }

        // Phase 4: Brand wordmark "Parkking" reveals underneath (0.85s -> ~1.35s)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.85)) {
            textOpacity = 1.0
            textOffset = 0.0
        }

        // Schedule completion after minimum duration
        Task { @MainActor in
            let delayNanos = UInt64(minimumDisplayDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanos)
            animationCompleted = true
            checkReadyToFinish()
        }
    }

    private func checkReadyToFinish() {
        if isDataReady && animationCompleted {
            notifyFinished()
        }
    }

    private func notifyFinished() {
        onFinished()
    }
}

#Preview("Splash Screen") {
    SplashScreenView()
}
