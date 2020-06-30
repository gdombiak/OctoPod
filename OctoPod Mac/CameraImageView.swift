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
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2{
            toggleFullScreen()
        }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape{
            toggleFullScreen()
        }
    }
    private func toggleFullScreen(){
        if !self.isInFullScreenMode{
            self.enterFullScreenMode(NSScreen.main!, withOptions: nil)
            
        }else{
            
            self.exitFullScreenMode(options: nil)
        }
    }
}
