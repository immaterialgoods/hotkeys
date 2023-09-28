//
//  KeyManager.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 12/30/19.
//  Copyright © 2019-2020 Andreas Schwarz @ immaterial. All rights reserved.
//

import Cocoa
import Carbon

final class KeyManager {
    
    /// The singleton
    static let shared = KeyManager()

    /// User-visible descriptions, possibly need localization. We do these manually because the control characters used for key equivalents are unprintable
    private let controlKeyDescriptionsForKeycodes: Dictionary<UInt16, String> = [
    122: "F1",
    120: "F2",
    99: "F3",
    118: "F4",
    96: "F5",
    97: "F6",
    98: "F7",
    100: "F8",
    101: "F9",
    109: "F10",
    103: "F11",
    111: "F12",
    105: "F13",
    107: "F14",
    113: "F15",
    106: "F16",
    64: "F17",
    79: "F18",
    80: "F19",
    36: String(format: "%C", 0x21A9), // Return Key
    48: String(format: "%C", 0x21E5), // Tab Key
    49: String(format: "%C", 0x2334), // Space
    51: String(format: "%C", 0x232B), // Delete Key
    53: String(format: "%C", 0x238B), // Escape Key (not 27?)
    76: String(format: "%C", 0x2324), // Enter Key
    117: String(format: "%C", 0x2326), // Forward Delete Key
    114: String(format: "%C", 0x003F), // Help Key
    116: String(format: "%C", 0x21DE), // Page Up Key
    121: String(format: "%C", 0x21DF), // Page Down Key
    123: String(format: "%C", 0x2190), // Left Arrow Key
    124: String(format: "%C", 0x2192), // Right arrow Key
    125: String(format: "%C", 0x2193), // Down Arrow Key
    126: String(format: "%C", 0x2191), // Up Arrow Key
    71: String(format: "%C", 0x2327), // Clear Key
    119: String(format: "%C", 0x2198), // End Key
    115: String(format: "%C", 0x2196) // Home Key
    ]
    
    /// Strings as defined by the system, used for assignment to menu item key equivalents (UCKeyboardLayout doesn't actually give us the right ones, it seems.)
    private let functionKeyEquivalentsForKeycodes: Dictionary<UInt16, String> = [
    122: String(format: "%C", NSF1FunctionKey),
    120: String(format: "%C", NSF2FunctionKey),
    99: String(format: "%C", NSF3FunctionKey),
    118: String(format: "%C", NSF4FunctionKey),
    96: String(format: "%C", NSF5FunctionKey),
    97: String(format: "%C", NSF6FunctionKey),
    98: String(format: "%C", NSF7FunctionKey),
    100: String(format: "%C", NSF8FunctionKey),
    101: String(format: "%C", NSF9FunctionKey),
    109: String(format: "%C", NSF10FunctionKey),
    103: String(format: "%C", NSF11FunctionKey),
    111: String(format: "%C", NSF12FunctionKey),
    105: String(format: "%C", NSF13FunctionKey),
    107: String(format: "%C", NSF14FunctionKey),
    113: String(format: "%C", NSF15FunctionKey),
    106: String(format: "%C", NSF16FunctionKey),
    64: String(format: "%C", NSF17FunctionKey),
    79: String(format: "%C", NSF18FunctionKey),
    80: String(format: "%C", NSF19FunctionKey),
    //36: String(format: "%C", ), // Return Key
    //48: String(format: "%C", ), // Tab Key
    //49: String(format: "%C", ), // Space
    //51: String(format: "%C", ), // Delete Key
    //53: String(format: "%C", ), // Escape Key
    //76: String(format: "%C", ), // Enter Key
    117: String(format: "%C", NSDeleteFunctionKey),
    114: String(format: "%C", NSHelpFunctionKey),
    116: String(format: "%C", NSPageUpFunctionKey),
    121: String(format: "%C", NSPageDownFunctionKey),
    123: String(format: "%C", NSLeftArrowFunctionKey),
    124: String(format: "%C", NSRightArrowFunctionKey),
    125: String(format: "%C", NSDownArrowFunctionKey),
    126: String(format: "%C", NSUpArrowFunctionKey),
    71: String(format: "%C", NSClearLineFunctionKey),
    119: String(format: "%C", NSEndFunctionKey),
    115: String(format: "%C", NSHomeFunctionKey)
    ]
    
    /// To  identify numberpad keys
    private let numberPadKeycodes: Set<UInt16> = [65,67,69,75,78,81,82,83,84,85,86,87,88,89,91,92]
    
    /// A map to and from keyCodes and the lowercase strings that define the key
    private var lowercaseKeycodesAndStrings: TwoWayMap<UInt16,String> = [:]
    
    /// A map to and from keyCodes and the uppercase strings that define the key
    private var uppercaseKeycodesAndStrings: TwoWayMap<UInt16,String> = [:]

    /// Used for comparison to ensure we don't waste time rebuilding our strings if the layout hasn't changed
    private var keyboardLayoutData = Data()
    
