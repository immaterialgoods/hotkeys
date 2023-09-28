//
//  HotkeyDescriptor.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 12/30/19.
//  Copyright © 2019-2020 Andreas Schwarz @ immaterial. All rights reserved.
//

import Cocoa
import Carbon

@objc
public final class HotkeyDescriptor: NSObject, NSSecureCoding {
    
    // MARK: - Properties
    
    /// It would be better to make keyCode optional, but since we want Objective C compatibility we use this flag instead
    @objc 
    public static let noKeyCode: UInt16 = UInt16.max
    
    /// The key code for the hotkey, should match NSEvent keyCode.  keyEquivalent and keyCode may simultaneously be nil/UInt16.max if the descriptor is only describing modifier flags
    let keyCode: UInt16
    
    /// The key string for the hotkey, should match NSMenuItem keyEquivalent. keyEquivalent and keyCode may simultaneously be nil if the descriptor is only describing modifier flags
    let keyEquivalent: String?
    
    /// Modifier flags for the hotkey, should match NSMenuItem keyEquivalentModifierMask and NSEvent modifierFlags
    let modifierKeys: NSEvent.ModifierFlags
    
    let isEmpty: Bool
    
    
    public override var description: String {
        return "Hotkey Descriptor keycode '\(self.keyCode)' keyEquivalent '\(String(describing: self.keyEquivalent))'"
    }
    
    // MARK: - Creating Hotkey Descriptors

    @objc 
    public init?(keyCode: UInt16, keyEquivalent: String?, modifierKeys: NSEvent.ModifierFlags) {
        self.modifierKeys = Self.sanitize(modifiers:modifierKeys)
        
        switch (keyCode, keyEquivalent) {
        case (Self.noKeyCode, nil):
            self.keyCode = Self.noKeyCode
            self.keyEquivalent = nil
            self.isEmpty = self.modifierKeys.isEmpty
            
        case let (Self.noKeyCode, string?):
            // If we got one, we should be able to get the other one or something went wrong
            guard let code = KeyManager.shared.keyCode(for:string) else { return nil }
            self.keyCode = code
            self.keyEquivalent = string
            self.isEmpty = false
                
        case let (code, nil):
            // If we got one, we should be able to get the other one or something went wrong
            guard let string = KeyManager.shared.keyEquivalent(for:code) else { return nil }
            self.keyCode = code
            self.keyEquivalent = string
            self.isEmpty = false
            
        case let (code, string?):
            // If we got both, make sure they're set up correctly
            guard string.count == 1 else { NSLog("String was '%@' which is apparently more than one character", string); return nil }
            self.keyCode = code
            self.keyEquivalent = string
            self.isEmpty = false
        }

    }
    
    @objc 
    public class func hotkey(command: Bool, shift: Bool, option: Bool, control: Bool, keyCode: UInt16, keyEquivalent: String?) -> HotkeyDescriptor? {
        var modifiers = NSEvent.ModifierFlags()
    
        // This gets rid of any other flags that might have been passed in
        if command { modifiers.insert(.command) }
        if shift { modifiers.insert(.option) }
        if option { modifiers.insert(.control) }
        if control { modifiers.insert(.shift) }
           
        return HotkeyDescriptor(keyCode: keyCode, keyEquivalent: keyEquivalent, modifierKeys: modifiers)
    }
    
    @objc 
    public class func hotkey(keyCode: UInt16) -> HotkeyDescriptor? {
        return HotkeyDescriptor(keyCode: keyCode, keyEquivalent: nil, modifierKeys: NSEvent.ModifierFlags())
    }

    @objc 
    public class func hotkey(keyEquivalent: String) -> HotkeyDescriptor? {
        return HotkeyDescriptor(keyCode: noKeyCode, keyEquivalent: keyEquivalent, modifierKeys: NSEvent.ModifierFlags())
    }

    @objc 
    public class func hotkey(keyCode: UInt16, modifierKeys: NSEvent.ModifierFlags) -> HotkeyDescriptor? {
        return HotkeyDescriptor(keyCode: keyCode, keyEquivalent: nil, modifierKeys: modifierKeys)
    }

    @objc 
    public class func hotkey(keyEquivalent: String, modifierKeys: NSEvent.ModifierFlags) -> HotkeyDescriptor? {
        return HotkeyDescriptor(keyCode: noKeyCode, keyEquivalent: keyEquivalent, modifierKeys: modifierKeys)
    }

    @objc 
    public class func hotkey(menuItem: NSMenuItem) -> HotkeyDescriptor? {
        guard menuItem.keyEquivalent.count > 0 else { return nil }
        
