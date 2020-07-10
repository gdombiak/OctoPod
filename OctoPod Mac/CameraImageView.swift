//
//  CameraImageView.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/29/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Foundation
import Cocoa
import Carbon.HIToolbox
class CameraImageView: NSImageView {
    private var currentOrientation = 0
    lazy var bedTemp = newLabel()
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2{
            toggleFullScreen()
        }
    }
    override func rotate(byDegrees angle: CGFloat) {
        //restore from existing rotation
        super.rotate(byDegrees: CGFloat(-currentOrientation))
        //apply new rotation
        super.rotate(byDegrees: CGFloat(angle))
        currentOrientation = Int(angle)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape{
            toggleFullScreen()
        }
    }
    private func toggleFullScreen(){
        if !self.isInFullScreenMode{
            self.enterFullScreenMode(NSScreen.main!, withOptions: nil)
            //self.addSubview(bedTemp)
            
        }else{
            self.exitFullScreenMode(options: nil)
            (NSApp.delegate as! AppDelegate).showQuickView()
           // bedTemp.removeFromSuperview()
        }
    }
    private func newLabel() -> NSTextField {
        let label = NSTextField(frame: NSMakeRect(0,0,100,50))
        label.stringValue = "BOOM"
        label.isEditable = false
        label.isSelectable = false
        label.textColor = .labelColor
        label.backgroundColor = .controlColor
        label.drawsBackground = false
        label.isBezeled = false
        label.alignment = .natural
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: label.controlSize))
        label.lineBreakMode = .byClipping
        label.cell?.isScrollable = false
        label.cell?.wraps = false
        return label
    }
}
