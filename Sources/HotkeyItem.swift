//
//  HotkeyListItem.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 1/1/20.
//  Copyright © 2019-2020 Andreas Schwarz @ immaterial. All rights reserved.
//

import Foundation

@objc public enum MenuAutoInclusionPolicy: Int {
    /// Any menu item with a custom identifier (IB automatic identifiers are excluded) will be added automatically
    case allItemsWithIdentifier
    /// Any menu item with a custom identifier with the suffix '-hotkeyable' will be added automatically
    case itemsWithHotkeySuffix
    /// Only menu items whose identifiers appear in the explicit inclusion set will be added
    case explicitInclusionOnly
}

@objc public enum HotkeyModifierRequirement: Int {
    /// No modifiers required
    case noModifiers
    /// At least one modifier key (command, option, control, shift, function) is required for this item
    case anyModifiers
    /// At least one menu modifier key (command, control, function) is required for this item
    case menuModifiers
}


@objc public final class HotkeyItem: NSObject {
    /// Item's title in the table view (can be pulled from menu item)
    @objc public var title: String
    
    /// Item's identifier, used to match it with menu item and as part of the NSUserDefaults key (can be pulled from menu item)
    @objc public let identifier: String

    /// The hotkey descriptor for this item (can be pulled from menu item if not in NSUserDefaults); that is, what the hotkey is actually set to.
    @objc public var hotkey: HotkeyDescriptor? = nil
    
    /// The default hotkey descriptor for this item (pulled from menu item); that is, what it would be were it not overridden by the user.
    @objc public var defaultHotkey: HotkeyDescriptor? = nil
    
    /// If the item is a header, identifier is ignored and it is not saved in NSUserDefaults. Headers are purely for organizational purposes.
    @objc public var isHeader = false

    @objc public var modifierRequirement: HotkeyModifierRequirement = .menuModifiers
            
    /// Whether to print the hotkey in menu style (this affects only the numberpad designation for certain keycodes)
    @objc public var menuStyle = true
    
    @objc public init(withTitle title: String, identifier: String, hotkey: HotkeyDescriptor? = nil, defaultHotkey: HotkeyDescriptor? = nil) {
        self.title = title
        self.identifier = identifier
        self.hotkey = hotkey
        self.defaultHotkey = defaultHotkey
    }
    
    /// Creates an item with title and identifier, all other properties at the default
    @objc public class func item(withTitle title: String, identifier: String) -> HotkeyItem {
        return HotkeyItem(withTitle: title, identifier: identifier, hotkey: nil, defaultHotkey: nil)
    }
    
    /// Creates an item with title, identifier, and default hotkey, all other properties at the default
    @objc public class func item(withTitle title: String, identifier: String, defaultHotkey: HotkeyDescriptor?) -> HotkeyItem {
        return HotkeyItem(withTitle: title, identifier: identifier, hotkey: nil, defaultHotkey: defaultHotkey)
    }
    
    /// Creates an item with title, identifier, default hotkey, and modifier requirement, all other properties at the default
    @objc public class func item(withTitle title: String, identifier: String, defaultHotkey: HotkeyDescriptor?, modifierRequirement: HotkeyModifierRequirement) -> HotkeyItem {
        let item = HotkeyItem(withTitle: title, identifier: identifier, hotkey: nil, defaultHotkey: defaultHotkey)
        item.modifierRequirement = modifierRequirement
        return item
    }
    
    /// Creates an item with title, identifier, default hotkey, all other properties set with the expectation of keyboard control rather than through a menu item. No modifier requirements and menuStyle = false.
    @objc public class func keyControlItem(withTitle title: String, identifier: String, defaultHotkey: HotkeyDescriptor?) -> HotkeyItem {
        let item = HotkeyItem(withTitle: title, identifier: identifier, hotkey: nil, defaultHotkey: defaultHotkey)
        item.modifierRequirement = .noModifiers
        item.menuStyle = false
        return item
    }
    
    @objc public class func headerItem(withTitle title: String) -> HotkeyItem {
        let item = HotkeyItem(withTitle: title, identifier: "", hotkey: nil, defaultHotkey: nil)
        item.isHeader = true
        return item
    }
}
