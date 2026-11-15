import CoreData
import Foundation

class TVPrinterManager: ObservableObject, CloudKitPrinterDelegate {
    @Published private(set) var printers: [Printer] = []
    @Published private(set) var page = 1
    @Published private(set) var iCloudConnected = true

    let printerManager: PrinterManager
    let cloudKitPrinterManager: CloudKitPrinterManager

    private struct ConnectionConfiguration: Equatable {
        let hostname: String
        let apiKey: String
        let username: String?
        let password: String?
        let headers: String?
        let connectionType: Int16
        let sharedNozzle: Bool

        init(printer: Printer) {
            hostname = printer.hostname
            apiKey = printer.apiKey
            username = printer.username
            password = printer.password
            headers = printer.headers
            connectionType = printer.connectionType
            sharedNozzle = printer.sharedNozzle
        }
    }

    private(set) var connections: [NSManagedObjectID: (websocket: ViewService, cameraService: CameraService)] = [:]
    private var connected: [NSManagedObjectID: ConnectionConfiguration] = [:]
    private var failedConnections: Set<NSManagedObjectID> = []
    private var activeCameras: Set<NSManagedObjectID> = []
    private var detailedPrinterID: NSManagedObjectID?
    private var isActive = false
    private let printersPerPage = 4

    var pages: Int {
        (printers.count + printersPerPage - 1) / printersPerPage
    }

    var visiblePrinters: [Printer] {
        Array(printers.dropFirst((page - 1) * printersPerPage).prefix(printersPerPage))
    }

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager) {
        self.printerManager = printerManager
        self.cloudKitPrinterManager = cloudKitPrinterManager
        updatePrinters(printerManager.getPrinters())
        cloudKitPrinterManager.delegates.append(self)
    }

    func showPage(_ page: Int) {
        guard (1...max(1, pages)).contains(page), page != self.page else { return }
        self.page = page
        reconcileConnections()
    }

    func suspendConnections() {
        isActive = false
        reconcileConnections()
    }

    func resumeConnections() {
        isActive = true
        reconcileConnections()
    }

    func showDetails(for printerID: NSManagedObjectID) {
        guard connections[printerID] != nil else { return }
        detailedPrinterID = printerID
        reconcileConnections()
    }

    func hideDetails(for printerID: NSManagedObjectID) {
        guard detailedPrinterID == printerID else { return }
        detailedPrinterID = nil
        reconcileConnections()
    }

    // MARK: - CloudKitPrinterDelegate

    func printersUpdated() {
        DispatchQueue.main.async {
            self.updatePrinters(self.printerManager.getPrinters())
        }
    }

    func iCloudStatusChanged(connected: Bool) {
        DispatchQueue.main.async {
            self.iCloudConnected = connected
            self.reconcileConnections()
        }
    }

    // MARK: - Camera settings

    func cameraChanged(printerID: NSManagedObjectID) {
        DispatchQueue.main.async {
            guard self.activeCameras.contains(printerID),
                  let camera = self.connections[printerID]?.cameraService else { return }

            // The settings writer uses a sibling context. Load its saved camera settings.
            let context = self.printerManager.newPrivateContext()
            let configuration = context.performAndWait {
                ((try? context.existingObject(with: printerID)) as? Printer).map(CameraService.Configuration.init)
            }
            if let configuration {
                camera.connect(configuration: configuration)
            }
        }
    }

    func printerConnectionFailed(_ printerID: NSManagedObjectID) {
        if connected[printerID] != nil {
            failedConnections.insert(printerID)
        }
    }

    private func updatePrinters(_ newPrinters: [Printer]) {
        let newIDs = Set(newPrinters.map(\.objectID))
        for printerID in Array(connections.keys) where !newIDs.contains(printerID) {
            disconnect(printerID)
            connections.removeValue(forKey: printerID)
        }
        for printer in newPrinters where connections[printer.objectID] == nil {
            connections[printer.objectID] = (ViewService(tvPrinterManager: self), CameraService())
        }
        if let detailedPrinterID, !newIDs.contains(detailedPrinterID) {
            self.detailedPrinterID = nil
        }

        // Preserve the selected page while it exists, clamping before publishing a shorter list.
        let newPageCount = (newPrinters.count + printersPerPage - 1) / printersPerPage
        if page > max(1, newPageCount) {
            page = max(1, newPageCount)
        }
        printers = newPrinters
        reconcileConnections()
    }

    private func reconcileConnections() {
        let canConnect = isActive && iCloudConnected
        var desiredPrinters = canConnect ? visiblePrinters : []
        if canConnect, let detailedPrinterID,
           !desiredPrinters.contains(where: { $0.objectID == detailedPrinterID }),
           let printer = printers.first(where: { $0.objectID == detailedPrinterID }) {
            desiredPrinters.append(printer)
        }

        let desiredIDs = Set(desiredPrinters.map(\.objectID))
        for printerID in Array(connected.keys) where !desiredIDs.contains(printerID) {
            disconnect(printerID)
        }
        for printer in desiredPrinters {
            let id = printer.objectID
            guard let connection = connections[id] else { continue }

            let configuration = ConnectionConfiguration(printer: printer)
            if connected[id] != configuration || failedConnections.contains(id) {
                // Force a new WebSocket as well as HTTP when credentials or other inputs change.
                disconnect(id)
                connection.websocket.connectToServer(printer: printer)
                connected[id] = configuration
            }
            if detailedPrinterID == nil || detailedPrinterID == id {
                if activeCameras.insert(id).inserted {
                    connection.cameraService.connect(configuration: CameraService.Configuration(printer: printer))
                }
            } else {
                stopCamera(id)
            }
        }
    }

    private func disconnect(_ printerID: NSManagedObjectID) {
        failedConnections.remove(printerID)
        if connected.removeValue(forKey: printerID) != nil {
            connections[printerID]?.websocket.disconnectFromServer()
        }
        stopCamera(printerID)
    }

    private func stopCamera(_ printerID: NSManagedObjectID) {
        if activeCameras.remove(printerID) != nil {
            connections[printerID]?.cameraService.disconnectFromServer()
        }
    }
}
