import SwiftUI
import Combine

@main
struct GFSApp: App {

    @UIApplicationDelegateAdaptor(GFSFlowDelegate.self) private var flow

    @StateObject private var router = GFSRouter()
    @StateObject private var launch = GFSLaunchStore()
    @StateObject private var session = GFSSessionState()
    @StateObject private var orientation = GFSOrientationManager()

    var body: some Scene {
        WindowGroup {
            GFSEntryScreen()
                .environmentObject(router)
                .environmentObject(launch)
                .environmentObject(session)
                .environmentObject(orientation)
        }
    }
}
