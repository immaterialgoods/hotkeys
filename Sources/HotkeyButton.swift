//
//  HotkeyButton.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 12/30/19.
//  Copyright © 2019-2020 Andreas Schwarz @ immaterial. All rights reserved.
//

import Cocoa

@objc 
public protocol HotkeyButtonDelegate {
    @objc 
    func hotkeyButton(_ button: HotkeyButton, updatedHotkey hotkey:HotkeyDescriptor?)
}

@objc 
public class HotkeyButton: NSButton {

/**
Set or get the hotkey from here. 3 possible states:
     - nil hotkey means defer to the default hotkey (or shows "no hotkey" if there is no default)
     - empty hotkey means the user cleared out the default but didn't set anything in its place (shows "no hotkey")
     - complete hotkey means the user has set a hotkey (shows that hotkey rather than default)
 */
    @objc 
    public var hotkey: HotkeyDescriptor? = nil {
        didSet {
            self.inProgressHotkey = self.hotkey
        }
    }
    
    /// The default hotkey that the user can revert back to if desired
    @objc 
    public var defaultHotkey: HotkeyDescriptor? = nil{
        didSet {
            updateForHotkey()
        }
    }
    
    /// What modifiers to require
    @objc 
    public var modifierRequirement: HotkeyModifierRequirement = .menuModifiers
    
    /// menuStyle = YES shows the display string rather than the key equivalent string
    @objc 
    public var menuStyle = true {
        didSet {
            updateForHotkey()
        }
    }
        
    /// Delegate gets notified when hotkey changes
    @objc 
    public weak var delegate: HotkeyButtonDelegate? = nil
    
    private var active = false {
        didSet {
            updateForActive()
        }
    }
    
    private var iconSize = NSSize(width:14, height:14)

    private var clearHotkey = false

    private var messageTimer: Timer? = nil
    
    private var inProgressHotkey: HotkeyDescriptor? = nil {
        didSet {
            updateForHotkey()
        }
    }

    
    // MARK: - Setup
    
