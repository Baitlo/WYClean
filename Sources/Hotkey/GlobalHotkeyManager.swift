import AppKit
import Carbon.HIToolbox
import Foundation

final class GlobalHotkeyManager {
    struct CleaningOptions {
        var autoRemoveLineBreaks: Bool = true
        var preserveEnglishWordSpacing: Bool = true
    }

    static let shared = GlobalHotkeyManager()

    /// 菜单栏可绑定此回调用于展示状态消息；默认使用日志输出。
    var onStatusMessage: ((String) -> Void)?
    var options = CleaningOptions()

    private let hotkeyID = EventHotKeyID(signature: GlobalHotkeyManager.fourCharCode("WYCL"), id: 1)
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyEventHandler: EventHandlerRef?

    private let copyDelay: TimeInterval = 0.12
    private let debounceInterval: TimeInterval = 0.35
    private var lastTriggerTime: Date = .distantPast
    private var isProcessing = false

    private let cleaner: (String, CleaningOptions) -> String

    init(cleaner: @escaping (String, CleaningOptions) -> String = { text, options in
        TextCleaningService.clean(text, options: options)
    }) {
        self.cleaner = cleaner
    }

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

        // Option + C
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
        guard !isProcessing else {
            postStatus("正在处理上一次复制内容，请稍候")
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= debounceInterval else {
            return
        }

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

        guard status == noErr, incomingHotKeyID.id == hotkeyID.id, incomingHotKeyID.signature == hotkeyID.signature else {
            return
        }

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
            postStatus("无法模拟 ⌘C，请检查权限")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func processClipboardText() {
        let pasteboard = NSPasteboard.general

        guard let rawText = pasteboard.string(forType: .string), !rawText.isEmpty else {
            postStatus("剪贴板中没有可处理文本，已跳过")
            return
        }

        let cleanedText = cleaner(rawText, options)

        guard !cleanedText.isEmpty else {
            postStatus("清洗结果为空，保留原剪贴板内容")
            return
        }

        pasteboard.clearContents()
        let didWrite = pasteboard.setString(cleanedText, forType: .string)

        if didWrite {
            postStatus("文本已清洗并写回剪贴板")
        } else {
            postStatus("写入剪贴板失败，可能被系统拒绝")
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

enum TextCleaningService {
    static func clean(_ text: String, options: GlobalHotkeyManager.CleaningOptions) -> String {
        var output = text

        if options.autoRemoveLineBreaks {
            output = output
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\n", with: " ")
        }

        output = output.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        if !options.preserveEnglishWordSpacing {
            output = output.replacingOccurrences(
                of: #"(?<=[A-Za-z])\s+(?=[A-Za-z])"#,
                with: "",
                options: .regularExpression
            )
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
