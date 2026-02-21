import AppKit
import Carbon.HIToolbox

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    var onStatusMessage: ((String) -> Void)?
    var isEnabled = true

    private let hotkeyID = EventHotKeyID(signature: GlobalHotkeyManager.fourCharCode("WYCL"), id: 1)
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyEventHandler: EventHandlerRef?

    private let copyDelay: TimeInterval = 0.12
    private let debounceInterval: TimeInterval = 0.3
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

        let registerStatus = RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(optionKey), hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)

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

        guard !isProcessing else { return }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= debounceInterval else { return }

        var incomingHotKeyID = EventHotKeyID()
        let status = GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &incomingHotKeyID)
        guard status == noErr, incomingHotKeyID.id == hotkeyID.id, incomingHotKeyID.signature == hotkeyID.signature else { return }

        isProcessing = true
        lastTriggerTime = now
        simulateSystemCopy()

        DispatchQueue.main.asyncAfter(deadline: .now() + copyDelay) { [weak self] in
            self?.processClipboardText()
            self?.isProcessing = false
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

    private func processClipboardText() {
        let pasteboard = NSPasteboard.general
        guard let rawText = pasteboard.string(forType: .string), !rawText.isEmpty else { return }

        let cleanedText = TextCleaningService().clean(rawText)
        guard !cleanedText.isEmpty else { return }

        pasteboard.clearContents()
        if pasteboard.setString(cleanedText, forType: .string) {
            postStatus("已复制并清洗，可直接 ⌘V 粘贴")
        } else {
            postStatus("写入剪贴板失败")
        }
    }

    private func postStatus(_ message: String) {
        onStatusMessage?(message)
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
