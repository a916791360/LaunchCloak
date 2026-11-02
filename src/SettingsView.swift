import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var manager: AppManager
    @ObservedObject private var updateChecker = UpdateChecker.shared
    var onClose: (() -> Void)? = nil
    
    public init(settings: SettingsManager, manager: AppManager, onClose: (() -> Void)? = nil) {
        self.settings = settings
        self.manager = manager
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Text("偏好设置")
                    .font(.system(size: 15, weight: .bold))
                
                Spacer()
                
                if let onClose = onClose {
                    Button("完成") {
                        onClose()
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.3)
            
            // 设置项列表
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 通用设置：开机自启动与更新检测
                    settingSection(title: "通用") {
                        VStack(spacing: 12) {
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
                                .tint(.blue)
                                .labelsHidden()
                            }
                            
                            Divider().opacity(0.3)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("启动时自动检查更新")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("启动时检测 GitHub 最新版本，若有新版弹窗提醒")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $settings.autoCheckUpdates)
                                    .toggleStyle(.switch)
                                    .tint(.blue)
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
                                .tint(.blue)
                                .labelsHidden()
                            }
                            
                            if settings.requireAuthForHiddenTab {
                                HStack(spacing: 6) {
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
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("LaunchCloak v\(updateChecker.currentVersion)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Button {
                                updateChecker.checkForUpdates(explicit: true)
                            } label: {
                                if updateChecker.isChecking {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 14, height: 14)
                                } else {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 9))
                                        Text("检查更新")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(updateChecker.isChecking)
                        }
                        
                        if let status = updateChecker.statusMessage {
                            Text(status)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        
                        Text("轻量级启动台图标隐藏与隐私管理工具 · 开源免费")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.top, 10)
                }
                .padding(18)
            }
        }
        .frame(width: 400, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
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
            // 开启密码保护：直接开启，即时生效
            settings.requireAuthForHiddenTab = true
        } else {
            // 关闭密码保护：必须验证机主身份，防范未经授权关闭
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
