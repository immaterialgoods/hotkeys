//
//  HotkeysController.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 1/1/20.
//  Copyright © 2019-2020 Andreas Schwarz @ immaterial. All rights reserved.
//

import Cocoa
import os

@objc 
public final class HotkeysController: NSObject {
    
    // MARK: - Properties
    
    /// REQUIRED: Set this to your main menu (or if for some reason you prefer just a submenu, you can do that) and the menu will be scanned as per the set auto inclusion policy
    @objc
    public var menu: NSMenu?
    
    /// Determines how to automatically scan your menu for items that can have hotkeys set
    @objc
    public var menuAutoInclusionPolicy: MenuAutoInclusionPolicy = .allItemsWithIdentifier
    
    /// If you want custom settings for a particular menu item hotkey (eg. want to change from the default menu modifier requirement), manually create the item(s) and set them here.
    @objc
    public var customMenuHotkeyItems: Array<HotkeyItem> = [] {
        didSet {
            customMenuHotkeyItemsByIdentifier = customMenuHotkeyItems.reduce(into: [:], { $0[$1.identifier] = $1 })
        }
    }
    
    /// If you want to add hotkeys for actions that are not in the main menu (eg. actions you may handle in a custom view), add them here. You may (and should) create header items for organizational purposes
    @objc
    public var additionalHotkeyItems: Array<HotkeyItem> = []
    
    /// Any menu item identifiers that must be included (regardless of menuAutoInclusionPolicy)
    @objc
    public var inclusionIdentifiers: Set<String> = []
    
    /// Any menu item identifiers that must be excluded (regardless of menuAutoInclusionPolicy)
    @objc
    public var exclusionIdentifiers: Set<String> = []
    
    /// Set this to your table view, and the hotkeys controller will do everything else. If desired you can use this temporarily (eg. while a preferences window is open), then set it to nil again.
    @objc
    public var hotkeysTableView: NSTableView? {
        willSet {
            if newValue == nil, let tableView = self.hotkeysTableView {
                tableView.dataSource = nil
                tableView.delegate = nil
            }
        }
        didSet {
            if let tableView = self.hotkeysTableView {
                tableView.dataSource = self
                tableView.delegate = self
                tableView.floatsGroupRows = true
                reloadTableView()
            }
        }
    }
    
    
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.immaterialgoods.Hotkeys", category: "HotkeysLogs")
    
    private var allHotkeyItemsByIdentifier: Dictionary<String, HotkeyItem> = [:]
    
    private var customMenuHotkeyItemsByIdentifier: Dictionary<String, HotkeyItem> = [:]
    
    private var hotkeyActions: Dictionary<String, HotkeyAction> = [:]
    
    private var hotkeyListenerCacheKeycode: Dictionary<UInt16, [(String, HotkeyDescriptor)]> = [:]
    
    private var hotkeyListenerCacheCharacter: Dictionary<String, [(String, HotkeyDescriptor)]> = [:]
    
    private var menuHotkeyItems: Array<HotkeyItem> = []
    
    private var setupComplete: Bool = false
    
    
    // MARK: - Starting the Controller
    
    /// Call this to start the hotkey controller; it will load the menu items and set any user-specified hotkeys. **Set all other properties first.** Do not call this more than once.
    @objc public func start() {
        guard let menu = menu else {
            logger.error("Hotkeys: Please set the menu property before attempting to set menu items to user hotkeys.")
            return
        }
        
        guard setupComplete == false else {
            logger.error("Hotkeys: Do not start the HotkeysContoller more than once.")
            return
        }
        
        setUpEventMonitor()
        scanMenu()
        setMenuItemsToUserHotkeys(menu)
        rebuildListenerCache()
        
        
        self.setupComplete = true
    }
    
    
    // MARK: - Saving/Retrieving/Comparing a Hotkey
    
    /// Returns the user's chosen hotkey for the identifier. This  comes from either UserDefaults or the default values registered from menu items and additionalHotkeyItems
    @objc
    public func hotkey(withIdentifier identifier: String) -> HotkeyDescriptor? {
        // Check first to see if we have it loaded already
        if let item = allHotkeyItemsByIdentifier[identifier], let hotkey = item.hotkey {
            return hotkey
        }
        
        // Otherwise load it from UserDefaults
        if let data = UserDefaults.standard.data(forKey: ("IMHotkey-" + identifier)) {
            if let hotkey = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [HotkeyDescriptor.self, NSString.self, NSNumber.self], from: data) as? HotkeyDescriptor {
                return hotkey
            }
        }
        
