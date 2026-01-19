import SwiftUI
import Combine

struct GFSLoadingScreen: View {

    @State private var appear: Bool = false
    @State private var spin: Double = 0
    @State private var bounce: Bool = false
    @State private var wave: CGFloat = 0

    var body: some View {
        ZStack {
            GFSTheme.background
                .ignoresSafeArea()

            jellyField

            VStack {
                Spacer()

                fluxCore
                    .frame(width: 220, height: 220)

                Text("Loading")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(GFSTheme.textPrimary.opacity(0.9))
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.35), value: appear)

                Spacer()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            appear = true
            bounce = true

            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                spin = 360
            }

            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                wave = 1
            }
        }
    }

    private var jellyField: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Color.black.opacity(0.18)

                jellyBlob(
                    size: min(w, h) * 0.95,
                    x: w * 0.18,
                    y: h * 0.28,
                    a: GFSTheme.accent.opacity(0.35),
                    b: GFSTheme.accentSoft.opacity(0.14),
                    shift: wave
                )

                jellyBlob(
                    size: min(w, h) * 0.72,
                    x: w * 0.82,
                    y: h * 0.42,
                    a: GFSTheme.mint.opacity(0.28),
                    b: GFSTheme.accent.opacity(0.12),
                    shift: -wave * 0.8
                )

                jellyBlob(
                    size: min(w, h) * 0.58,
                    x: w * 0.52,
                    y: h * 0.78,
                    a: GFSTheme.sun.opacity(0.22),
                    b: GFSTheme.accentSoft.opacity(0.10),
                    shift: wave * 0.6
                )
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private func jellyBlob(
        size: CGFloat,
        x: CGFloat,
        y: CGFloat,
        a: Color,
        b: Color,
        shift: CGFloat
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [a, b, Color.clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: size * 0.55
                )
            )
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .offset(x: shift * 120, y: shift * 90)
            .scaleEffect(bounce ? 1.04 : 0.96)
            .blur(radius: 24)
            .blendMode(.screen)
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: bounce)
    }

    private var fluxCore: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                GFSTheme.accentSoft.opacity(0.35),
                                GFSTheme.mint.opacity(0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: side * 0.52
                        )
                    )
                    .frame(width: side, height: side)
                    .position(c)
                    .scaleEffect(bounce ? 1.05 : 0.97)
                    .blur(radius: 14)
                    .blendMode(.screen)
                    .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: bounce)

                ForEach(0..<12, id: \.self) { i in
                    FluxParticle(index: i, spin: spin)
                        .position(c)
                }

                Circle()
                    .fill(GFSTheme.sun)
                    .frame(width: side * 0.22, height: side * 0.22)
                    .scaleEffect(bounce ? 1.02 : 0.95)
                    .shadow(color: GFSTheme.sun.opacity(0.6), radius: 18)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FluxParticle: View {

    let index: Int
    let spin: Double

    var body: some View {
        let count = 12.0
        let base = Double(index) / count * 360.0
        let angle = (base + spin) * .pi / 180.0

        let radius = 70.0 + Double(index % 3) * 14.0
        let x = cos(angle) * radius
        let y = sin(angle) * radius

        return Circle()
            .fill(GFSTheme.accent)
            .frame(width: 8, height: 8)
            .offset(x: x, y: y)
            .opacity(0.85)
            .blur(radius: 0.5)
    }
}
