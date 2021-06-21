import Foundation

class PrintJobDataService: ObservableObject {
    @Published var printerName: String = ""
    @Published var printerStatus: String = "--"
    @Published var progress: Double?
    @Published var printEstimatedCompletion: String = "--"
    
    @Published var errorUpdating: String?
    
    private let restClient: OctoPrintRESTClient!
    
    init(name: String, hostname: String, apiKey: String, username: String?, password: String?, preemptive: Bool) {
        printerName = name
        restClient = OctoPrintRESTClient()
        restClient.connectToServer(serverURL: hostname, apiKey: apiKey, username: username, password: password, preemptive: preemptive)
    }
    
    func updateData(completion: @escaping () -> ()) {
        restClient!.currentJobInfo { (result: NSObject?, error: Error?, response :HTTPURLResponse) in
            // Update properties from event. This will fire event that will refresh UI
            DispatchQueue.main.async {
                if let error = error {
                    self.errorUpdating = error.localizedDescription
                } else if let result = result as? Dictionary<String, Any> {
                    self.errorUpdating = nil
                    
                    if let state = result["state"] as? String {
                        self.printerStatus = state
                        if state == "Printing from SD" {
                            self.printerStatus = "Printing"
                        } else if state.starts(with: "Offline (Error:") {
                            self.printerStatus = "Offline"
                        }
                    }
                    if let progress = result["progress"] as? Dictionary<String, Any> {
                        if let completion = progress["completion"] as? Double {
                            self.progress = completion / 100
                        }
                        if let seconds = progress["printTimeLeft"] as? Int {
                            self.printEstimatedCompletion = UIUtils.secondsToETA(seconds: seconds)
                        }
                    }
                }
                completion()
            }
        }
    }
    
    func isPrinting() -> Bool {
        // Assume that printer is printing if not operational, not offline and not unknown
        return printerStatus != "Operational" && printerStatus != "Offline" && printerStatus != "--"
    }

}
