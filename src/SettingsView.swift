import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var manager: AppManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAuthError: Bool = false
    
    public init(settings: SettingsManager, manager: AppManager) {
        self.settings = settings
        self.manager = manager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Text("偏好设置")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.3)
            
            // 设置项列表
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 通用设置：开机自启动
                    settingSection(title: "通用") {
                        VStack(spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("开机时自动启动")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("登录系统后自动在顶部菜单栏常驻运行")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { settings.isLaunchAtLoginEnabled },
                                    set: { newValue in
                                        settings.setLaunchAtLogin(enabled: newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                        }
                    }
                    
                    // 2. 隐私与安全：访问已隐藏标签页锁屏密码验证
                    settingSection(title: "隐私与安全") {
                        VStack(spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("访问“已隐藏”标签需密码验证")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("开启后，切换到已隐藏列表必须验证 Touch ID 或锁屏密码")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { settings.requireAuthForHiddenTab },
                                    set: { newValue in
                                        handleAuthToggle(newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                            
                            if settings.requireAuthForHiddenTab {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                    Text("已启用系统级 LocalAuthentication 安全保护")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    
                    // 3. 数据与文件管理
                    settingSection(title: "存储与隔离") {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("隔离存储目录")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("~/.hidden_apps.noindex")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Spacer()
                                
                                Button("在访达中打开") {
                                    manager.openHiddenFolder()
                                }
                                .font(.system(size: 11))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    // 4. 关于 LaunchCloak
                    VStack(spacing: 4) {
                        Text("LaunchCloak v1.1.0")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Link("GitHub 仓库与反馈", destination: URL(string: "https://github.com/a916791360/LaunchCloak")!)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .frame(width: 380, height: 420)
        .background(.regularMaterial)
    }
    
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack {
                content()
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
    
    private func handleAuthToggle(_ newValue: Bool) {
        if newValue {
            // 开启时，立即要求验证一次作为确认
            Task {
                let success = await settings.authenticate(reason: "请验证以启用已隐藏应用的访问密码保护")
                if success {
                    settings.requireAuthForHiddenTab = true
                }
            }
        } else {
            // 关闭时，必须验证当前机主身份，防止他人偷偷关闭
            Task {
                let success = await settings.authenticate(reason: "关闭密码保护需验证机主身份")
                if success {
                    settings.requireAuthForHiddenTab = false
                    settings.isHiddenTabUnlocked = false
                }
            }
        }
    }
}
