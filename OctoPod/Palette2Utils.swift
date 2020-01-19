import Foundation

class Palette2Utils {

    static func pingPongMessage(history: Array<Dictionary<String,Any>>, index: Int, reversed: Bool) -> (number: String, percent: String, variance: String)? {
        if history.count > index && index >= 0 {
            let entry = history[index]
            var variance = "-- %"
            if let number = entry["number"] as? Int, let percent = entry["percent"] as? String {
                return ("\(number)" , percent == "MISSED" ? NSLocalizedString("Missed", comment: "") : "\(percent) %", variance)
            } else if let number = entry["number"] as? Int, let percent = entry["percent"] as? Double {
                // New version 2.3.1 of Palette 2 plugin uses Float(in Python) for sending percent. It used to be a String in previous versions.
                // String is still used for indicating MISSED in this version
                if reversed {
                    if index < history.count - 1, let previousPrct = history[index + 1]["percent"] as? Double {
                        variance = "\(String(format: "%.2f", abs(percent - previousPrct)))%"
                    }
                } else {
                    if index > 0, let previousPrct = history[index - 1]["percent"] as? Double {
                        variance = "\(String(format: "%.2f", abs(percent - previousPrct)))%"
                    }
                }
                return ("\(number)" , "\(String(format: "%.2f", percent))%", variance)
            }
        }
        return nil
    }

    static func pingPongVarianceStats(history: Array<Dictionary<String,Any>>, reversed: Bool) -> (max: String, average: String, min: String)? {
        var maxVariance = 0.0, totalVariance = 0.0, countVariance = 0.0, minVariance = 0.0
        for (index, entry) in history.enumerated() {
            var variance: Double?
            if let percent = entry["percent"] as? Double {
                if reversed {
                    if index < history.count - 1, let previousPrct = history[index + 1]["percent"] as? Double {
                        variance = abs(percent - previousPrct)
                    }
                } else {
                    if index > 0, let previousPrct = history[index - 1]["percent"] as? Double {
                        variance = abs(percent - previousPrct)
                    }
                }
                if let variance = variance {
                    countVariance += 1
                    totalVariance += variance
                    if maxVariance < variance {
                        maxVariance = variance
                    }
                    if minVariance == 0 || minVariance > variance {
                        minVariance = variance
                    }
                }
            }
        }
        let averageVariance = countVariance > 0 ? totalVariance / countVariance : 0.0
        return ("\(String(format: "%.2f", maxVariance))%", "\(String(format: "%.2f", averageVariance))%", "\(String(format: "%.2f", minVariance))%")
    }
}
