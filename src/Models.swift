import AppKit
import Foundation

/// 代表一个应用程序项
public struct AppItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String
    public let url: URL
    public let icon: NSImage
    public let isSystemProtected: Bool
    public var isHidden: Bool
    
    public init(url: URL, isHidden: Bool = false) {
        self.url = url
        self.id = url.path
        self.isHidden = isHidden
        
        let bundle = Bundle(url: url)
        self.bundleIdentifier = bundle?.bundleIdentifier ?? url.lastPathComponent
        
        let displayName = FileManager.default.displayName(atPath: url.path)
        self.name = displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
        
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // 检查是否为 /System 只读受保护应用
        self.isSystemProtected = url.path.hasPrefix("/System/") || url.path.hasPrefix("/System/Applications/")
    }
    
    public static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 隐藏记录元数据
public struct HiddenAppRecord: Codable {
    public let bundleIdentifier: String
    public let appName: String
    public let originalPath: String
    public let hiddenDate: Date
}
