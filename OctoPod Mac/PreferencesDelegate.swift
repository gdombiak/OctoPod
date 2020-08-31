//
//  PreferencesDelegate.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 7/4/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Foundation
protocol PreferencesDelegate: class {
    func printerAdded(printer: Printer)
    func printerDeleted(printer: Printer)
    func printerUpdated(printer: Printer)
    func cameraOrientationChanged(newOrientation: Int)
}
