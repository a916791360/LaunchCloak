import AppKit
import SwiftUI

/// 管理独立的偏好设置原生窗口（解决在 MenuBarExtra 中使用 sheet 会失焦闪退、开关变灰的问题）
@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    public func show(settings: SettingsManager, manager: AppManager) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(settings: settings, manager: manager) { [weak self] in
            self?.close()
        }
        
        let hostingView = NSHostingView(rootView: settingsView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "偏好设置"
        newWindow.titleVisibility = .visible
        newWindow.titlebarAppearsTransparent = true
        newWindow.isReleasedWhenClosed = false
        newWindow.isMovableByWindowBackground = true
        newWindow.center()
        newWindow.contentView = hostingView
        newWindow.delegate = self
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func close() {
        window?.orderOut(nil)
        window = nil
    }
    
    public func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}