        // Otherwise try to use the default hotkey
        if let item = allHotkeyItemsByIdentifier[identifier], let hotkey = item.defaultHotkey {
            return hotkey
        }
        
        return nil
    }
    
    /// Saves the hotkey to UserDefaults. Pass nil to remove an item.
    @objc
    public func save(hotkey: HotkeyDescriptor?, withIdentifier identifier: String) {
        if let hotkey = hotkey,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: hotkey, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: ("IMHotkey-" + identifier))
        }
        else {
            UserDefaults.standard.removeObject(forKey: ("IMHotkey-" + identifier))
        }
        
        // Make sure nobody changes anything out from under us without us updating for it
        if let item = allHotkeyItemsByIdentifier[identifier], item.hotkey != hotkey {
            item.hotkey = hotkey
            rebuildListenerCache()
            reloadTableView()
        }
    }
    
    @objc
    public func hotkey(withIdentifier identifier: String, matchesEvent event: NSEvent, preferKeyCode: Bool = false) -> Bool {
        guard let hotkey = hotkey(withIdentifier: identifier) else { return false }
        
        if preferKeyCode {
            return hotkey.matchesThroughKeyCode(event)
        }
        else {
            return hotkey.matchesThroughKeyEquivalent(event)
        }
    }
    
    
    
    // MARK: - Hotkey Actions
    
    /// Adding a hotkey action allows the HotkeysController to listen for the hotkey identified by `identifier` and fire the action as appropriate. Note there can only be one action per identifier.
    @objc
    public func addHotkeyActions(_ actions: [HotkeyAction]) {
        for action in actions {
            hotkeyActions[action.identifier] = action
        }
        rebuildListenerCache()
    }
    
    /// Removes a hotkey action associted with a particular identifier
    @objc
    public func removeHotkeyActions(withIdentifiers identifiers: [String]) {
        for identifier in identifiers {
            hotkeyActions.removeValue(forKey: identifier)
        }
        rebuildListenerCache()
    }
    
    private func setUpEventMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            return self?.handleEvent(event)
        }
    }
    
    private func handleEvent(_ event: NSEvent) -> NSEvent? {
        // If we handle the event, return nil; Otherwise, return event
        let keyCode = event.keyCode
        let character = event.charactersIgnoringModifiers?.lowercased()
        var consumeEvent = false
        
        if let keyCodeHotkeys = hotkeyListenerCacheKeycode[keyCode] {
            for (identifier, hotkey) in keyCodeHotkeys {
                if hotkey.matchesThroughKeyCode(event), let actionItem = hotkeyActions[identifier] {
                    consumeEvent = performAction(forItem: actionItem, usingModifiers: hotkey.modifierKeys)
                    break;
                }
            }
        }
        
        if consumeEvent == false, let keyEquivalent = character, let keyEquivalentHotkeys = hotkeyListenerCacheCharacter[keyEquivalent] {
            for (identifier, hotkey) in keyEquivalentHotkeys {
                if hotkey.matchesThroughKeyEquivalent(event), let actionItem = hotkeyActions[identifier] {
                    consumeEvent = performAction(forItem: actionItem, usingModifiers: hotkey.modifierKeys)
                    break;
                }
            }
        }
        
        return consumeEvent ? nil : event
    }
    
    private func performAction(forItem actionItem: HotkeyAction, usingModifiers modifiers: NSEvent.ModifierFlags) -> Bool {
        var performedAction = false
        
        // We don't want a hotkey that isn't using non-text modifiers (eg. just "a", or with shift, "A", or with option "å") to activate in a text field.
        // TODO: Yes, this does preclude some non-character things like shift-leftarrow. Need to find a way to detect only character-producing keys
        let hasNonTextModifiers = (modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.function))
        
        if let target = actionItem.target {
            _ = target.perform(actionItem.action, with: self)
            performedAction = true
        }
        else {
            var nextResponder = NSApp.keyWindow?.firstResponder
            while let responder = nextResponder {
                if !hasNonTextModifiers && (responder.isKind(of: NSTextField.self) || responder.isKind(of: NSTextView.self)) {
                    break;
                }
                
                if responder.responds(to: actionItem.action) {
                    _ = responder.perform(actionItem.action, with: self)
                    performedAction = true
                    break
                }
                if actionItem.fullResponderChain == false { break }
                nextResponder = responder.nextResponder
            }
        }
        
        return performedAction && actionItem.consumeEvent
    }
    
    private func rebuildListenerCache() {
        hotkeyListenerCacheKeycode.removeAll()
        hotkeyListenerCacheCharacter.removeAll()
        
        for identifier in hotkeyActions.keys {
            guard let hotkeyItem = allHotkeyItemsByIdentifier[identifier] else { continue }
            
            if let hotkey = hotkeyItem.hotkey {
                if hotkey.isEmpty == false {
                    if let keyEquivalent = hotkey.keyEquivalent?.lowercased(), hotkeyItem.menuStyle {
                        if hotkeyListenerCacheCharacter[keyEquivalent] == nil { hotkeyListenerCacheCharacter[keyEquivalent] = [] }
                        hotkeyListenerCacheCharacter[keyEquivalent]?.append((identifier, hotkey))
                    }
                    else {
                        if hotkeyListenerCacheKeycode[hotkey.keyCode] == nil { hotkeyListenerCacheKeycode[hotkey.keyCode] = [] }
                        hotkeyListenerCacheKeycode[hotkey.keyCode]?.append((identifier, hotkey))
                    }
                }
                // Else: Empty hotkeys are no-ops
                
            }
            // nil hotkey means try the default
            else if let defaultHotkey = hotkeyItem.defaultHotkey, defaultHotkey.isEmpty == false {
                if let keyEquivalent = defaultHotkey.keyEquivalent, hotkeyItem.menuStyle {
                    if hotkeyListenerCacheCharacter[keyEquivalent] == nil { hotkeyListenerCacheCharacter[keyEquivalent] = [] }
                    hotkeyListenerCacheCharacter[keyEquivalent]?.append((identifier, defaultHotkey))
                }
                else {
                    if hotkeyListenerCacheKeycode[defaultHotkey.keyCode] == nil { hotkeyListenerCacheKeycode[defaultHotkey.keyCode] = [] }
                    hotkeyListenerCacheKeycode[defaultHotkey.keyCode]?.append((identifier, defaultHotkey))
                }
            }
        }
        
    }
    
    // MARK: - Utilities
    
    private func scanMenu() {
        guard setupComplete == false else {
            logger.log("Hotkeys: Do not scan the menu more than once.")
            return
        }
        
        var items: Array<HotkeyItem> = []
        
        if let menu = menu {
            if menu.supermenu == nil {
                // We are dealing with the main menu, do each item in it separately
                for menuItem in menu.items {
                    if let submenu = menuItem.submenu {
                        scan(submenu: submenu, intoArray: &items)
                    }
                }
            }
            else {
                // We are dealing with a submenu, do it directly
                scan(submenu: menu, intoArray: &items)
            }
        }
        
        menuHotkeyItems = items
        
        allHotkeyItemsByIdentifier.removeAll()
        
        for item in menuHotkeyItems where item.isHeader == false {
            if let id = allHotkeyItemsByIdentifier[item.identifier] {
                logger.log("Warning: Hotkeys detected duplicate item identifiers: \(id)")
            }
            allHotkeyItemsByIdentifier[item.identifier] = item
        }
        
        for item in additionalHotkeyItems where item.isHeader == false {
            if let id = allHotkeyItemsByIdentifier[item.identifier] {
                logger.log("Warning: Hotkeys detected duplicate item identifiers: \(id)")
            }
            allHotkeyItemsByIdentifier[item.identifier] = item
        }
        
        checkItemsForSavedHotkeys()
        
        reloadTableView()
    }
    
    private func scan(submenu: NSMenu, intoArray allItems: inout Array<HotkeyItem>) {
        var hotkeyItems: Array<HotkeyItem> = []
        var submenus: Array<NSMenu> = []
        
        switch menuAutoInclusionPolicy {
        case .allItemsWithIdentifier:
            for menuItem in submenu.items {
                if menuItem.isSeparatorItem { continue; }
                
                if let newSubmenu = menuItem.submenu {
                    submenus.append(newSubmenu)
                }
                else {
                    if let identifier = menuItem.identifier?.rawValue, identifier.hasPrefix("_") == false && identifier.count > 0 && !exclusionIdentifiers.contains(identifier) {
                        hotkeyItems.append(hotkeyItem(for: menuItem))
                    }
                }
            }
            
        case .itemsWithHotkeySuffix:
            for menuItem in submenu.items {
                if menuItem.isSeparatorItem { continue; }
                
                if let newSubmenu = menuItem.submenu {
                    submenus.append(newSubmenu)
                }
                else {
                    if let identifier = menuItem.identifier?.rawValue, (identifier.hasSuffix("-hotkeyable") ||  inclusionIdentifiers.contains(identifier)) && !exclusionIdentifiers.contains(identifier) {
                        hotkeyItems.append(hotkeyItem(for: menuItem))
                    }
                }
            }
            
        case .explicitInclusionOnly:
            for menuItem in submenu.items {
                if menuItem.isSeparatorItem { continue; }
                
                if let newSubmenu = menuItem.submenu {
                    submenus.append(newSubmenu)
                }
                else {
                    if let identifier = menuItem.identifier?.rawValue, inclusionIdentifiers.contains(identifier) {
                        hotkeyItems.append(hotkeyItem(for: menuItem))
                    }
                }
            }
        }
        
        if hotkeyItems.count > 0 {
            let headerItem = HotkeyItem.headerItem(withTitle: fullTitle(for:submenu))
            allItems.append(headerItem)
            allItems += hotkeyItems
        }
        
        // Do the submenus at the end, so they are sorted after all the menu items in the parent submenu
        for menu in submenus {
            scan(submenu: menu, intoArray: &allItems)
        }
    }
    
    private func hotkeyItem(for menuItem: NSMenuItem) -> HotkeyItem {
        let defaultHotkey: HotkeyDescriptor?
        
        if let identifier = menuItem.identifier, let customItem = customMenuHotkeyItemsByIdentifier[identifier.rawValue] {
            return customItem
        }
        
        if menuItem.keyEquivalent.count > 0 {
            defaultHotkey = HotkeyDescriptor.hotkey(menuItem: menuItem)
        }
        else {
            defaultHotkey = nil
        }
        
        return HotkeyItem.item(withTitle: menuItem.title, identifier: menuItem.identifier?.rawValue ?? "", defaultHotkey: defaultHotkey)
    }
    
    private func fullTitle(for menu: NSMenu) -> String {
        let separator: String
        if let tableView = hotkeysTableView, tableView.userInterfaceLayoutDirection == .rightToLeft {
            separator = " ‹ "
        }
        else {
            separator = " › "
        }
        
        var title = menu.title
        var parent = menu.supermenu
        
        while let parentTitle = parent?.title {
            if parent?.supermenu == nil {
                title = NSLocalizedString("Main Menu", comment: "") + separator + title
            }
            else {
                title = parentTitle + separator + title
            }
            parent = parent?.supermenu
        }
        
        return title
    }
    
    private func checkItemsForSavedHotkeys() {
        for item in allHotkeyItemsByIdentifier.values {
            if let data = UserDefaults.standard.data(forKey: ("IMHotkey-" + item.identifier)) {
                if let hotkey = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [HotkeyDescriptor.self, NSString.self, NSNumber.self], from: data) as? HotkeyDescriptor {
                    item.hotkey = hotkey
                    continue
                }
            }
            item.hotkey = nil
        }
    }
    
    /// Scans through the given menu with the given criteria and sets any user-set hotkeys. This should be called once; just after the launch of the app and just after the other properties have been set (menu is required; hotkeysTableView is not)
    private func setMenuItemsToUserHotkeys(_ menu: NSMenu) {
        for menuItem in menu.items {
            if let submenu = menuItem.submenu {
                setMenuItemsToUserHotkeys(submenu)
            }
            else if let identifier = menuItem.identifier?.rawValue, let hotkeyItem = allHotkeyItemsByIdentifier[identifier] {
                setMenuItem(menuItem, withHotkeyItem: hotkeyItem)
            }
        }
    }
    
    private func setMenuItem(_ menuItem: NSMenuItem, withHotkeyItem hotkeyItem: HotkeyItem) {
        if let hotkey = hotkeyItem.hotkey {
            // Either set to no hotkey, or set to user-specified hotkey depending on whether it's empty
            if let keyEquivalent = hotkey.keyEquivalent {
                menuItem.keyEquivalentModifierMask = hotkey.modifierKeys
                menuItem.keyEquivalent = keyEquivalent.lowercased()
            }
            else if hotkey.isEmpty {
                menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags()
                menuItem.keyEquivalent = ""
            }
            else {
                // This shouldn't happen
                NSLog("Error, misconfigured hotkey for identifier \(hotkeyItem.identifier)")
            }
        }
        else {
            // Set to default, or nothing if there is no default
            if let defaultHotkey = hotkeyItem.defaultHotkey, let keyEquivalent = defaultHotkey.keyEquivalent {
                menuItem.keyEquivalentModifierMask = defaultHotkey.modifierKeys
                menuItem.keyEquivalent = keyEquivalent.lowercased()
            }
            else {
                menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags()
                menuItem.keyEquivalent = ""
            }
        }
    }
    
    private func menuItemWithIdentifier(_ identifier: String, inMenu menu: NSMenu) -> NSMenuItem? {
        for menuItem in menu.items {
            if let submenu = menuItem.submenu, let foundItem = menuItemWithIdentifier(identifier, inMenu: submenu) {
                return foundItem
            }
            else if let id = menuItem.identifier?.rawValue, id == identifier {
                return menuItem
            }
        }
        
        return nil
    }
    
}


