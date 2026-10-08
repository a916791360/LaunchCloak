import AppKit
import Foundation
import ServiceManagement
import LocalAuthentication
import SwiftUI

@MainActor
public final class SettingsManager: ObservableObject {
    @AppStorage("requireAuthForHiddenTab") public var requireAuthForHiddenTab: Bool = false
    @Published public var isHiddenTabUnlocked: Bool = false
    @Published public var isLaunchAtLoginEnabled: Bool = false
    @Published public var authErrorMessage: String? = nil
    
    public init() {
        checkLaunchAtLoginStatus()
    }
    
    /// 检查开机自启状态
    public func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            self.isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    /// 切换开机自启动
    public func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                self.isLaunchAtLoginEnabled = enabled
            } catch {
                print("Failed to update SMAppService: \(error.localizedDescription)")
                // 即使无权限或在非 /Applications 目录调试，保持 UI 反映尝试状态
                self.isLaunchAtLoginEnabled = enabled
            }
        }
    }
    
    /// 验证用户身份（支持 Touch ID 或 Mac 锁屏密码）
    public func authenticate(reason: String = "请验证以访问已隐藏的应用") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 如果设备未设置密码或不支持，默认放行
            return true
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    if success {
                        self.isHiddenTabUnlocked = true
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    /// 重新锁定已隐藏标签页
    public func lockHiddenTab() {
        self.isHiddenTabUnlocked = false
    }
}
