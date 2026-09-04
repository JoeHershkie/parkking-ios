import SwiftUI

public enum ParkkingLogoColors {
    public static let background = Color(red: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xF0 / 255.0)
    public static let redLine = Color(red: 0xFD / 255.0, green: 0x50 / 255.0, blue: 0x37 / 255.0)
    public static let greenLine = Color(red: 0x4C / 255.0, green: 0xC2 / 255.0, blue: 0x72 / 255.0)
    public static let title = Color(red: 0x1F / 255.0, green: 0x24 / 255.0, blue: 0x21 / 255.0)
}

public struct ParkkingRedLinesShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let originX = rect.minX + (rect.width - side) / 2
        let originY = rect.minY + (rect.height - side) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + side * (x / 1024.0),
                    y: originY + side * (y / 1024.0))
        }

        // 1. Long diagonal line (bottom-left to top-right)
        path.move(to: pt(100, 890))
        path.addLine(to: pt(925, 115))

        // 2. Horizontal red bar from left edge
        path.move(to: pt(70, 575))
        path.addLine(to: pt(385, 575))

        // 3. Lower right diagonal 1 (up-right)
        path.move(to: pt(520, 940))
        path.addLine(to: pt(965, 520))

        // 4. Lower right diagonal 2 (down-right, crossing line 3)
        path.move(to: pt(565, 735))
        path.addLine(to: pt(825, 940))

        return path
    }
}

public struct ParkkingGreenLinesShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let originX = rect.minX + (rect.width - side) / 2
        let originY = rect.minY + (rect.height - side) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + side * (x / 1024.0),
                    y: originY + side * (y / 1024.0))
        }

        // 1. Upper right diagonal transit line curving down into the shield shoulder
        path.move(to: pt(965, 230))
        path.addLine(to: pt(780, 415))
        path.addCurve(
            to: pt(745, 510),
            control1: pt(750, 445),
            control2: pt(745, 475)
        )

        // 2. Horizontal green bar on lower-left
        path.move(to: pt(70, 715))
        path.addLine(to: pt(275, 715))

        return path
    }
}

public struct ParkkingShieldAndPShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let originX = rect.minX + (rect.width - side) / 2
        let originY = rect.minY + (rect.height - side) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + side * (x / 1024.0),
                    y: originY + side * (y / 1024.0))
        }

        // 1. Left stem bottom segment (below horizontal red line gap)
        path.move(to: pt(275, 960))
        path.addLine(to: pt(275, 620))

        // 2. Left stem upper segment + Shield top arch + Right side + Bottom curve
        path.move(to: pt(275, 530))
        path.addLine(to: pt(275, 400))
        path.addCurve(
            to: pt(512, 280),
            control1: pt(275, 320),
            control2: pt(370, 280)
        )
        path.addCurve(
            to: pt(745, 400),
            control1: pt(654, 280),
            control2: pt(745, 320)
        )
        path.addLine(to: pt(745, 570))
        path.addCurve(
            to: pt(420, 715),
            control1: pt(745, 670),
            control2: pt(620, 715)
        )
        path.addLine(to: pt(275, 715))

        // 3. Central P vertical stem
        path.move(to: pt(420, 280))
        path.addLine(to: pt(420, 960))

        // 4. P loop
        path.move(to: pt(420, 370))
        path.addCurve(
            to: pt(635, 472),
            control1: pt(560, 370),
            control2: pt(635, 410)
        )
        path.addCurve(
            to: pt(420, 575),
            control1: pt(635, 535),
            control2: pt(560, 575)
        )

        return path
    }
}

public struct ParkkingCrownShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let originX = rect.minX + (rect.width - side) / 2
        let originY = rect.minY + (rect.height - side) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + side * (x / 1024.0),
                    y: originY + side * (y / 1024.0))
        }

        // Crown contour and base
        path.move(to: pt(365, 230))
        path.addLine(to: pt(350, 115))
        path.addLine(to: pt(435, 195))
        path.addLine(to: pt(512, 90))
        path.addLine(to: pt(589, 195))
        path.addLine(to: pt(674, 115))
        path.addLine(to: pt(659, 230))
        path.addCurve(
            to: pt(365, 230),
            control1: pt(580, 242),
            control2: pt(444, 242)
        )

        // Inner chevron
        path.move(to: pt(435, 195))
        path.addLine(to: pt(512, 90))
        path.addLine(to: pt(589, 195))

        return path
    }
}

public struct ParkkingAnimatedLogoView: View {
    public var redProgress: CGFloat
    public var greenTransitProgress: CGFloat
    public var shieldProgress: CGFloat
    public var crownProgress: CGFloat
    public var lineWidthRatio: CGFloat

    public init(
        redProgress: CGFloat = 1.0,
        greenTransitProgress: CGFloat = 1.0,
        shieldProgress: CGFloat = 1.0,
        crownProgress: CGFloat = 1.0,
        lineWidthRatio: CGFloat = 0.047
    ) {
        self.redProgress = redProgress
        self.greenTransitProgress = greenTransitProgress
        self.shieldProgress = shieldProgress
        self.crownProgress = crownProgress
        self.lineWidthRatio = lineWidthRatio
    }

    public var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let lineWidth = side * lineWidthRatio
            let strokeStyle = StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                lineJoin: .round
            )

            ZStack {
                // Background Red Lines
                ParkkingRedLinesShape()
                    .trim(from: 0, to: redProgress)
                    .stroke(ParkkingLogoColors.redLine, style: strokeStyle)

                // Background Green Transit Lines
                ParkkingGreenLinesShape()
                    .trim(from: 0, to: greenTransitProgress)
                    .stroke(ParkkingLogoColors.greenLine, style: strokeStyle)

                // Shield & Monogram "P"
                ParkkingShieldAndPShape()
                    .trim(from: 0, to: shieldProgress)
                    .stroke(ParkkingLogoColors.greenLine, style: strokeStyle)

                // Crown
                ParkkingCrownShape()
                    .trim(from: 0, to: crownProgress)
                    .stroke(ParkkingLogoColors.greenLine, style: strokeStyle)
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
