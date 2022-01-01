import Foundation
import UIKit

// Users can select different themes as a way to control the colors that the UI should use
class Theme {
    private static let DEFAULT_THEME = "DEFAULT_THEME"
    
    private static var current: ThemeChoice?
    
    enum ThemeChoice: Int {
        case Light = 1
        case Dark = 2
        case Orange = 3
        case OctoPrint = 4
        case System = 5

        func navigationTopColor(octoPrintColor: String?) -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 218/255, green: 218/255, blue: 219/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 242/255, green: 104/255, blue: 45/255, alpha: 1.0)
            case .OctoPrint:
                return octoprintNavTopColor(octoPrintColor)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        /// Return the color for Light Mode. Same as OctoPrint color
                        return self.octoprintNavTopColor(octoPrintColor)
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 218/255, green: 218/255, blue: 219/255, alpha: 1.0)
                }
            }
        }
        
        func navigationTitleColor(octoPrintColor: String?) -> UIColor {
            switch self {
            case .Light:
                return UIColor.black
            case .Dark, .Orange:
                return UIColor.white
            case .OctoPrint:
                return octoprintNavTitleColor(octoPrintColor)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        /// Return the color for Light Mode. Same as OctoPrint color
                        return self.octoprintNavTitleColor(octoPrintColor)
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor.black
                }
            }
        }

        func navigationTintColor(octoPrintColor: String?) -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 251/255, green: 251/255, blue: 251/255, alpha: 1.0)
            case .OctoPrint:
                return octoprintNavTintColor(octoPrintColor)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            /// Use title color when in dark mode and using system theme
                            return self.octoprintNavTitleColor(octoPrintColor)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return self.octoprintNavTintColor(octoPrintColor)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
                }
            }
        }
        
        func tabBarColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor(red: 246/255, green: 246/255, blue: 248/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 246/255, green: 246/255, blue: 248/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 246/255, green: 246/255, blue: 248/255, alpha: 1.0)
                }
            }
        }
        
        func backgroundColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 239/255, green: 239/255, blue: 244/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 47/255, green: 51/255, blue: 55/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 47/255, green: 51/255, blue: 55/255, alpha: 1.0)
            case .OctoPrint:
                return UIColor(red: 212/255, green: 212/255, blue: 208/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 47/255, green: 51/255, blue: 55/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 212/255, green: 212/255, blue: 208/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 239/255, green: 239/255, blue: 244/255, alpha: 1.0)
                }
            }
        }
        
        func cellBackgroundColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 56/255, green: 58/255, blue: 63/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 56/255, green: 58/255, blue: 63/255, alpha: 1.0)
            case .OctoPrint:
                return UIColor(red: 225/255, green: 225/255, blue: 220/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 56/255, green: 58/255, blue: 63/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 225/255, green: 225/255, blue: 220/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
                }
            }
        }
        
        func separatorColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 235/255, green: 234/255, blue: 236/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 40/255, green: 42/255, blue: 46/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 40/255, green: 42/255, blue: 46/255, alpha: 1.0)
            case .OctoPrint:
                return UIColor(red: 235/255, green: 235/255, blue: 226/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 40/255, green: 42/255, blue: 46/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 235/255, green: 235/255, blue: 226/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 235/255, green: 234/255, blue: 236/255, alpha: 1.0)
                }
            }
        }
        
        func labelColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor.black
            case .Dark:
                return UIColor.white
            case .Orange:
                return UIColor(red: 242/255, green: 105/255, blue: 45/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor.white
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor.black
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor.black
                }
            }
        }
        
        func textColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor.darkGray
            case .Dark:
                return UIColor(red: 134/255, green: 137/255, blue: 142/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 134/255, green: 137/255, blue: 142/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 134/255, green: 137/255, blue: 142/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor.darkGray
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor.darkGray
                }
            }
        }

        func tintColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 75/255, green: 166/255, blue: 219/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 247/255, green: 150/255, blue: 109/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 75/255, green: 166/255, blue: 219/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
                }
            }
        }

        func placeholderColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor(red: 61.2/255, green: 61.2/255, blue: 66.3/255, alpha: 0.3)
            case .Dark:
                return UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 0.4)
            case .Orange:
                return UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 0.4)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 0.4)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 61.2/255, green: 61.2/255, blue: 66.3/255, alpha: 0.3)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 61.2/255, green: 61.2/255, blue: 66.3/255, alpha: 0.3)
                }
            }
        }

        func currentPageIndicatorTintColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
            case .Dark, .Orange:
                return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
                }
            }
        }

        func pageIndicatorTintColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor(red: 182/255, green: 182/255, blue: 182/255, alpha: 1.0)
            case .Dark, .Orange:
                return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 182/255, green: 182/255, blue: 182/255, alpha: 1.0)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 182/255, green: 182/255, blue: 182/255, alpha: 1.0)
                }
            }
        }

        func tableHeaderFooterTextColor() -> UIColor {
            switch self {
            case .Light, .OctoPrint:
                return UIColor(red: 61.2/255, green: 61.2/255, blue: 66.3/255, alpha: 0.6)
            case .Dark, .Orange:
                return UIColor(red: 224/255, green: 224/255, blue: 224/255, alpha: 0.6)
            case .System:
                if #available(iOS 13, *) {
                    return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                        if UITraitCollection.userInterfaceStyle == .dark {
                            /// Return the color for Dark Mode. Same as Dark color
                            return UIColor(red: 224/255, green: 224/255, blue: 224/255, alpha: 0.6)
                        } else {
                            /// Return the color for Light Mode. Same as OctoPrint color
                            return UIColor(red: 61.2/255, green: 61.2/255, blue: 66.3/255, alpha: 0.6)
                        }
                    }
                } else {
                    /// Return a fallback color for iOS 12 and lower. Fall back to Light color
                    return UIColor(red: 61.2/255, green: 61.2/255, blue: 66.3/255, alpha: 0.6)
                }
            }
        }

        // MARK: - Private functions

        fileprivate func octoprintNavTopColor(_ octoPrintColor: String?) -> UIColor {
            if let color = octoPrintColor {
                if color == "default" {
                    return UIColor(red: 213/255, green: 213/255, blue: 213/255, alpha: 1.0)
                } else if color == "red" {
                    return UIColor(red: 168/255, green: 81/255, blue: 77/255, alpha: 1.0)
                } else if color == "orange" {
                    return UIColor(red: 215/255, green: 127/255, blue: 81/255, alpha: 1.0)
                } else if color == "yellow" {
                    return UIColor(red: 210/255, green: 195/255, blue: 82/255, alpha: 1.0)
                } else if color == "green" {
                    return UIColor(red: 141/255, green: 236/255, blue: 111/255, alpha: 1.0)
                } else if color == "blue" {
                    return UIColor(red: 35/255, green: 86/255, blue: 182/255, alpha: 1.0)
                } else if color == "violet" {
                    return UIColor(red: 113/255, green: 51/255, blue: 223/255, alpha: 1.0)
                } else if color == "black" {
                    return UIColor(red: 79/255, green: 79/255, blue: 79/255, alpha: 1.0)
                } else if color == "white" {
                    return UIColor(red: 217/255, green: 217/255, blue: 217/255, alpha: 1.0)
                } else {
                    // Unknown color so use default color
                    return UIColor(red: 218/255, green: 218/255, blue: 219/255, alpha: 1.0)
                }
            } else {
                // No printer defined so use default color
                return UIColor(red: 218/255, green: 218/255, blue: 219/255, alpha: 1.0)
            }
        }
        
        fileprivate func octoprintNavTitleColor(_ octoPrintColor: String?) -> UIColor {
            if let color = octoPrintColor {
                if color == "yellow" {
                    return UIColor.black
                } else if color == "white" {
                    return UIColor.black
                } else {
                    return UIColor.white
                }
            } else {
                // No printer defined so use default color
                return UIColor.black
            }
        }
        
        fileprivate func octoprintNavTintColor(_ octoPrintColor: String?) -> UIColor {
            if let color = octoPrintColor {
                if color == "default" || color == "green" || color == "white"{
                    return UIColor.black
                } else if color == "red" || color == "orange" || color == "yellow" || color == "blue" || color == "violet" || color == "black" {
                    return UIColor.white
                } else {
                    // Unknown color so use default color
                    return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
                }
            } else {
                // No printer defined so use default color
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            }
        }
    }

    class func currentTheme() -> ThemeChoice {
        if let currentTheme = current {
            // Use cached value to prevent extra work
            return currentTheme
        }
        
        if let stored = UserDefaults.standard.object(forKey: DEFAULT_THEME) as? Int {
            current = ThemeChoice(rawValue: stored)!
        } else {
            current = ThemeChoice.Dark
        }
        return current!
    }

    class func switchTheme(choice: ThemeChoice) {
        current = choice
        UserDefaults.standard.set(choice.rawValue, forKey: DEFAULT_THEME)
    }
}
