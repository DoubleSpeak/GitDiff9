//
//  AppDelegate.swift
//  LNProvider
//
//  Created by John Holdsworth on 31/03/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet var defaults: DefaultManager!

    @IBOutlet var formatChecked: NSButton!
    @IBOutlet var gitDiffChecked: NSButton!
    @IBOutlet var gitBlameChecked: NSButton!
    @IBOutlet var unusedChecked: NSButton!

    var services = [LNExtensionClient]()
    private var statusItem: NSStatusItem!

    var buttonMap: [NSButton: String] {
        return [
            formatChecked: "com.johnholdsworth.FormatRelay",
            gitDiffChecked: "com.johnholdsworth.GitDiffRelay",
            gitBlameChecked: "com.johnholdsworth.GitBlameRelay",
            unusedChecked: "com.johnholdsworth.UnusedRelay",
        ]
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Insert code here to initialize your application
        startServiceAndRegister(checkButton: formatChecked)
        startServiceAndRegister(checkButton: gitDiffChecked)
        startServiceAndRegister(checkButton: gitBlameChecked)
        startServiceAndRegister(checkButton: unusedChecked)
        let statusBar = NSStatusBar.system()
        statusItem = statusBar.statusItem(withLength: statusBar.thickness)
        statusItem.toolTip = "LineNumber"
        statusItem.highlightMode = true
        statusItem.target = self
        statusItem.action = #selector(show(sender:))
        statusItem.isEnabled = true
        statusItem.title = ""
        setMenuIcon(tiffName: "icon_16x16")
        window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark)
    }

    func setMenuIcon(tiffName: String) {
        if let path = Bundle.main.path(forResource: tiffName, ofType: "tiff") {
            statusItem.image = NSImage(contentsOfFile: path)
            statusItem.alternateImage = statusItem.image
        }
    }

    @IBAction func show(sender: Any) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func startServiceAndRegister(checkButton: NSButton) {
        if checkButton.state == NSOnState, let serviceName = buttonMap[checkButton] {
            services.append(LNExtensionClient(serviceName: serviceName, delegate: nil))
        }
    }

    @IBAction func serviceDidChange(checkButton: NSButton) {
        if checkButton.state == NSOnState {
            startServiceAndRegister(checkButton: checkButton)
        } else if let serviceName = buttonMap[checkButton] {
            services.first(where: { $0.serviceName == serviceName })?.deregister()
            services = services.filter { $0.serviceName != serviceName }
        }
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
        _ = services.map { $0.deregister() }
    }

}