        /* Apple does something weird and stupid, here. if the keyEquivalent is capitalized, the menu item requires the shift key BUT DOES NOT INCLUDE SHIFT IN THE MODIFIER MASK.
         On the other hand, in cases where the shift key produces a different (not just capitalized) character, ie. 7 and &, they might use the lowercase (7) and include the shift
         modifier mask, or they might usee the uppercase (&) and not include the shift modifier mask.
         
         We want to record the correct modifier mask all the time so we have to check if the keyEquivalent is an uppercase character. */
        
        if let keyCode = KeyManager.shared.keyCode(for: menuItem.keyEquivalent) {
            let addShift = KeyManager.shared.isUppercaseKeyEquivalent(menuItem.keyEquivalent)
            var modifiers = menuItem.keyEquivalentModifierMask
            
            if addShift { modifiers.insert(.shift) }
            
            return HotkeyDescriptor(keyCode: keyCode, keyEquivalent: nil, modifierKeys: modifiers)
        }
        
        return nil
    }
        
    @objc 
    public class func emptyHotkey() -> HotkeyDescriptor {
        return HotkeyDescriptor(keyCode: noKeyCode, keyEquivalent: nil, modifierKeys: NSEvent.ModifierFlags())!
    }
        
    // MARK: - Displaying Hotkey Descriptors

    public func displayString(withNumberPadAnnotation annotate: Bool = false) -> String {
        if
            keyCode != Self.noKeyCode,
            let keyEquivalent = keyEquivalent,
            let displayString = KeyManager.shared.displayString(for: keyCode, keyEquivalent: keyEquivalent, modifierKeys: modifierKeys, annotateNumberPad: annotate) {
            return displayString
        }

        return ""
    }
    
    public func displayModifiers() -> String {
        var modString = ""
        let control = "⌃"
        let option = "⌥"
        let shift = "⇧"
        let command = "⌘"

        if modifierKeys.contains(.control) { modString += control }
        if modifierKeys.contains(.option) { modString += option }
        if modifierKeys.contains(.shift) { modString += shift }
        if modifierKeys.contains(.command) { modString += command }

        return modString
    }
    
    public func completeMenuStyleString(withNumberPadAnnotation annotate: Bool = false) -> String {
        return displayModifiers() + displayString(withNumberPadAnnotation:annotate)
    }
    
    // MARK: - Comparing to Events

    @objc public func matchesThroughKeyCode(_ event: NSEvent) -> Bool {
        guard isEmpty == false && (event.type == .keyUp || event.type == .keyDown) else { return false }
        
        if event.keyCode == keyCode {
            let eventModifiers = event.modifierFlags
            if (eventModifiers.contains(.command) == modifierKeys.contains(.command)) &&
                (eventModifiers.contains(.option) == modifierKeys.contains(.option)) &&
                (eventModifiers.contains(.control) == modifierKeys.contains(.control)) &&
                (eventModifiers.contains(.shift) == modifierKeys.contains(.shift)) &&
                (eventModifiers.contains(.function) == modifierKeys.contains(.function)) {
                return true
            }
        }
        
        return false
    }
    
    @objc public func matchesThroughKeyEquivalent(_ event: NSEvent) -> Bool {
        guard isEmpty == false && (event.type == .keyUp || event.type == .keyDown) else { return false }
        
        if let keyEquivalent = keyEquivalent, let eventKeyEquivalent = event.charactersIgnoringModifiers {
            // We have to take into account possible uppercase/lowercase shenanigans, though the event SHOULD be lowercase anyway
            if keyEquivalent.lowercased() == eventKeyEquivalent.lowercased() {
                let eventModifiers = event.modifierFlags
                if (eventModifiers.contains(.command) == modifierKeys.contains(.command)) &&
                    (eventModifiers.contains(.option) == modifierKeys.contains(.option)) &&
                    (eventModifiers.contains(.control) == modifierKeys.contains(.control)) &&
                    (eventModifiers.contains(.shift) == modifierKeys.contains(.shift)) &&
                    (eventModifiers.contains(.function) == modifierKeys.contains(.function)) {
                    return true
                }
            }
            
        }
        
        return false
    }

    // MARK: - NSCoding

    enum Keys: String, RawRepresentable {
        case keyCode
        case keyEquivalent
        case modifierCommand
        case modifierOption
        case modifierControl
        case modifierShift
        case modifierFunction
    }

    @objc 
    public static var supportsSecureCoding = true
        
