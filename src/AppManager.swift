import AppKit
import Foundation
import Combine

@MainActor
public final class AppManager: ObservableObject {
    @Published public var installedApps: [AppItem] = []
    @Published public var hiddenApps: [AppItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    public let hiddenFolderURL: URL
    private let metadataURL: URL
    private var records: [String: HiddenAppRecord] = [:]
    
    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.hiddenFolderURL = home.appendingPathComponent(".hidden_apps.noindex", isDirectory: true)
        self.metadataURL = hiddenFolderURL.appendingPathComponent("metadata.json")
        
        setupHiddenDirectory()
        loadMetadata()
        refresh()
    }
    
    /// 初始化隐藏隔离目录
    private func setupHiddenDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: hiddenFolderURL.path) {
            try? fm.createDirectory(at: hiddenFolderURL, withIntermediateDirectories: true)
        }
    }
    
    /// 读取历史元数据
    private func loadMetadata() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([String: HiddenAppRecord].self, from: data) else {
            return
        }
        self.records = decoded
    }
    
    /// 保存元数据
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: metadataURL)
    }
    
    /// 刷新已安装和已隐藏应用列表
    public func refresh() {
        self.isLoading = true
        self.errorMessage = nil
        
        let hiddenDir = self.hiddenFolderURL
        
        Task {
            let (hiddenList, installedList) = await Task.detached(priority: .userInitiated) { () -> ([AppItem], [AppItem]) in
                let fm = FileManager.default
                
                // 1. 扫描已隐藏目录
                var hidden: [AppItem] = []
                if let hiddenContents = try? fm.contentsOfDirectory(at: hiddenDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for url in hiddenContents where url.pathExtension == "app" {
                        hidden.append(AppItem(url: url, isHidden: true))
                    }
                }
                
                // 2. 扫描已安装应用目录
                var installed: [AppItem] = []
                let searchDirs = [
                    URL(fileURLWithPath: "/Applications"),
                    fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
                ]
                
                for dir in searchDirs {
                    guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                    for url in contents where url.pathExtension == "app" {
                        if url.lastPathComponent.contains("LaunchCloak") { continue }
                        installed.append(AppItem(url: url, isHidden: false))
                    }
                }
                
                hidden.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                installed.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                
                return (hidden, installed)
            }.value
            
            self.hiddenApps = hiddenList
            self.installedApps = installedList
            self.isLoading = false
        }
    }
    
    /// 隐藏指定应用
    public func hideApp(_ item: AppItem) {
        let fm = FileManager.default
        let fileName = item.url.lastPathComponent
        let targetURL = hiddenFolderURL.appendingPathComponent(fileName)
        
        // 记录原位置
        let record = HiddenAppRecord(
            bundleIdentifier: item.bundleIdentifier,
            appName: item.name,
            originalPath: item.url.path,
            hiddenDate: Date()
        )
        self.records[fileName] = record
        self.saveMetadata()
        
        // 执行文件移动
        do {
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.moveItem(at: item.url, to: targetURL)
            notifySystemChange(at: targetURL, original: item.url)
            refresh()
        } catch {
            // 若遇权限受限，尝试以管理员提权移动
            let success = moveWithPrivileges(from: item.url.path, to: targetURL.path)
            if success {
                notifySystemChange(at: targetURL, original: item.url)
                refresh()
            } else {
                self.errorMessage = "隐藏失败：无法移动 \(item.name)，可能受 macOS 权限或系统保护限制。"
                self.records.removeValue(forKey: fileName)
                self.saveMetadata()
            }
        }
    }
    
    /// 恢复指定应用
    public func restoreApp(_ item: AppItem) {
        let fm = FileManager.default
        let fileName = item.url.lastPathComponent
        
        let destinationPath = self.records[fileName]?.originalPath ?? "/Applications/\(fileName)"
        let targetURL = URL(fileURLWithPath: destinationPath)
        
        do {
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.moveItem(at: item.url, to: targetURL)
            self.records.removeValue(forKey: fileName)
            self.saveMetadata()
            notifySystemChange(at: targetURL, original: item.url)
            refresh()
        } catch {
            let success = moveWithPrivileges(from: item.url.path, to: targetURL.path)
            if success {
                self.records.removeValue(forKey: fileName)
                self.saveMetadata()
                notifySystemChange(at: targetURL, original: item.url)
                refresh()
            } else {
                self.errorMessage = "恢复失败：无法还原 \(item.name) 到原路径。"
            }
        }
    }
    
    /// 恢复所有已隐藏应用
    public func restoreAll() {
        for app in hiddenApps {
            restoreApp(app)
        }
    }
    
    /// 在访达中打开隐藏目录
    public func openHiddenFolder() {
        NSWorkspace.shared.open(hiddenFolderURL)
    }
    
    /// 管理员提权执行 mv
    private func moveWithPrivileges(from: String, to: String) -> Bool {
        let script = "do shell script \"mv \\\"\(from)\\\" \\\"\(to)\\\"\" with administrator privileges"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }
    
    /// 通知系统文件变化
    private func notifySystemChange(at target: URL, original: URL) {
        // 使用 touch 与 mdimport 刷新 Spotlight / Launchpad 缓存
        Process.launchedProcess(launchPath: "/usr/bin/touch", arguments: [target.path])
        Process.launchedProcess(launchPath: "/usr/bin/touch", arguments: [original.deletingLastPathComponent().path])
    }
}
