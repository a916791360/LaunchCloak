import AppKit
import Foundation
import Combine

/// GitHub Release 数据模型
public struct GitHubReleaseInfo: Codable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

/// 负责从 GitHub Releases 检测新版本并引导下载更新
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()
    
    @Published public var isChecking: Bool = false
    @Published public var lastCheckTime: Date? = nil
    @Published public var statusMessage: String? = nil
    
    private let repoOwner = "a916791360"
    private let repoName = "LaunchCloak"
    private let lastCheckKey = "lastUpdateCheckTimestamp"
    
    private init() {}
    
    /// 获取当前 App 版本号 (如 "1.1.3")
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.3"
    }
    
    /// 检测更新
    /// - Parameter explicit: 是否为用户主动点击检测（主动检测在无更新或失败时会弹窗提示；后台自动检查则保持静默）
    public func checkForUpdates(explicit: Bool = false) {
        guard !isChecking else { return }
        
        // 如果是后台静默检查，增加 24 小时频次冷却保护，确保绝不频繁请求网络
        if !explicit {
            let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
            let now = Date().timeIntervalSince1970
            // 24 小时 (86400 秒) 内已检查过则直接跳过，零网络与资源消耗
            if lastCheck > 0 && (now - lastCheck) < 86400 {
                return
            }
        }
        
        isChecking = true
        statusMessage = "正在检查更新..."
        
        Task {
            defer {
                self.isChecking = false
                self.lastCheckTime = Date()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastCheckKey)
            }
            
            guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
                if explicit {
                    showErrorAlert(message: "更新接口地址无效。")
                }
                self.statusMessage = nil
                return
            }
            
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("LaunchCloak-App", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    if explicit {
                        showErrorAlert(message: "服务器响应异常。")
                    }
                    self.statusMessage = nil
                    return
                }
                
                if httpResponse.statusCode == 404 {
                    if explicit {
                        showUpToDateAlert(currentVersion: currentVersion)
                    }
                    self.statusMessage = "已是最新版本"
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    if explicit {
                        showErrorAlert(message: "GitHub 服务状态码异常 (\(httpResponse.statusCode))，请稍后再试。")
                    }
                    self.statusMessage = nil
                    return
                }
                
                let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
                let remoteVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
                let current = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
                
                if Self.isVersion(remoteVersion, newerThan: current) {
                    self.statusMessage = "发现新版本 \(release.tagName)"
                    showUpdateAvailableAlert(release: release, currentVersion: current)
                } else {
                    self.statusMessage = "已是最新版本"
                    if explicit {
                        showUpToDateAlert(currentVersion: current)
                    }
                }
            } catch {
                if explicit {
                    showErrorAlert(message: "网络连接失败，无法连接到 GitHub 检查更新：\n\(error.localizedDescription)")
                }
                self.statusMessage = nil
            }
        }
    }
    
    /// 语义化版本号比对：判断 remote 是否大于 local
    public static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localParts = cleanLocal.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
    
    // MARK: - 弹窗提示
    
    /// 发现新版本时弹出引导
    private func showUpdateAvailableAlert(release: GitHubReleaseInfo, currentVersion: String) {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        let remoteTag = release.tagName.hasPrefix("v") || release.tagName.hasPrefix("V") ? release.tagName : "v\(release.tagName)"
        alert.messageText = "🎉 发现 LaunchCloak 新版本 (\(remoteTag))"
        
        var message = "您当前运行的版本为 v\(currentVersion)，最新版本为 \(remoteTag)。"
        if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message += "\n\n更新日志：\n\(body.prefix(600))"
            if body.count > 600 {
                message += "\n..."
            }
        }
        
        alert.informativeText = message
        alert.addButton(withTitle: "前往下载更新")
        alert.addButton(withTitle: "稍后提醒")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// 已是最新版本提示
    private func showUpToDateAlert(currentVersion: String) {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "已是最新版本"
        alert.informativeText = "您当前使用的 LaunchCloak (v\(currentVersion)) 已经是最新的正式版本，无需更新。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    
    /// 检查失败提示
    private func showErrorAlert(message: String) {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
