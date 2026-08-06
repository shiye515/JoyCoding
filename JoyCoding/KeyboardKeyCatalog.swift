import AppKit
import Carbon.HIToolbox

enum KeyboardKeyCatalog {
    static let modifierCodes: [(KeyboardModifiers, UInt16)] = [
        (.control, UInt16(kVK_Control)), (.option, UInt16(kVK_Option)),
        (.shift, UInt16(kVK_Shift)), (.command, UInt16(kVK_Command))
    ]

    static func modifiers(from flags: NSEvent.ModifierFlags) -> KeyboardModifiers {
        var value: KeyboardModifiers = []
        if flags.contains(.command) { value.insert(.command) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.shift) { value.insert(.shift) }
        return value
    }

    static func modifier(for keyCode: UInt16) -> KeyboardModifiers? {
        switch Int(keyCode) {
        case kVK_Command, kVK_RightCommand: return .command
        case kVK_Option, kVK_RightOption: return .option
        case kVK_Control, kVK_RightControl: return .control
        case kVK_Shift, kVK_RightShift: return .shift
        default: return nil
        }
    }

    static func displayName(for binding: KeyboardBinding) -> String {
        var parts: [String] = []
        if binding.modifiers.contains(.control) { parts.append("⌃") }
        if binding.modifiers.contains(.option) { parts.append("⌥") }
        if binding.modifiers.contains(.shift) { parts.append("⇧") }
        if binding.modifiers.contains(.command) { parts.append("⌘") }
        parts.append(displayName(for: binding.keyCode))
        return parts.joined(separator: "+")
    }

    static func displayName(for keyCode: UInt16) -> String {
        let names: [Int: String] = [
            kVK_ANSI_A:"A", kVK_ANSI_B:"B", kVK_ANSI_C:"C", kVK_ANSI_D:"D", kVK_ANSI_E:"E", kVK_ANSI_F:"F", kVK_ANSI_G:"G", kVK_ANSI_H:"H", kVK_ANSI_I:"I", kVK_ANSI_J:"J", kVK_ANSI_K:"K", kVK_ANSI_L:"L", kVK_ANSI_M:"M", kVK_ANSI_N:"N", kVK_ANSI_O:"O", kVK_ANSI_P:"P", kVK_ANSI_Q:"Q", kVK_ANSI_R:"R", kVK_ANSI_S:"S", kVK_ANSI_T:"T", kVK_ANSI_U:"U", kVK_ANSI_V:"V", kVK_ANSI_W:"W", kVK_ANSI_X:"X", kVK_ANSI_Y:"Y", kVK_ANSI_Z:"Z",
            kVK_ANSI_0:"0", kVK_ANSI_1:"1", kVK_ANSI_2:"2", kVK_ANSI_3:"3", kVK_ANSI_4:"4", kVK_ANSI_5:"5", kVK_ANSI_6:"6", kVK_ANSI_7:"7", kVK_ANSI_8:"8", kVK_ANSI_9:"9",
            kVK_ANSI_Minus:"-", kVK_ANSI_Equal:"=", kVK_ANSI_LeftBracket:"[", kVK_ANSI_RightBracket:"]", kVK_ANSI_Backslash:"\\", kVK_ANSI_Semicolon:";", kVK_ANSI_Quote:"'", kVK_ANSI_Comma:",", kVK_ANSI_Period:".", kVK_ANSI_Slash:"/", kVK_ANSI_Grave:"`",
            kVK_Space: String(localized: "Space"), kVK_Return: String(localized: "Return"), kVK_Tab: String(localized: "Tab"), kVK_Escape: String(localized: "Escape"), kVK_Delete: String(localized: "Delete"), kVK_ForwardDelete: String(localized: "Forward Delete"), kVK_Home: String(localized: "Home"), kVK_End: String(localized: "End"), kVK_PageUp: String(localized: "Page Up"), kVK_PageDown: String(localized: "Page Down"), kVK_Help: String(localized: "Help"), kVK_UpArrow:"↑", kVK_DownArrow:"↓", kVK_LeftArrow:"←", kVK_RightArrow:"→",
            kVK_F1:"F1", kVK_F2:"F2", kVK_F3:"F3", kVK_F4:"F4", kVK_F5:"F5", kVK_F6:"F6", kVK_F7:"F7", kVK_F8:"F8", kVK_F9:"F9", kVK_F10:"F10", kVK_F11:"F11", kVK_F12:"F12", kVK_F13:"F13", kVK_F14:"F14", kVK_F15:"F15", kVK_F16:"F16", kVK_F17:"F17", kVK_F18:"F18", kVK_F19:"F19", kVK_F20:"F20",
            kVK_Command:"⌘", kVK_RightCommand:"右⌘", kVK_Option:"⌥", kVK_RightOption:"右⌥", kVK_Control:"⌃", kVK_RightControl:"右⌃", kVK_Shift:"⇧", kVK_RightShift:"右⇧"
        ]
        if let name = names[Int(keyCode)] { return name }
        return "Key \(keyCode)"
    }
}
