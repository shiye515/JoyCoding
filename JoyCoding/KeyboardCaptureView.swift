import AppKit
import SwiftUI

struct KeyboardCaptureState: Equatable {
    private(set) var seenModifierCodes: Set<UInt16> = []
    private(set) var pressedModifierCodes: Set<UInt16> = []
    private(set) var error: String?
    mutating func start() { seenModifierCodes = []; pressedModifierCodes = []; error = nil }
    mutating func keyDown(code: UInt16, flags: NSEvent.ModifierFlags, isRepeat: Bool) -> KeyboardBinding? {
        guard !isRepeat else { return nil }
        return KeyboardBinding(keyCode: code, modifiers: KeyboardKeyCatalog.modifiers(from: flags))
    }
    mutating func flagsChanged(code: UInt16, flags: NSEvent.ModifierFlags) -> KeyboardBinding? {
        guard KeyboardKeyCatalog.modifier(for: code) != nil else { return nil }
        let isDown = flags.contains(modifierFlag(for: code))
        if isDown { seenModifierCodes.insert(code); pressedModifierCodes.insert(code); return nil }
        pressedModifierCodes.remove(code)
        guard pressedModifierCodes.isEmpty else { return nil }
        if seenModifierCodes.count == 1, let only = seenModifierCodes.first { return KeyboardBinding(keyCode: only) }
        if seenModifierCodes.count > 1 { error = "组合键需要一个非修饰主键" }
        return nil
    }
    private func modifierFlag(for code: UInt16) -> NSEvent.ModifierFlags {
        switch KeyboardKeyCatalog.modifier(for: code) { case .command: return .command; case .option: return .option; case .control: return .control; case .shift: return .shift; default: return [] }
    }
}

struct KeyboardCaptureView: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onBinding: (KeyboardBinding) -> Void
    let onError: (String?) -> Void
    func makeNSView(context: Context) -> CaptureNSView { CaptureNSView(coordinator: context.coordinator) }
    func updateNSView(_ view: CaptureNSView, context: Context) {
        context.coordinator.onBinding = onBinding; context.coordinator.onError = onError
        if isCapturing {
            guard view.window?.firstResponder !== view else { return }
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        } else if view.window?.firstResponder === view {
            DispatchQueue.main.async { view.window?.makeFirstResponder(nil) }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(isCapturing: $isCapturing) }
    final class Coordinator {
        var state = KeyboardCaptureState(); var isCapturing: Binding<Bool>; var onBinding: (KeyboardBinding) -> Void = { _ in }; var onError: (String?) -> Void = { _ in }
        init(isCapturing: Binding<Bool>) { self.isCapturing = isCapturing }
        func begin() { state.start(); onError(nil) }
        func finish(_ binding: KeyboardBinding) { onBinding(binding); isCapturing.wrappedValue = false }
    }
}

final class CaptureNSView: NSView {
    let coordinator: KeyboardCaptureView.Coordinator
    init(coordinator: KeyboardCaptureView.Coordinator) { self.coordinator = coordinator; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { coordinator.begin(); return true }
    override func resignFirstResponder() -> Bool { coordinator.isCapturing.wrappedValue = false; return true }
    override func keyDown(with event: NSEvent) {
        guard coordinator.isCapturing.wrappedValue else { return }
        if let binding = coordinator.state.keyDown(code: UInt16(event.keyCode), flags: event.modifierFlags, isRepeat: event.isARepeat) { coordinator.finish(binding) }
    }
    override func flagsChanged(with event: NSEvent) {
        guard coordinator.isCapturing.wrappedValue else { return }
        if let binding = coordinator.state.flagsChanged(code: UInt16(event.keyCode), flags: event.modifierFlags) { coordinator.finish(binding) }
        coordinator.onError(coordinator.state.error)
    }
}