    override public func awakeFromNib() {
        super.awakeFromNib()
                
        updateForHotkey()
        updateForActive()
    }
    
/**
     4 Possible states:
     - active state when user is actively setting hotkey
     - nil hotkey means defer to the default hotkey (or shows "no hotkey" if there is no default)
     - empty hotkey means the user cleared out the default but didn't set anything in its place (shows "no hotkey")
     - complete hotkey means the user has set a hotkey (shows that hotkey rather than default)

*/
    private func updateForHotkey() {
        self.imageHugsTitle = false;
        
        if active {
            // User is actively entering a hotkey; all we want to do is display what they've typed so far
            title = inProgressHotkey?.completeMenuStyleString(withNumberPadAnnotation: !menuStyle) ?? ""
            image = nil
            alternateImage = nil
            self.imagePosition = .noImage
        }
        else if let hotkey = hotkey {
            if (hotkey.isEmpty) {
                // User has cleared the hotkey in a way that takes precedence over the default
                title = NSLocalizedString("No Hotkey", comment: "")
                let newAttributedTitle = attributedTitle.mutableCopy() as! NSMutableAttributedString
                newAttributedTitle.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: NSMakeRange(0, newAttributedTitle.length))
                attributedTitle = newAttributedTitle
                
                // If there is a default, we want the user to be able to return to it
                if defaultHotkey != nil {
                    let resetImage = NSImage(imageLiteralResourceName: NSImage.refreshFreestandingTemplateName)
                    resetImage.size = iconSize
                    image = resetImage
                    alternateImage = resetImage
                    self.imagePosition = .imageTrailing
                }
                else {
                    image = nil
                    alternateImage = nil
                    self.imagePosition = .noImage
                }
            }
            else {
                // User has set a hotkey that takes precedence over the default
                title = hotkey.completeMenuStyleString(withNumberPadAnnotation: !menuStyle)
                
                // Show the user the clear button
                let clearImage = NSImage(imageLiteralResourceName: NSImage.stopProgressFreestandingTemplateName)
                clearImage.size = iconSize
                image = clearImage
                alternateImage = clearImage
                self.imagePosition = .imageTrailing
            }
        }
        else {
            // Nil hotkey means we are back to default, if it exists
            if let defaultHotkey = defaultHotkey {
                title = defaultHotkey.completeMenuStyleString(withNumberPadAnnotation: !menuStyle)
                
                // Show the user the clear button
                let clearImage = NSImage(imageLiteralResourceName: NSImage.stopProgressFreestandingTemplateName)
                clearImage.size = iconSize
                image = clearImage
                alternateImage = clearImage
                self.imagePosition = .imageTrailing
            }
            else {
                // No hotkey at all
                image = nil
                alternateImage = nil
                self.imagePosition = .noImage

                title = NSLocalizedString("No Hotkey", comment: "")
                let newAttributedTitle = attributedTitle.mutableCopy() as! NSMutableAttributedString
                newAttributedTitle.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: NSMakeRange(0, newAttributedTitle.length))
                attributedTitle = newAttributedTitle
            }
        }
    }
    
    private func updateForActive() {
        if active {
            clearHotkey = true
            state = .on
            window?.makeFirstResponder(self)
        }
        else {
            clearHotkey = false
            state = .off
            if window?.firstResponder == self { window?.makeFirstResponder(window?.contentView) }
        }
        
        updateForHotkey()
    }
    
    // MARK: - Getting responder events
    
    public override func flagsChanged(with event: NSEvent) {
        guard active else { return }
        enterEventCycle(with: event)
    }
    
    public override func keyDown(with event: NSEvent) {
        guard active else { return }
        enterEventCycle(with: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        if NSPointInRect(convert(event.locationInWindow, from: nil), cell?.imageRect(forBounds: bounds) ?? NSZeroRect) {
            // User clicked the clear or reset button
            active = false
            
            if let hotkey = hotkey, hotkey.isEmpty, defaultHotkey != nil {
                // We need to reset hotkey back to the default
                self.hotkey = nil
            }
            else {
                // We need to clear the hotkey
                self.hotkey = HotkeyDescriptor.emptyHotkey()
            }
            
            informDelegateOfNewHotkey()
        }
        else {
            // Activate or deactivate
            active = !active
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        guard active else { return }
        enterEventCycle(with: event)
    }
    
    public override func performClick(_ sender: Any?) {
        // Toggle active state
        active = !active
    }
    
    // MARK: - Handling events

    private func enterEventCycle(with event: NSEvent) {
        var nextEvent: NSEvent? = event
        
        while let currentEvent = nextEvent {
            var done = false
            
            switch currentEvent.type {
            case .keyDown:
                guard !currentEvent.isARepeat else { break }
                
                if let characters = currentEvent.charactersIgnoringModifiers, characters.count == 1 {
                    inProgressHotkey = HotkeyDescriptor(keyCode: currentEvent.keyCode, keyEquivalent: nil /* We want to get the lowercase from the keycode (ie. 7 not &). */, modifierKeys: currentEvent.modifierFlags)
                } else {
                    inProgressHotkey = HotkeyDescriptor(keyCode: HotkeyDescriptor.noKeyCode, keyEquivalent: nil, modifierKeys: currentEvent.modifierFlags)
                }
                
                clearHotkey = false
                
            case .flagsChanged:
                if let hotkey = inProgressHotkey, !clearHotkey {
                    inProgressHotkey = HotkeyDescriptor(keyCode: hotkey.keyCode, keyEquivalent: hotkey.keyEquivalent, modifierKeys: currentEvent.modifierFlags)
                }
                else {
                    inProgressHotkey = HotkeyDescriptor(keyCode:HotkeyDescriptor.noKeyCode, keyEquivalent: nil, modifierKeys: currentEvent.modifierFlags)
                }
                clearHotkey = false

            case .keyUp:
                done = true
                
            case .leftMouseDown:
                NSApp.sendEvent(currentEvent)
                done = true
                
            default:
                break
            }
            
            if done {
                nextEvent = nil;
            }
            else {
                nextEvent = NSApp.nextEvent(matching: .any, until: Date(timeIntervalSinceNow: 10.0), inMode: .default, dequeue: true)
            }
        }
        
        finalizeHotkey()
    }
    
    private func finalizeHotkey() {
        var modifierMessage = false
        active = false

        if let inProgressHotkey = inProgressHotkey {
            let modifiers = inProgressHotkey.modifierKeys
            
            if inProgressHotkey.keyCode == HotkeyDescriptor.noKeyCode || inProgressHotkey.keyEquivalent == nil {
                self.inProgressHotkey = nil
            }
            
            switch modifierRequirement {
            case .anyModifiers:
                if (modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.function)) == false {
                    self.inProgressHotkey = nil
                    modifierMessage = true
                }
                
            case .menuModifiers:
                if (modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.function)) == false {
                    self.inProgressHotkey = nil
                    modifierMessage = true
                }
                
            case .noModifiers:
                break
            }
        }
        
        if let inProgressHotkey = inProgressHotkey {
            hotkey = inProgressHotkey
        }

        
        if modifierMessage {
            showModifiersMessage()
        }
        else {
            informDelegateOfNewHotkey()
        }
    }
    
    private func showModifiersMessage() {
        var title: String? = nil
        let control = "⌃"
        let option = "⌥"
        let shift = "⇧"
        let command = "⌘"
        
        switch modifierRequirement {
            case .anyModifiers:
                title = String(format: NSLocalizedString("%@, %@, %@, or %@", comment: ""), command, control, option, shift)

            case .menuModifiers:
                title = String(format: NSLocalizedString("%@, %@, or Fn", comment: ""), command, control)

            case .noModifiers:
                break
        }
        
        if let title = title {
            let attributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 9), NSAttributedString.Key.foregroundColor : NSColor.disabledControlTextColor]
            attributedTitle = NSAttributedString(string: title, attributes: attributes)
            
            messageTimer?.invalidate()
            messageTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(self.resetTitle), userInfo: nil, repeats: false)
        }
        
    }
    
    @objc 
    private func resetTitle(_ timer: Timer) {
        messageTimer?.invalidate()
        messageTimer = nil
        updateForHotkey()
    }
    
    private func informDelegateOfNewHotkey() {
        guard let delegate = delegate else { return }
        delegate.hotkeyButton(self, updatedHotkey: self.hotkey)
    }
    
    // MARK: - Misc Overrides
    
    public override var canBecomeKeyView: Bool {
        get {
            return true
        }
    }

    public override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    public override func becomeFirstResponder() -> Bool {
        return true
    }
    
    public override func resignFirstResponder() -> Bool {
        if active { finalizeHotkey() }
        return true
    }
}
