import SwiftUI
import AppKit

public enum AppTab: String, CaseIterable, Identifiable {
    case installed = "全部应用"
    case hidden = "已隐藏"
    
    public var id: String { rawValue }
}

public struct MainContentView: View {
    @ObservedObject var manager: AppManager
    @StateObject private var settings = SettingsManager()
    @State private var selectedTab: AppTab = .installed
    @State private var searchText: String = ""
    @State private var hoveredAppId: String? = nil
    @State private var pendingActionAppId: String? = nil
    @State private var isShowingSettings: Bool = false
    
    public init(manager: AppManager) {
        self.manager = manager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部标题栏 (Title + Menu)
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
            
            // 2. 分段切换胶囊 (Full-width Segmented Tabs)
            tabSelectorView
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            
            // 3. 搜索栏
            searchBarView
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            
            Divider()
                .opacity(0.3)
            
            // 4. 应用列表
            contentListView
            
            Divider()
                .opacity(0.3)
            
            // 5. 底部状态与安全背书提示
            footerView
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 380, height: 500)
        .background(.regularMaterial)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(settings: settings, manager: manager)
        }
    }
    
    // MARK: - Header (Title & Action Menu)
    private var headerView: some View {
        HStack(spacing: 8) {
            // 品牌图标与标题
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                
                Text("LaunchCloak")
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .fixedSize()
            }
            
            Spacer()
            
            // 右上角 "···" 更多菜单
            Menu {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("偏好设置...", systemImage: "gearshape")
                }
                
                if settings.requireAuthForHiddenTab && settings.isHiddenTabUnlocked {
                    Button {
                        settings.lockHiddenTab()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedTab = .installed
                        }
                    } label: {
                        Label("锁定“已隐藏”标签", systemImage: "lock.fill")
                    }
                }
                
                Divider()
                
                Button {
                    manager.openHiddenFolder()
                } label: {
                    Label("在访达中打开隐藏目录", systemImage: "folder")
                }
                
                Button {
                    manager.refresh(showLoading: true)
                } label: {
                    Label("刷新应用列表", systemImage: "arrow.clockwise")
                }
                
                if !manager.hiddenApps.isEmpty {
                    Divider()
                    Button(role: .destructive) {
                        manager.restoreAll()
                    } label: {
                        Label("一键恢复所有隐藏应用", systemImage: "arrow.uturn.backward.circle")
                    }
                }
                
                Divider()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出 LaunchCloak", systemImage: "power")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
    
    // MARK: - Full-width Tab Selector
    private var tabSelectorView: some View {
        HStack(spacing: 4) {
            tabButton(title: "全部应用", count: manager.installedApps.count, tab: .installed)
            tabButton(title: "已隐藏", count: manager.hiddenApps.count, tab: .hidden)
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func tabButton(title: String, count: Int, tab: AppTab) -> some View {
        Button {
            handleTabSwitch(to: tab)
        } label: {
            HStack(spacing: 6) {
                // 如果开启了密码保护，在已隐藏标签旁显示锁状态图标
                if tab == .hidden && settings.requireAuthForHiddenTab {
                    Image(systemName: settings.isHiddenTabUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(settings.isHiddenTabUnlocked ? Color.accentColor : Color.secondary)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selectedTab == tab
                ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                : nil
            )
            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func handleTabSwitch(to tab: AppTab) {
        if tab == .hidden && settings.requireAuthForHiddenTab && !settings.isHiddenTabUnlocked {
            Task {
                let success = await settings.authenticate(reason: "请验证以访问已隐藏的应用列表")
                if success {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedTab = .hidden
                    }
                }
            }
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                selectedTab = tab
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            
            TextField(selectedTab == .installed ? "搜索要隐藏的应用..." : "搜索已隐藏的应用...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Content List
    private var filteredApps: [AppItem] {
        let baseList = selectedTab == .installed ? manager.installedApps : manager.hiddenApps
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return baseList
        }
        return baseList.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    @ViewBuilder
    private var contentListView: some View {
        if manager.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("正在扫描应用列表...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredApps.isEmpty {
            emptyStateView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { item in
                        appRow(item: item)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
            }
        }
    }
    
    // MARK: - App Row (8 States)
    private func appRow(item: AppItem) -> some View {
        let isHovered = hoveredAppId == item.id
        let isProcessing = pendingActionAppId == item.id
        
        return HStack(spacing: 10) {
            // App 图标
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
            
            // 名称与标识
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(item.isSystemProtected ? Color.secondary : Color.primary)
                    .lineLimit(1)
                
                Text(item.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 操作按钮
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 50, height: 24)
            } else if item.isSystemProtected {
                Text("系统核心")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
            } else if selectedTab == .installed {
                // 隐藏按钮
                Button {
                    executeHide(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 10))
                        Text("隐藏")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHovered ? Color.red.opacity(0.12) : Color.primary.opacity(0.05))
                    .foregroundStyle(isHovered ? Color.red : Color.secondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // 恢复按钮
                Button {
                    executeRestore(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                        Text("恢复")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHovered ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredAppId = hovering ? item.id : nil
            }
        }
    }
    
    private func executeHide(_ item: AppItem) {
        pendingActionAppId = item.id
        Task {
            manager.hideApp(item)
            pendingActionAppId = nil
        }
    }
    
    private func executeRestore(_ item: AppItem) {
        pendingActionAppId = item.id
        Task {
            manager.restoreApp(item)
            pendingActionAppId = nil
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedTab == .hidden ? "sparkles" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            
            Text(selectedTab == .hidden ? "没有隐藏的应用" : "未找到匹配的应用")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text(selectedTab == .hidden ? "在“全部应用”中点击“隐藏”，即可从启动台隐匿图标。" : "换个关键词试试。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Text("已隔离至 .noindex 目录 · 数据无损且随时可恢复")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            
            Spacer()
            
            Button {
                manager.openHiddenFolder()
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("打开隐藏文件夹")
        }
    }
}
