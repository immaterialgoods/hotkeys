//
//  HotkeyAction.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 1/4/20.
//  Copyright © 2019-2020 Andreas Schwarz @ immaterial. All rights reserved.
//

import Foundation

@objc public final class HotkeyAction: NSObject {
    @objc public let identifier: String

    /// Action for this HotkeyAction; the HotkeysController will listen for this item's hotkey and attempt to fire the action to either the target (if not nil), or the current first responder (but not up the chain)
    @objc public let action: Selector
    
    /// Target for this HotkeyAction; the HotkeysController will listen for this item's hotkey and attempt to fire the action to either the target (if not nil), or the current first responder (but not up the chain)
    @objc public weak var target: AnyObject? = nil
    
    // Whether to search up the full responder chain; if false, only the first responder is tested for response to the action
    @objc public let fullResponderChain: Bool
    
    // Whether to consume the event after the action is taken. If true, the event will not be passed to the rest of the application.
    @objc public let consumeEvent: Bool

    @objc public init(identifier: String, action: Selector, target: AnyObject? = nil, consumeEvent: Bool = true, fullResponderChain: Bool = true) {
        self.identifier = identifier
        self.action = action
        self.target = target
        self.fullResponderChain = fullResponderChain
        self.consumeEvent = consumeEvent
    }
    
    @objc public class func hotkeyAction(withIdentifier identifier: String, action: Selector) -> HotkeyAction {
        return HotkeyAction(identifier: identifier, action: action)
    }
    
    @objc public class func hotkeyAction(withIdentifier identifier: String, action: Selector, target: AnyObject?) -> HotkeyAction {
        return HotkeyAction(identifier: identifier, action: action, target: target)
    }
    
    @objc public class func hotkeyAction(withIdentifier identifier: String, action: Selector, consumeEvent: Bool) -> HotkeyAction {
        return HotkeyAction(identifier: identifier, action: action, consumeEvent: consumeEvent)
    }

}
