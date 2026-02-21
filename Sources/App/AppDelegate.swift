import AppKit
import ApplicationServices

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        requestAccessibilityPermissionIfNeeded()
        showPasteboardUsageNoticeIfNeeded()

        statusBarController = StatusBarController()

        GlobalHotkeyManager.shared.onStatusMessage = { [weak self] message in
            self?.statusBarController?.updateStatus(message)
        }
        GlobalHotkeyManager.shared.startListening()
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.stopListening()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func showPasteboardUsageNoticeIfNeeded() {
        let hasShownNoticeKey = "PasteboardUsageNoticeShown"
        guard !UserDefaults.standard.bool(forKey: hasShownNoticeKey) else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "首次使用说明"
        alert.informativeText = "请在任意应用中选中 PDF 文本后按 ⌥C，WYClean 会先执行复制，再自动清洗文本并回写剪贴板。"
        alert.addButton(withTitle: "我知道了")
        alert.runModal()

        UserDefaults.standard.set(true, forKey: hasShownNoticeKey)
    }
}