    @objc 
    public func encode(with coder: NSCoder) {
        coder.encode(keyCode, forKey: Keys.keyCode.rawValue)
        coder.encode(keyEquivalent, forKey: Keys.keyEquivalent.rawValue)
        
        coder.encode(modifierKeys.contains(.command), forKey: Keys.modifierCommand.rawValue)
        coder.encode(modifierKeys.contains(.option), forKey: Keys.modifierOption.rawValue)
        coder.encode(modifierKeys.contains(.control), forKey: Keys.modifierControl.rawValue)
        coder.encode(modifierKeys.contains(.shift), forKey: Keys.modifierShift.rawValue)
        coder.encode(modifierKeys.contains(.function), forKey: Keys.modifierFunction.rawValue)
    }
    
    @objc 
    public init?(coder: NSCoder) {
        let command = coder.decodeBool(forKey: Keys.modifierCommand.rawValue)
        let option = coder.decodeBool(forKey: Keys.modifierOption.rawValue)
        let control = coder.decodeBool(forKey: Keys.modifierControl.rawValue)
        let shift = coder.decodeBool(forKey: Keys.modifierShift.rawValue)
        let function = coder.decodeBool(forKey: Keys.modifierFunction.rawValue)

        var modifiers = NSEvent.ModifierFlags()
        if command { modifiers.insert(.command) }
        if option { modifiers.insert(.option) }
        if control { modifiers.insert(.control) }
        if shift { modifiers.insert(.shift) }
        if function { modifiers.insert(.function) }

        self.modifierKeys = modifiers

        if
            var keyCode = coder.decodeObject(forKey: Keys.keyCode.rawValue) as? UInt16,
            var keyEquivalent = coder.decodeObject(forKey: Keys.keyEquivalent.rawValue) as? String,
            keyCode != Self.noKeyCode {
            
            // Confirm keyCode and keyEquivalent are still accurate to one another (keyboard may have changed while we were archived)
            if let testString = KeyManager.shared.keyEquivalent(for:keyCode) {
                if keyEquivalent != testString {
                    // Incompatibility. Let's prefer the key string if possible.
                    if let testCode = KeyManager.shared.keyCode(for: keyEquivalent) {
                        keyCode = testCode
                    }
                    else {
                        keyEquivalent = testString
                    }
                }
            }
            else {
                // See if we can get a keyCode for the keyEquivalent instead
                if let testCode = KeyManager.shared.keyCode(for: keyEquivalent) {
                    keyCode = testCode
                }
                else {
                    NSLog("Keyboard changed in an incompatible way, likely to see inconsistent hotkey functionality")
                    // Nothing we can really do about it, though.
                }
            }

            self.keyCode = keyCode
            self.keyEquivalent = keyEquivalent
            self.isEmpty = false
        }
        else {
            self.keyCode = Self.noKeyCode
            self.keyEquivalent = nil
            self.isEmpty = modifiers.isEmpty
        }
    }
    
    // MARK: - Equatable
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? HotkeyDescriptor else { return false }
        
        if self.keyCode != other.keyCode || self.keyEquivalent != other.keyEquivalent { return false }
        
        return
            self.modifierKeys.contains(.command) == other.modifierKeys.contains(.command) &&
            self.modifierKeys.contains(.control) == other.modifierKeys.contains(.control) &&
            self.modifierKeys.contains(.shift) == other.modifierKeys.contains(.shift) &&
            self.modifierKeys.contains(.option) == other.modifierKeys.contains(.option) &&
            self.modifierKeys.contains(.function) == other.modifierKeys.contains(.function)
    }
    
    // MARK: - Utility
    class func sanitize(modifiers: NSEvent.ModifierFlags?) -> NSEvent.ModifierFlags {
        var newModifiers = NSEvent.ModifierFlags()
        // This gets rid of any other flags that might have been passed in
        if let modifiers = modifiers {
            if modifiers.contains(.command) { newModifiers.insert(.command) }
            if modifiers.contains(.option) { newModifiers.insert(.option) }
            if modifiers.contains(.control) { newModifiers.insert(.control) }
            if modifiers.contains(.shift) { newModifiers.insert(.shift) }
        }
        return newModifiers
    }

}



public extension NSMenuItem {
    /// Used to set the menu item to the speficied hotkey
    @objc 
    func setHotkey(_ hotkey: HotkeyDescriptor?) {
        guard let hotkey = hotkey, let keyEquivalent = hotkey.keyEquivalent else { return }
        self.keyEquivalent = keyEquivalent.lowercased()
        self.keyEquivalentModifierMask = hotkey.modifierKeys
    }
}

