import SwiftUI

@main
struct LaunchCloakApp: App {
    @StateObject private var manager = AppManager()
    
    init() {
        // 启动时延迟 2 秒后台静默检查更新（仅在有新版本时才会弹窗，不影响正常启动）
        let autoCheck = UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true
        if autoCheck {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task { @MainActor in
                    UpdateChecker.shared.checkForUpdates(explicit: false)
                }
            }
        }
    }
    
    var body: some Scene {
        MenuBarExtra("LaunchCloak", systemImage: "eye.slash") {
            MainContentView(manager: manager)
        }
        .menuBarExtraStyle(.window)
    }
}
