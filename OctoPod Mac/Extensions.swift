//
//  Extensions.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/30/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Foundation

extension Double {
    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
