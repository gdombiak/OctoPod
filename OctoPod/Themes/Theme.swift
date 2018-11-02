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

        func navigationTopColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 247/255, green: 247/255, blue: 248/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 242/255, green: 104/255, blue: 45/255, alpha: 1.0)
            }
        }
        
        func navigationTintColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 251/255, green: 251/255, blue: 251/255, alpha: 1.0)
            }
        }
        
        func tabBarColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 246/255, green: 246/255, blue: 248/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            }
        }
        
        func backgroundColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 239/255, green: 239/255, blue: 244/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 53/255, green: 57/255, blue: 62/255, alpha: 1.0)
            }
        }
        
        func cellBackgroundColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 47/255, green: 49/255, blue: 53/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 47/255, green: 49/255, blue: 53/255, alpha: 1.0)
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
            }
        }
        
        func labelColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor.black
            case .Dark:
                return UIColor.white
            case .Orange:
                return UIColor(red: 242/255, green: 105/255, blue: 45/255, alpha: 1.0)
            }
        }
        
        func textColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor.darkGray
            case .Dark:
                return UIColor(red: 134/255, green: 137/255, blue: 142/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 134/255, green: 137/255, blue: 142/255, alpha: 1.0)
            }
        }

        func tintColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 0/255, green: 122.4/255, blue: 255/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 242/255, green: 105/255, blue: 45/255, alpha: 1.0)
            }
        }

        func currentPageIndicatorTintColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
            }
        }

        func pageIndicatorTintColor() -> UIColor {
            switch self {
            case .Light:
                return UIColor(red: 182/255, green: 182/255, blue: 182/255, alpha: 1.0)
            case .Dark:
                return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
            case .Orange:
                return UIColor(red: 93/255, green: 97/255, blue: 101/255, alpha: 1.0)
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

