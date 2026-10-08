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
        
        // 解析官方本地化中文名称 (优先取 zh-Hans / 当前系统语言)
        self.name = Self.resolveDisplayName(for: url, bundle: bundle)
        
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // 检查是否为 /System 只读受保护应用
        self.isSystemProtected = url.path.hasPrefix("/System/") || url.path.hasPrefix("/System/Applications/")
    }
    
    /// 获取应用真实显示名称（如：aDrive -> 阿里云盘，WeChat -> 微信，DingTalk -> 钉钉）
    private static func resolveDisplayName(for url: URL, bundle: Bundle?) -> String {
        if let bundle = bundle {
            // 1. 尝试从当前系统首选语言的本地化资源包 (zh-Hans.lproj/InfoPlist.strings) 获取
            let prefLangs = Locale.preferredLanguages
            if let loc = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: prefLangs).first,
               let stringsPath = bundle.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: loc),
               let dict = NSDictionary(contentsOfFile: stringsPath) {
                if let name = (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String),
                   !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    return name
                }
            }
            
            // 2. 尝试从应用主 Info.plist 获取
            if let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                          (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String),
               !name.trimmingCharacters(in: .whitespaces).isEmpty {
                return name
            }
        }
        
        // 3. 回退到文件系统显示名
        let fmName = FileManager.default.displayName(atPath: url.path)
        return fmName.hasSuffix(".app") ? String(fmName.dropLast(4)) : fmName
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
