import Combine
import SwiftUI

struct GFSPlayContainer: View {

    @EnvironmentObject private var router: GFSRouter
    @EnvironmentObject private var launch: GFSLaunchStore
    @EnvironmentObject private var session: GFSSessionState

    @StateObject private var model = GFSPlayCoordinator()

    let onReady: () -> Void

    init(onReady: @escaping () -> Void) {
        self.onReady = onReady
    }

    var body: some View {
        let start = launch.restoreResume() ?? launch.mainPoint

        ZStack {
            Color.black.ignoresSafeArea()

            GFSPlayView(
                startPoint: start,
                launch: launch,
                session: session
            ) {
                model.markReady()
                onReady()
            }
            .opacity(model.fadeIn ? 1 : 0)
            .animation(.easeOut(duration: 0.32), value: model.fadeIn)

            if model.showOverlay {
                loadingOverlay
            }

            Color.black
                .opacity(model.dimLayer)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.22), value: model.dimLayer)
        }
        .onAppear {
            model.onAppear()
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                GFSTropicSpinner()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .transition(.opacity)
    }
}

private struct GFSTropicSpinner: View {

    @State private var spin: Double = 0
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 2.5)
                .frame(width: 56, height: 56)

            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.white.opacity(pulse ? 0.95 : 0.72))
                .scaleEffect(pulse ? 1.03 : 0.97)

            Image(systemName: "drop.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.82))
                .offset(y: -27)
                .rotationEffect(.degrees(spin))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                spin = 360
            }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
