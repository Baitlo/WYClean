import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var isCleaningEnabled = true {
        didSet {
            updateToggleMenuItemTitle()
            GlobalHotkeyManager.shared.isEnabled = isCleaningEnabled
        }
    }

    private lazy var toggleMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "关闭清洗", action: #selector(toggleCleaning), keyEquivalent: "")
        item.target = self
        return item
    }()

    private lazy var statusMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "状态：待命", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusButton()
        configureMenu()
    }

    func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.statusMenuItem.title = "状态：\(status)"
        }
    }

    private func configureStatusButton() {
        statusItem.button?.title = "WYClean"
        statusItem.button?.toolTip = "WYClean 已在后台运行"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())

        let quitMenuItem = NSMenuItem(title: "退出", action: #selector(quitApplication), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    private func updateToggleMenuItemTitle() {
        toggleMenuItem.title = isCleaningEnabled ? "关闭清洗" : "开启清洗"
    }

    @objc private func toggleCleaning() {
        isCleaningEnabled.toggle()
        updateStatus(isCleaningEnabled ? "清洗功能已开启" : "清洗功能已关闭")
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