// MARK: - TableView Data Source

extension HotkeysController: NSTableViewDataSource {
    
    @objc public func reloadTableView() {
        hotkeysTableView?.reloadData()
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        menuHotkeyItems.count + additionalHotkeyItems.count
    }

    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        itemAtRow(row)
    }
    
    private func itemAtRow(_ row: Int) -> HotkeyItem {
        if row >= additionalHotkeyItems.count {
            return menuHotkeyItems[row - additionalHotkeyItems.count]
        }
        else {
            return additionalHotkeyItems[row]
        }
    }
    
}
    
    // MARK: - TableView Delegate
    
extension HotkeysController: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let hotkeyItem = itemAtRow(row)
        
        if hotkeyItem.isHeader {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "header"), owner: self) as! HotkeyTableViewHeader? ?? makeHeaderRow()
            view.label.stringValue = hotkeyItem.title
            
            return view
        }
        else {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "standard"), owner: self) as! HotkeyTableViewRow? ?? makeStandardRow()
            view.label.stringValue = hotkeyItem.title
            view.defaultLabel.stringValue = hotkeyItem.defaultHotkey?.completeMenuStyleString(withNumberPadAnnotation: !hotkeyItem.menuStyle) ?? ""
            view.button.hotkey = hotkeyItem.hotkey
            view.button.defaultHotkey = hotkeyItem.defaultHotkey
            view.button.modifierRequirement = hotkeyItem.modifierRequirement
            view.button.menuStyle = hotkeyItem.menuStyle
            view.button.identifier = NSUserInterfaceItemIdentifier(rawValue: hotkeyItem.identifier)

            return view
        }
    }
    
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        let hotkeyItem = itemAtRow(row)
        return hotkeyItem.isHeader
    }
    
    private func makeHeaderRow() -> HotkeyTableViewHeader {
        let view = loadViewFromNib(name: "HeaderRow") as! HotkeyTableViewHeader
        view.identifier = NSUserInterfaceItemIdentifier(rawValue: "header")
        
        return view
    }
    
    private func makeStandardRow() -> HotkeyTableViewRow {
        let view = loadViewFromNib(name: "StandardRow") as! HotkeyTableViewRow
        view.identifier = NSUserInterfaceItemIdentifier(rawValue: "standard")
        view.button.delegate = self
        
        return view
    }
    
    /// Obviously all the code in here is dangerous. It should only crash if the nib is misconfigured, which we will know immediately.
    private func loadViewFromNib(name: String) -> NSView {
        var topLevelObjects: NSArray? = nil
        Bundle.module.loadNibNamed(name, owner: self, topLevelObjects: &topLevelObjects)
        
        // For some reason, NSApplication is one of the top-level objects! (I would expect only one, our view.) So, filter...
        var foundView: NSView? = nil
        for object in topLevelObjects! {
            if (object as! NSObject).isKind(of: NSView.self) {
                foundView = object as? NSView
                break;
            }
        }
        
        return foundView!
    }
    
}
    
    // MARK: - Hotkey Button Delegate
    
extension HotkeysController: HotkeyButtonDelegate {
    
    @objc 
    public func hotkeyButton(_ button: HotkeyButton, updatedHotkey hotkey: HotkeyDescriptor?) {
        guard let identifier = button.identifier?.rawValue, let hotkeyItem = allHotkeyItemsByIdentifier[identifier] else { return }
        // Update the item we have stored
        hotkeyItem.hotkey = hotkey
        
        // Update the menu item itself
        if let menu = menu, let menuItem = menuItemWithIdentifier(hotkeyItem.identifier, inMenu: menu) {
            setMenuItem(menuItem, withHotkeyItem: hotkeyItem)
        }
        
        // Finally, update UserDefaults
        save(hotkey: hotkey, withIdentifier: identifier)
        
        // Rebuild in case this hotkey was one we were listening for
        rebuildListenerCache()
    }

}

