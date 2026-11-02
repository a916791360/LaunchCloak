import AppKit
import Foundation
import Combine
import SwiftUI

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
        refresh(showLoading: true)
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
    
    /// 刷新已安装和已隐藏应用列表（仅在初次加载或手动请求刷新时触发）
    public func refresh(showLoading: Bool = true) {
        if showLoading {
            self.isLoading = true
        }
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
                    URL(fileURLWithPath: "/Applications/Utilities"),
                    fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
                ]
                
                var seenPaths = Set<String>()
                for dir in searchDirs {
                    guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                    for url in contents where url.pathExtension == "app" {
                        if url.lastPathComponent.contains("LaunchCloak") { continue }
                        if seenPaths.insert(url.path).inserted {
                            installed.append(AppItem(url: url, isHidden: false))
                        }
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
    
    /// 隐藏指定应用：原地原地顺滑移除，不重置滚动位置
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
        
        var moveSucceeded = false
        
        do {
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.moveItem(at: item.url, to: targetURL)
            moveSucceeded = true
        } catch {
            let success = moveWithPrivileges(from: item.url.path, to: targetURL.path)
            if success {
                moveSucceeded = true
            } else {
                self.errorMessage = "隐藏失败：无法移动 \(item.name)，可能受 macOS 权限或系统保护限制。"
                self.records.removeValue(forKey: fileName)
                self.saveMetadata()
            }
        }
        
        if moveSucceeded {
            notifySystemChange(at: targetURL, original: item.url)
            syncLaunchpad(
                unregisteredPath: item.url.path,
                bundleId: item.bundleIdentifier,
                title: item.name,
                fileNameWithoutExt: item.url.deletingPathExtension().lastPathComponent,
                shouldRestartDock: true
            )
            
            // 原地动画移除当前行，滚动位置纹丝不动
            withAnimation(.snappy(duration: 0.25)) {
                self.installedApps.removeAll { $0.id == item.id }
                let hiddenItem = AppItem(url: targetURL, isHidden: true)
                self.hiddenApps.append(hiddenItem)
                self.hiddenApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
    }
    
    /// 恢复指定应用：原地顺滑移除，不重置滚动位置
    public func restoreApp(_ item: AppItem) {
        let fm = FileManager.default
        let fileName = item.url.lastPathComponent
        
        let destinationPath = self.records[fileName]?.originalPath ?? "/Applications/\(fileName)"
        let targetURL = URL(fileURLWithPath: destinationPath)
        
        var moveSucceeded = false
        
        do {
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.moveItem(at: item.url, to: targetURL)
            moveSucceeded = true
        } catch {
            let success = moveWithPrivileges(from: item.url.path, to: targetURL.path)
            if success {
                moveSucceeded = true
            } else {
                self.errorMessage = "恢复失败：无法还原 \(item.name) 到原路径。"
            }
        }
        
        if moveSucceeded {
            self.records.removeValue(forKey: fileName)
            self.saveMetadata()
            notifySystemChange(at: targetURL, original: item.url)
            syncLaunchpad(
                registeredPath: targetURL.path,
                shouldRestartDock: true
            )
            
            // 原地动画从隐藏列表移出，平滑放入已安装列表
            withAnimation(.snappy(duration: 0.25)) {
                self.hiddenApps.removeAll { $0.id == item.id }
                let restoredItem = AppItem(url: targetURL, isHidden: false)
                self.installedApps.append(restoredItem)
                self.installedApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
    }
    
    /// 恢复所有已隐藏应用（智能合并提权，最多只弹一次系统密码授权）
    public func restoreAll() {
        let fm = FileManager.default
        var remainingPrivilegedMoves: [(item: AppItem, source: String, dest: String, fileName: String)] = []
        var successfullyRestored: [(item: AppItem, targetURL: URL, fileName: String)] = []
        
        let appsToRestore = self.hiddenApps
        
        // 1. 第一阶段：先尝试常规无特权静默移动（普通第三方应用在此完成，0 弹窗）
        for item in appsToRestore {
            let fileName = item.url.lastPathComponent
            let destinationPath = self.records[fileName]?.originalPath ?? "/Applications/\(fileName)"
            let targetURL = URL(fileURLWithPath: destinationPath)
            
            do {
                if fm.fileExists(atPath: targetURL.path) {
                    try fm.removeItem(at: targetURL)
                }
                try fm.moveItem(at: item.url, to: targetURL)
                successfullyRestored.append((item, targetURL, fileName))
            } catch {
                // 需要 root 权限的系统应用收集起来集中处理
                remainingPrivilegedMoves.append((item, item.url.path, destinationPath, fileName))
            }
        }
        
        // 2. 第二阶段：如果存在需要管理员权限的系统应用，打包合并为单次提权批处理脚本（只弹一次密码）
        if !remainingPrivilegedMoves.isEmpty {
            var shellCommands: [String] = []
            for move in remainingPrivilegedMoves {
                let escapedSource = move.source.replacingOccurrences(of: "\"", with: "\\\"")
                let escapedDest = move.dest.replacingOccurrences(of: "\"", with: "\\\"")
                shellCommands.append("rm -rf \\\"\(escapedDest)\\\" 2>/dev/null; mv \\\"\(escapedSource)\\\" \\\"\(escapedDest)\\\"")
            }
            
            let combinedCommand = shellCommands.joined(separator: "; ")
            let appleScriptSource = "do shell script \"\(combinedCommand)\" with administrator privileges"
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    // 全部批量恢复成功
                    for move in remainingPrivilegedMoves {
                        successfullyRestored.append((move.item, URL(fileURLWithPath: move.dest), move.fileName))
                    }
                } else {
                    self.errorMessage = "批量恢复部分系统应用受阻：用户取消了授权或权限不足。"
                }
            }
        }
        
        // 3. 第三阶段：清理元数据、更新列表与刷新视图
        for restored in successfullyRestored {
            self.records.removeValue(forKey: restored.fileName)
            notifySystemChange(at: restored.targetURL, original: restored.item.url)
            syncLaunchpad(registeredPath: restored.targetURL.path, shouldRestartDock: false)
        }
        self.saveMetadata()
        
        // 批量恢复完成后，统一重启一次 Dock 刷新 Launchpad
        if !successfullyRestored.isEmpty {
            let killDock = Process()
            killDock.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killDock.arguments = ["Dock"]
            try? killDock.run()
        }
        
        withAnimation(.snappy(duration: 0.25)) {
            for restored in successfullyRestored {
                self.hiddenApps.removeAll { $0.id == restored.item.id }
                let restoredItem = AppItem(url: restored.targetURL, isHidden: false)
                self.installedApps.append(restoredItem)
            }
            self.installedApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
        Process.launchedProcess(launchPath: "/usr/bin/touch", arguments: [target.path])
        Process.launchedProcess(launchPath: "/usr/bin/touch", arguments: [original.deletingLastPathComponent().path])
    }
    
    /// 强力同步 Launchpad 启动台与 Dock 状态，确保隐藏/恢复即刻反映在启动台上
    private func syncLaunchpad(
        unregisteredPath: String? = nil,
        registeredPath: String? = nil,
        bundleId: String? = nil,
        title: String? = nil,
        fileNameWithoutExt: String? = nil,
        shouldRestartDock: Bool = true
    ) {
        // 1. LaunchServices 注销或重新注册
        if let unreg = unregisteredPath {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
            p.arguments = ["-u", unreg]
            try? p.run()
            p.waitUntilExit()
        }
        
        if let reg = registeredPath {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
            p.arguments = ["-f", reg]
            try? p.run()
            p.waitUntilExit()
        }
        
        // 2. 如果存在 Launchpad 数据库（macOS 15 及更早系统），直接从 SQLite 中清除记录，避免残留幽灵图标
        if bundleId != nil || title != nil || fileNameWithoutExt != nil {
            deleteAppFromLaunchpadDB(bundleId: bundleId, title: title, fileNameWithoutExt: fileNameWithoutExt)
        }
        
        // 3. 重启 Dock（Dock 负责绘制 Launchpad，重启仅耗时约 0.1 秒，立即重绘并移除图标）
        if shouldRestartDock {
            let killDock = Process()
            killDock.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killDock.arguments = ["Dock"]
            try? killDock.run()
        }
    }
    
    /// 从 Launchpad SQLite 数据库中精准剔除应用记录
    private func deleteAppFromLaunchpadDB(bundleId: String?, title: String?, fileNameWithoutExt: String?) {
        var conditions: [String] = []
        if let bid = bundleId, !bid.isEmpty {
            let escapedBid = bid.replacingOccurrences(of: "'", with: "''")
            conditions.append("bundleid='\(escapedBid)'")
        }
        if let t = title, !t.isEmpty {
            let escapedT = t.replacingOccurrences(of: "'", with: "''")
            conditions.append("title='\(escapedT)'")
        }
        if let fn = fileNameWithoutExt, !fn.isEmpty {
            let escapedFn = fn.replacingOccurrences(of: "'", with: "''")
            conditions.append("title='\(escapedFn)'")
        }
        
        guard !conditions.isEmpty else { return }
        let whereClause = conditions.joined(separator: " OR ")
        
        let script = """
        LP_DIR=$(find /private/var/folders -name com.apple.dock.launchpad -user $(id -u) 2>/dev/null | head -n 1)
        if [ -n "$LP_DIR" ] && [ -f "$LP_DIR/db/db" ]; then
            sqlite3 "$LP_DIR/db/db" "DELETE FROM apps WHERE \(whereClause);" 2>/dev/null
            sqlite3 "$LP_DIR/db/db" "DELETE FROM items WHERE rowid NOT IN (SELECT item_id FROM apps UNION SELECT item_id FROM groups) AND type = 4;" 2>/dev/null
        fi
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", script]
        try? p.run()
        p.waitUntilExit()
    }
}
