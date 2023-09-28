//
//  HotkeyTableViews.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 9/28/23.
//  Copyright © 2023 Andreas Schwarz. All rights reserved.
//

import Cocoa

// TODO: Eventually, these items should be changed from nibs to programmatic UI.

@objc
internal class HotkeyTableViewHeader: NSView {
    @IBOutlet var label: NSTextField!
}

@objc
internal class HotkeyTableViewRow: NSView {
    @IBOutlet var label: NSTextField!
    @IBOutlet var defaultLabel: NSTextField!
    @IBOutlet var button: HotkeyButton!
}
