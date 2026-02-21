import AppKit
import Carbon.HIToolbox
import ApplicationServices

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    var onStatusMessage: ((String) -> Void)?
    var isEnabled = true

    private let hotkeyID = EventHotKeyID(signature: GlobalHotkeyManager.fourCharCode("WYCL"), id: 1)
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyEventHandler: EventHandlerRef?

    private let debounceInterval: TimeInterval = 0.3
    private let pollInterval: TimeInterval = 0.1
    private let maxPollAttempts = 15
    private var lastTriggerTime: Date = .distantPast
    private var isProcessing = false

    deinit {
        stopListening()
    }

    func startListening() {
        guard hotkeyRef == nil else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let eventInstallStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(eventRef)
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotkeyEventHandler
        )

        guard eventInstallStatus == noErr else {
            postStatus("快捷键监听注册失败：\(eventInstallStatus)")
            return
        }

        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(optionKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if registerStatus == noErr {
            postStatus("快捷键已启用：⌥C")
        } else {
            postStatus("快捷键注册失败：\(registerStatus)")
        }
    }

    func stopListening() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        if let hotkeyEventHandler {
            RemoveEventHandler(hotkeyEventHandler)
            self.hotkeyEventHandler = nil
        }
    }

    private func handleHotKeyEvent(_ eventRef: EventRef?) {
        guard isEnabled else {
            postStatus("清洗功能已关闭")
            return
        }

        guard !isProcessing else {
            postStatus("正在处理上一次复制，请稍候")
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= debounceInterval else { return }

        var incomingHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &incomingHotKeyID
        )

        guard status == noErr,
              incomingHotKeyID.id == hotkeyID.id,
              incomingHotKeyID.signature == hotkeyID.signature else {
            return
        }

        guard AXIsProcessTrusted() else {
            postStatus("请先在系统设置中授予 WYClean 辅助功能权限")
            return
        }

        isProcessing = true
        lastTriggerTime = now

        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        simulateSystemCopy()
        waitForClipboardUpdate(previousChangeCount: previousChangeCount, attemptsLeft: maxPollAttempts)
    }

    private func waitForClipboardUpdate(previousChangeCount: Int, attemptsLeft: Int) {
        let pasteboard = NSPasteboard.general

        if pasteboard.changeCount != previousChangeCount,
           let rawText = pasteboard.string(forType: .string),
           !rawText.isEmpty {
            processClipboardText(rawText)
            isProcessing = false
            return
        }

        guard attemptsLeft > 0 else {
            postStatus("未检测到新的复制内容，请确认目标应用支持 ⌘C")
            isProcessing = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { [weak self] in
            self?.waitForClipboardUpdate(previousChangeCount: previousChangeCount, attemptsLeft: attemptsLeft - 1)
        }
    }

    private func simulateSystemCopy() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            postStatus("无法模拟 ⌘C，请检查辅助功能权限")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func processClipboardText(_ rawText: String) {
        let pasteboard = NSPasteboard.general
        let cleanedText = TextCleaningService().clean(rawText)

        guard !cleanedText.isEmpty else {
            postStatus("清洗结果为空，保留原剪贴板")
            return
        }

        pasteboard.clearContents()
        if pasteboard.setString(cleanedText, forType: .string) {
            postStatus("已复制并清洗，可直接 ⌘V 粘贴")
        } else {
            postStatus("写入剪贴板失败")
        }
    }

    private func postStatus(_ message: String) {
        if let onStatusMessage {
            onStatusMessage(message)
        } else {
            NSLog("[GlobalHotkeyManager] %@", message)
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
