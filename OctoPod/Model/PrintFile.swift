import Foundation

class PrintFile {
    private static let SORT_BY_PREFERENCE = "filesSortBy"
    
    enum SortBy: Int {
        case uploadDate = 0
        case alphabetical = 1
        case lastPrintDate = 2
    }
    
    var display: String!
    var name: String?
    var path: String?  // The path to the file or folder within the location. E.g. “folder/subfolder/file.gco” for a file “file.gco” located within “folder” and “subfolder” relative to the root of the location
    var type: String?  // Type of file. model or machinecode. Or folder if it’s a folder, in which case the children node will be populated

    var origin: String?  // The origin of the file, local when stored in OctoPrint’s uploads folder, sdcard when stored on the printer’s SD card (if available)
    
    var size: Int?

    var estimatedPrintTime: Double?
    var date: Date?  // Date when this file was uploaded. Only available for files stored in OctoPrint

    var lastPrintDate: Date?  // Date when this file was printed last time

    var children: Array<PrintFile>?  // This is used by folders to track files in the folder and subfolders
    
    // Returns true if file can be sent to be printed
    func canBePrinted() -> Bool {
        return type == "machinecode"
    }
    
    func canBeDeleted() -> Bool {
        return type != "folder"
    }

    func displayOrigin() -> String {
        if let currentOrigin = origin {
            if currentOrigin == "local" {
                return NSLocalizedString("OctoPrint", comment: "OctoPrint server")
            } else if currentOrigin == "sdcard" {
                return NSLocalizedString("SD Card", comment: "Origin is SD Card")
            } else {
                return NSLocalizedString("Unknown", comment: "Origin is Unknown")
            }
        }
        return ""
    }
    
    func displayType() -> String {
        if let currentOrigin = type {
            if currentOrigin == "model" {
                return NSLocalizedString("Model", comment: "File Type is a Model")
            } else if currentOrigin == "machinecode" {
                return NSLocalizedString("Code", comment: "File Type is GCode")
            } else if currentOrigin == "folder" {
                return NSLocalizedString("Folder", comment: "File Type is a Folder")
            }
        }
        return NSLocalizedString("Unknown", comment: "File Type is Unknown")
    }
    
