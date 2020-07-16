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
    private lazy var printerStatusOverlay = overlayableLabel()
    private var extruderTempDisplay = 0.0
    private var bedTempDisplay = 0.0
    private var progress = "-"
    private var timeLeft = "-"
    private var progressCompletionDisplay = 0.0
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2{
            toggleFullScreen()
        }
    }
    override func rotate(byDegrees angle: CGFloat) {
        DispatchQueue.main.async {
        //restore from existing rotation
        super.rotate(byDegrees: CGFloat(-self.currentOrientation))
        //apply new rotation
        super.rotate(byDegrees: CGFloat(angle))
        }
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
            //overlayPrinterDetails(visible: true)
            
        }else{
            self.exitFullScreenMode(options: nil)
            (NSApp.delegate as! AppDelegate).showQuickView()
            //overlayPrinterDetails(visible: false)
        }
    }
    func setPrinerDetails(printerStatus:String?,actualExtruderTemp:Double?,targetExtruderTemp:Double?,actualBedTemp:Double?,targetBedTemp:Double?,progressPrintTime:Int?,progressPrintTimeLeft:Int?, progressCompletion:Double?){
        extruderTempDisplay = actualExtruderTemp ?? extruderTempDisplay
        bedTempDisplay = actualBedTemp ?? bedTempDisplay
        let progressPrintTimeLeftDouble = Double(progressPrintTimeLeft ?? 0)
        timeLeft = UIUtils.secondsToEstimatedPrintTime(seconds: progressPrintTimeLeftDouble)
        progressCompletionDisplay = progressCompletion?.round(to: 1) ?? progressCompletionDisplay
        printerStatusOverlay.stringValue = "Extruder:\(extruderTempDisplay) Bed:\(bedTempDisplay) Complete: \(progressCompletionDisplay)%"
    }
    func overlayPrinterDetails(visible:Bool) {
        if(visible){
            let x = 20
            let y = 20
            printerStatusOverlay.setFrameOrigin(CGPoint(x: x, y: y))
            

            self.addSubview(printerStatusOverlay)
        }
        else{
            printerStatusOverlay.removeFromSuperview()
        }
    }

    private func overlayableLabel() -> NSTextField {
        let screenWidth = NSScreen.main?.frame.width ?? 100
        let label = NSTextField(frame: NSMakeRect(0,0,screenWidth - 200,25))
        label.isEditable = false
        label.isSelectable = false
        label.textColor = .labelColor
        let backgroundColor = NSColor.controlBackgroundColor
        label.backgroundColor = backgroundColor.withAlphaComponent(CGFloat(0.5))
        label.drawsBackground = true
        label.isBezeled = false
        label.alignment = .natural
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: label.controlSize))
        label.lineBreakMode = .byClipping
        label.cell?.isScrollable = false
        label.cell?.wraps = false
        return label
    }
}
