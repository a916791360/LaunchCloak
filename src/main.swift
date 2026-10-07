import SwiftUI

@main
struct LaunchCloakApp: App {
    @StateObject private var manager = AppManager()
    
    var body: some Scene {
        MenuBarExtra("LaunchCloak", systemImage: "eye.slash") {
            MainContentView(manager: manager)
        }
        .menuBarExtraStyle(.window)
    }
}