    /// Builds the keycodesAndStrings map, and rebuilds it in cases the user's keyboard layout has changed
    private func updateKeycodeMap() {
        let keyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        guard let keyboardLayoutDataPointer = TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData) else {
            NSLog("Unable to get keyboard layout data pointer.")
            lowercaseKeycodesAndStrings = [:]
            uppercaseKeycodesAndStrings = [:]
            keyboardLayoutData = Data()
            return
        }
        
        let latestLayoutData = Unmanaged<CFData>.fromOpaque(keyboardLayoutDataPointer).takeUnretainedValue() as Data
        
        if latestLayoutData == keyboardLayoutData {
            // Nothing has changed since last time, so we are free to stop working
            return
        }
        
        keyboardLayoutData = latestLayoutData
        lowercaseKeycodesAndStrings = [:]
        uppercaseKeycodesAndStrings = [:]

        let keyboardLayout = keyboardLayoutData.withUnsafeBytes {
            $0.bindMemory(to: UCKeyboardLayout.self)
        }
        
        let shiftModifier = UInt32(shiftKey >> 8) & 0xFF
        
        // Iterate through the possible keycodes (never seen anything useful beyond 128) and create their string representation
        for keyCode: UInt16 in (0..<128) {
            // If it's a function key, get the string representation from our table
            if let functionName = functionKeyEquivalentsForKeycodes[keyCode] {
                // Just add to one map, no need for both
                lowercaseKeycodesAndStrings[keyCode] = functionName
                continue
            }
            
            if let name = getName(for: keyCode, from: keyboardLayout, modifierKeys: 0) {
                lowercaseKeycodesAndStrings[keyCode] = name
            }
            if let shiftName = getName(for: keyCode, from: keyboardLayout, modifierKeys: shiftModifier) {
                // Only add to the uppercase map if the value is actually unique
                if let lowercase = lowercaseKeycodesAndStrings[keyCode], lowercase == shiftName {
                    // Don't save it
                }
                else {
                    uppercaseKeycodesAndStrings[keyCode] = shiftName
                }
            }
        }

    }
    
    private func getName(for keyCode: UInt16, from keyboardLayout: UnsafeBufferPointer<UCKeyboardLayout>, modifierKeys: UInt32) -> String? {
        let keyboardType = UInt32(LMGetKbdType())
        var deadKeys: UInt32 = 0
        let maxNameLength = 4
        var actualNameLength = 0
        var nameBuffer = [UniChar](repeating: 0, count : maxNameLength)

        let error = UCKeyTranslate(keyboardLayout.baseAddress, keyCode, UInt16(kUCKeyActionDisplay), modifierKeys, keyboardType, OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, maxNameLength, &actualNameLength, &nameBuffer)
        
        guard error == noErr else {
            NSLog("Error %+i getting keyCode 0x%04X", error, keyCode)
            return nil
        }
        
        guard actualNameLength > 0 else {
            return nil
        }
        
        let name = String(utf16CodeUnits: nameBuffer, count: actualNameLength)
        
        guard name.count > 0 else {
            return nil
        }
            
        return name
    }

    // MARK: - Useful public functions
    
    public func keyCode(for string: String) -> UInt16? {
        updateKeycodeMap()
        if let lowercase = lowercaseKeycodesAndStrings[string] { return lowercase }
        if let uppercase = uppercaseKeycodesAndStrings[string] { return uppercase }
        return nil
    }
    
    public func keyEquivalent(for keyCode: UInt16) -> String? {
        updateKeycodeMap()
        if let lowercase = lowercaseKeycodesAndStrings[keyCode] { return lowercase }
        if let uppercase = uppercaseKeycodesAndStrings[keyCode] { return uppercase }
        return nil
    }
    
    public func displayString(for keyCode: UInt16, keyEquivalent: String, modifierKeys: NSEvent.ModifierFlags, annotateNumberPad numPad: Bool) -> String? {
        var displayString: String?
       
        // Check if we have a control key strin available
        if let controlKeyEquivalent = controlKeyDescriptionsForKeycodes[keyCode] {
            displayString = controlKeyEquivalent
        }
        else if numPad {
            // Use keyCode
            if modifierKeys.contains(.shift) {
                if let uppercase = uppercaseKeycodesAndStrings[keyCode] {
                    displayString = uppercase
                }
                    // Try this just in case
                else if let lowercase = lowercaseKeycodesAndStrings[keyCode] {
                    displayString = lowercase.uppercased()
                }
            }
            else {
                if let lowercase = lowercaseKeycodesAndStrings[keyCode] {
                    displayString = lowercase.uppercased()
                }
                    // Try this just in case
                else if let uppercase = uppercaseKeycodesAndStrings[keyCode] {
                    displayString = uppercase
                }
            }
            
            // Check for numberpad annotation
            if numberPadKeycodes.contains(keyCode), let numberPadString = displayString {
                displayString = "#" + numberPadString
            }
        }
        else {
            // Use keyEquivalent
            displayString = keyEquivalent.uppercased()
        }
        
        
        return displayString
    }
    
    public func isUppercaseKeyEquivalent(_ keyEquivalent: String) -> Bool {
        // This can return false positives: normal + (shift =) is uppercase but keypad + is not. Can't help that.
        if uppercaseKeycodesAndStrings[keyEquivalent] != nil {
            return true
        }

        return false
    }
    

    
    
}
