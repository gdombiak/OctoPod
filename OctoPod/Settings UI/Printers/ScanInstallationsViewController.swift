import UIKit

/// Discover OctoPrint instances via ZeroConf. See [Discovery Plugin](http://docs.octoprint.org/en/master/bundledplugins/discovery.html)
class ScanInstallationsViewController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

    var browser: NetServiceBrowser!
    var discovered: Array<NetService> = []
    var resolved: Array<NetService> = []
    
    var selectedOctoPrint: (name: String, hostname: String)?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup the browser
        browser = NetServiceBrowser()
        browser.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Start the discovery
        selectedOctoPrint = nil
        discovered.removeAll()
        resolved.removeAll()
        browser.stop()
        browser.searchForServices(ofType: "_octoprint._tcp", inDomain: "")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop search (not sure that this is needed but just in case)
        browser.stop()
        // Remove this VC as a delegate
        for service in resolved {
            service.delegate = nil
        }
        // Release memory and let things go
        discovered.removeAll()
        resolved.removeAll()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resolved.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "discovered_cell", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = resolved[indexPath.row].name
        cell.detailTextLabel?.text = resolved[indexPath.row].hostName

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Remember selected OctoPrint instance
        let selection = resolved[indexPath.row]
        if let hostURL = octoPrintURL(service: selection) {
            selectedOctoPrint = (name: selection.name, hostname: hostURL)
        }
        // Close window
        performSegue(withIdentifier: "backFromDiscoverOctoPrintInstances", sender: self)

    }
    
    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        discovered.append(service)
        // Resolve the service in 5 seconds
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    // MARK: - NetServiceDelegate
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let _ = resolved.first(where: { (service: NetService) -> Bool in
            return self.octoPrintURL(service: service) == self.octoPrintURL(service: sender)
        }) {
            // Do nothing since we already have this service listed. For some
            // reason duplicates are received
            return
        }
        // Track detected OctoPrint instance
        resolved.append(sender)

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Utility functions
    
    /// Returns the full URL for the OctoPrint instance based on the discovered ZeroConf information
    func octoPrintURL(service: NetService) -> String? {
        if let serviceIp = resolveIPv4(addresses: service.addresses!) {
            let hostURL: String!
            var path = ""
            
            if let data = service.txtRecordData() {
                let dict = NetService.dictionary(fromTXTRecord: data)
                if let pathData = dict["path"] {
                    path = String(data: pathData, encoding: String.Encoding.utf8) ?? ""
                }
                // Remove trailing /
                if path.last == "/" {
                    path = String(path.dropLast())
                }
            }
            
            if service.port == 443 {
                hostURL = "https://\(serviceIp)\(path)"
            } else if service.port == 80 {
                hostURL = "http://\(serviceIp)\(path)"
            } else {
                hostURL = "http://\(serviceIp):\(service.port)\(path)"
            }
            
            return hostURL
        }
        return nil
    }
    
    // MARK: - Private functions
    
    /// Find an IPv4 address from the service address data
    fileprivate func resolveIPv4(addresses: [Data]) -> String? {
        var result: String?
        
        for addr in addresses {
            let data = addr as NSData
            var storage = sockaddr_storage()
            data.getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
            
            if Int32(storage.ss_family) == AF_INET {
                let addr4 = withUnsafePointer(to: &storage) {
                    $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        $0.pointee
                    }
                }
                
                if let ip = String(cString: inet_ntoa(addr4.sin_addr), encoding: .ascii) {
                    result = ip
                    break
                }
            }
        }
        
        return result
    }
}