    func displaySize() -> String {
        if let currentSize = size {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useKB, .useMB]
            bcf.countStyle = .file
            return bcf.string(fromByteCount: Int64(currentSize))
        }
        return ""
    }
    
    func isFolder() -> Bool {
        return type == "folder"
    }
    
    func isModel() -> Bool {
        return type == "model"
    }
    
    // Do a recursive search for the specified file/folder
    func locate(file: PrintFile) -> PrintFile? {
        if origin == file.origin && path == file.path && type == file.type {
            return self
        } else {
            // Check if any of my children has the specified file
            if let children = self.children {
                for child in children {
                    if let found = child.locate(file: file) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Sort operations

    // Returns default sort criteria to use (based on user preferences)
    class func defaultSortCriteria() -> SortBy {
        let defaults = UserDefaults.standard
        if let storedValue = defaults.object(forKey: SORT_BY_PREFERENCE) as? Int {
            return SortBy(rawValue: storedValue)!
        }
        return SortBy.alphabetical
    }
    
    // Sort all (including nested) files with specified sort criteria.
    // Returns provided files sorted
    class func resort(rootFiles: Array<PrintFile>, sortBy: SortBy) -> Array<PrintFile> {
        // Sort root files
        let sortedRootFiles = sort(files: rootFiles, sortBy: sortBy)
        // Sort nested children of root files
        for file in sortedRootFiles {
            if let children = file.children {
                file.children = resort(rootFiles: children, sortBy: sortBy)
            }
        }
        return sortedRootFiles
    }
    
    // Sort files by user prefered sort criteria (does not sort in nested elements)
    class func sort(files: Array<PrintFile>, sortBy: SortBy?) -> Array<PrintFile> {
        var useSort: SortBy
        if let newSortBy = sortBy {
            useSort = newSortBy
            // Store sort by as user preference
            let defaults = UserDefaults.standard
            defaults.set(newSortBy.rawValue, forKey: SORT_BY_PREFERENCE)
        } else {
            // Use default sort criteria based on user preferences
            useSort = defaultSortCriteria()
        }
        
        switch useSort {
        case SortBy.alphabetical:
            return sortByAlphabeticalOrder(files: files)
        case SortBy.uploadDate:
            return sortByUploadDate(files: files)
        case SortBy.lastPrintDate:
            return sortByLastPrintDate(files: files)
        }
    }

    // Sorts specified list of files by alphabetical order
    // Folders first and files second
    fileprivate class func sortByAlphabeticalOrder(files: Array<PrintFile>) -> Array<PrintFile> {
        return files.sorted { (file1: PrintFile, file2: PrintFile) -> Bool in
            if file1.isFolder() && file2.isFolder() {
                // Both are folders so sort by display
                return file1.display < file2.display
            } else if file1.isFolder() {
                // File 1 is a folder but not file 2
                return true
            } else if file2.isFolder() {
                // File 2 is a folder but not file 1
                return false
            } else {
                // There is some weird bug where Files coming from OctoPrint have no display so app
                // is crashing. Add these checks just in case
                if file1.display == nil {
                    return true
                }
                if file2.display == nil {
                    return false
                }
                // They are both files (not folders)
                return file1.display < file2.display
            }
        }
    }
    
    // Sorts specified list of files by upload date. Files from SD Card have no date so put them at the bottom sorted by 'display'
    // Folders first and files second
    fileprivate class func sortByUploadDate(files: Array<PrintFile>) -> Array<PrintFile> {
        return files.sorted { (file1: PrintFile, file2: PrintFile) -> Bool in
            if file1.isFolder() && file2.isFolder() {
                // Both are folders.
                return compareDate(file1: file1, file2: file2)
            } else if file1.isFolder() {
                // File 1 is a folder but not file 2
                return true
            } else if file2.isFolder() {
                // File 2 is a folder but not file 1
                return false
            } else {
                // They are both files (not folders)
                return compareDate(file1: file1, file2: file2)
            }
        }
    }
    
    // Sorts specified list of files by last print date. Files from SD Card have no date so put them at the bottom sorted by 'display'
    // Folders first and files second
    fileprivate class func sortByLastPrintDate(files: Array<PrintFile>) -> Array<PrintFile> {
        return files.sorted { (file1: PrintFile, file2: PrintFile) -> Bool in
            if file1.isFolder() && file2.isFolder() {
                // Both are folders.
                return compareLastPrintDate(file1: file1, file2: file2)
            } else if file1.isFolder() {
                // File 1 is a folder but not file 2
                return true
            } else if file2.isFolder() {
                // File 2 is a folder but not file 1
                return false
            } else {
                // They are both files (not folders)
                return compareLastPrintDate(file1: file1, file2: file2)
            }
        }
    }
    
    fileprivate class func compareDate(file1: PrintFile, file2: PrintFile) -> Bool {
        let date1: Date? = file1.newestUploadDate()
        let date2: Date? = file2.newestUploadDate()
        if date1 != nil && date2 != nil {
            // Both folder have files so sort by newest file inside of the folders
            return date1! > date2!
        } else if date1 != nil {
            return true
        } else if date2 != nil {
            return false
        } else {
            // Both folder have no files so sort by display
            return file1.display < file2.display
        }
    }
    
    fileprivate func newestUploadDate() -> Date? {
        if isFolder() {
            if let children = self.children {
                // Get newest upload date from the children
                var newest: Date?
                for file in children {
                    if let date = file.newestUploadDate() {
                        if newest == nil {
                            newest = date
                        } else if date > newest! {
                            newest = date
                        }
                    }
                }
                return newest
            }
            // Folder with no children then has no date (since there is no upload date for a folder)
            return nil
        }
        // Return upload date of the file (if there is one)
        return date
    }

    fileprivate class func compareLastPrintDate(file1: PrintFile, file2: PrintFile) -> Bool {
        let date1: Date? = file1.newestLastPrintDate()
        let date2: Date? = file2.newestLastPrintDate()
        if date1 != nil && date2 != nil {
            // Both folder have files so sort by newest file inside of the folders
            return date1! > date2!
        } else if date1 != nil {
            return true
        } else if date2 != nil {
            return false
        } else {
            // Both folder have no files so sort by display
            return file1.display < file2.display
        }
    }
    
    fileprivate func newestLastPrintDate() -> Date? {
        if isFolder() {
            if let children = self.children {
                // Get latest print date from the children
                var newest: Date?
                for file in children {
                    if let date = file.newestLastPrintDate() {
                        if newest == nil {
                            newest = date
                        } else if date > newest! {
                            newest = date
                        }
                    }
                }
                return newest
            }
            // Folder with no children then has no date (since there is no last print date for a folder)
            return nil
        }
        // Return last print date of the file (if there is one)
        return lastPrintDate
    }
    
    // MARK: - Parse operations

    func parse(json: NSDictionary) {
        if let newDisplay = json["display"] as? String {
            display = newDisplay
        }
        if let newName = json["name"] as? String {
            name = newName
        }
        if let newPath = json["path"] as? String {
            path = newPath
        }
        if let newType = json["type"] as? String {
            type = newType
        }
        if let newOrigin = json["origin"] as? String {
            origin = newOrigin
        }
        if let newSize = json["size"] as? Int {
            size = newSize
        }
        if let gcodeAnalysis = json["gcodeAnalysis"] as? NSDictionary {
            if let newPrintTime = gcodeAnalysis["estimatedPrintTime"] as? Double {
                estimatedPrintTime = newPrintTime
            }
        }
        if let newDate = json["date"] as? Double {
            date = Date(timeIntervalSince1970: newDate)
        }
        if let prints = json["prints"] as? NSDictionary {
            if let last = prints["last"] as? NSDictionary {
                if let newDate = last["date"] as? Double {
                    lastPrintDate = Date(timeIntervalSince1970: newDate)
                }
            }
        }
        if let children = json["children"] as? NSArray {
            var newChildren = Array<PrintFile>()
            for child in children {
                if let subJSON = child as? NSDictionary {
                    let childPrintFile = PrintFile()
                    childPrintFile.parse(json: subJSON)
                    newChildren.append(childPrintFile)
                }
            }
            // Sort files by user prefered sort criteria
            self.children = PrintFile.sort(files: newChildren, sortBy: nil)
        }
    }
}
