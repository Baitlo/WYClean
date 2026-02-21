import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var isCleaningEnabled = true {
        didSet { updateToggleMenuItemTitle() }
    }

    private lazy var toggleMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "关闭清洗", action: #selector(toggleCleaning), keyEquivalent: "")
        item.target = self
        return item
    }()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusButton()
        configureMenu()
    }

    private func configureStatusButton() {
        statusItem.button?.title = "WYClean"
        statusItem.button?.toolTip = "WYClean 菜单"
    }

    private func configureMenu() {
        let menu = NSMenu()
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
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
