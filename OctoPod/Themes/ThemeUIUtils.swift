import Foundation
import UIKit

class ThemeUIUtils {
    
    class func themeCell(cell: UITableViewCell) {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()
        
        cell.backgroundColor = theme.cellBackgroundColor()
        cell.textLabel?.textColor = textColor
        cell.detailTextLabel?.textColor = textColor
    }
    
    class func applyTheme(table: UITableView, staticCells: Bool) {
        let theme = Theme.currentTheme()
        table.separatorColor = theme.separatorColor()
        table.sectionIndexBackgroundColor = theme.backgroundColor()
        table.backgroundColor = staticCells ? theme.backgroundColor() : theme.cellBackgroundColor()
    }
    
}
