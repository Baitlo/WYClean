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
        alert.messageText = "需要剪贴板访问说明"
        alert.informativeText = "WYClean 会读取剪贴板内容用于后续文本清洗功能。应用不会在未触发清洗时主动上传你的剪贴板内容。"
        alert.addButton(withTitle: "我知道了")
        alert.runModal()

        UserDefaults.standard.set(true, forKey: hasShownNoticeKey)
    }
}
