import SwiftUI
import AVKit

struct DetailedView : View {
    let name: String
    
    @ObservedObject private var tvPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).tvPrinterManager }()
    
    @EnvironmentObject var viewService: ViewService
    @EnvironmentObject var cameraService: CameraService
    @Namespace private var namespace
    
    @State private var cameraMaximized = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                if !cameraMaximized {
                    NormalCameraView(geometry: geometry, service: viewService, cameraService: cameraService, namespace: namespace, cameraMaximized: $cameraMaximized)
                } else {
                    MaximizedCameraView(geometry: geometry, cameraService: cameraService, namespace: namespace, cameraMaximized: $cameraMaximized)
                }
            }.navigationTitle(self.name)
        }.onDisappear {
            // Ask TVPrinterManager to resume refreshing cameras that appear in main view
            self.tvPrinterManager.resumeOtherCameraConnections(skip: self.name)
            // Tell CameraService that it's not longer being used by detailed view
            cameraService.changedView(detailed: false)
        }.onAppear() {
            // Ask TVPrinterManager to stop refreshing other cameras that appear in main view
            // This will save CPU usage, websockets do not consume much
            self.tvPrinterManager.suspendOtherCameraConnections(skip: self.name)
            // Tell CameraService that it's being used by detailed view
            cameraService.changedView(detailed: true)
        }.focusScope(self.namespace)
    }
}

struct DetailedView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedView(name: "MK3")
            .environmentObject(ViewService())
            .environmentObject(CameraService())
    }
}

struct NormalCameraView: View {
    let geometry: GeometryProxy
    let service: ViewService
    let cameraService: CameraService
    let namespace: Namespace.ID
    @Binding var cameraMaximized: Bool
    
    var body: some View {
        HStack {
            VStack {
                VStack {
                    HStack() {
                        Text("State")
                        Spacer()
                        self.value(text: self.service.printerStatus)
                    }
                    HStack() {
                        Text("File")
                        Spacer()
                        self.value(text: self.service.printingFile)
                    }
                }
                Divider()
                VStack {
                    HStack() {
                        Text("Progress")
                        Spacer()
                        self.value(text: self.service.progress)
                    }
                    HStack() {
                        Text("Print Time")
                        Spacer()
                        self.value(text: self.service.printTime)
                    }
                    HStack() {
                        Text("Print Time Left")
                        Spacer()
                        self.value(text: self.service.printTimeLeft)
                    }
                    HStack() {
                        Text("Print Completion")
                        Spacer()
                        self.value(text: self.service.printEstimatedCompletion)
                    }
                }
                Divider()
                VStack {
                    HStack() {
                        Text("Extruder")
                        Spacer()
                        self.value(text: "\(self.service.tool0Actual) / \(self.service.tool0Target)")
                    }
                    HStack() {
                        Text("Bed")
                        Spacer()
                        self.value(text: "\(self.service.bedActual) / \(self.service.bedTarget)")
                    }
                    if self.service.currentHeight != nil {
                        HStack() {
                            Text("Current Height")
                            Spacer()
                            self.value(text: self.service.currentHeight!)
                        }
                    }
                    if self.service.layer != nil {
                        HStack() {
                            Text("Layer")
                            Spacer()
                            self.value(text: self.service.layer!)
                        }
                    }
                }
            }.frame(minWidth: 510)
            VStack {
                if self.cameraService.image != nil {
                    Image(uiImage: self.cameraService.image!)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: geometry.size.height * 0.85)
                } else if cameraService.detailedPlayer != nil {
                    Spacer()
                    VideoPlayer(player: cameraService.detailedPlayer!)
                        .prefersDefaultFocus(false, in: self.namespace)
                        .disabled(true)  // Disable so cannot be selected
                        .rotation3DEffect(cameraService.avPlayerEffect3D1!.angle, axis: cameraService.avPlayerEffect3D1!.axis)
                        .rotation3DEffect(cameraService.avPlayerEffect3D2!.angle, axis: cameraService.avPlayerEffect3D2!.axis)
                        .rotationEffect(cameraService.avPlayerEffect!)
                        .frame(maxHeight: geometry.size.height * 0.80)
                } else {
                    Image("Image")
                    if self.cameraService.errorMessage != nil {
                        Text(self.cameraService.errorMessage!)
                    }
                }
            }
        }
        HStack {
            if self.service.pausing == true || self.service.cancelling == true {
                // We are pausing or cancelling so show Print (disabled), Pause (disabled) and Cancel (disabled)
                self.print(enabled: false)
                self.pause(enabled: false)
                self.cancel(enabled: false)
            } else if self.service.printing == true{
                // We are printing so show Print (disabled), Pause and Cancel
                self.print(enabled: false)
                self.pause(enabled: true)
                self.cancel(enabled: true)
            } else if self.service.paused == true {
                // We are paused so offer Restart, Resume and Cancel
                self.restart()
                self.resume()
                self.cancel(enabled: true)
            } else {
                // We are not printing so show Print (disabled?), Pause (disabled) and Cancel (disabled)
                self.print(enabled: self.service.printingFile != "--")
                self.pause(enabled: false)
                self.cancel(enabled: false)
            }
            Spacer()
            if self.cameraService.hasPrevious || self.cameraService.hasNext {
                if self.cameraService.hasPrevious {
                    Button(action: {
                        self.cameraService.renderPrevious()
                    }) {
                        HStack {
                            Image("Back")
                            Text("Camera")
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                        }
                    }
                }
                if self.cameraService.hasNext {
                    Button(action: {
                        self.cameraService.renderNext()
                    }) {
                        HStack {
                            Text("Camera")
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                            Image("Next")
                        }
                    }
                }
            }
            Button(action: {
                cameraMaximized = true
            }) {
                HStack {
                    Image("Expand")
                    Text("Expand")
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                }
            }
            .prefersDefaultFocus(true, in: self.namespace)
        }
    }

    fileprivate func value(text: String) -> Text {
        return Text(text)
            .foregroundColor(Color(red: 47/255, green: 79/255, blue: 79/256))
    }
    
    fileprivate func print(enabled: Bool) -> some View {
        return Button(action: {
            if let lastFile = self.service.lastKnownPrintFile, let origin = lastFile.origin, let path = lastFile.path {
                self.service.printFile(origin: origin, path: path) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    NSLog("Print requested successfully \(requested)")
                }
            }
        }) {
            HStack {
                Image("Print")
                Text("Print")
                    .minimumScaleFactor(0.70)
                    .lineLimit(1)
            }
        }.disabled(!enabled)
    }
    
    fileprivate func pause(enabled: Bool) -> some View {
        let confirmText = NSLocalizedString("Do you want to pause job?", comment: "")
        return PrintJobButton(confirmationText: confirmText, type: PrintJobButton.JobType.Pause, service: service)
            .disabled(!enabled)
    }
    
    fileprivate func cancel(enabled: Bool) -> some View {
        let confirmText = NSLocalizedString("Do you want to cancel job?", comment: "")
        return PrintJobButton(confirmationText: confirmText, type: PrintJobButton.JobType.Cancel, service: service)
            .disabled(!enabled)
    }
    
    fileprivate func restart() -> some View {
        let confirmText = NSLocalizedString("Do you want to restart print job from the beginning?", comment: "")
        return PrintJobButton(confirmationText: confirmText, type: PrintJobButton.JobType.Restart, service: service)
    }
    
    fileprivate func resume() -> some View {
        return Button(action: {
            self.service.resumeCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                NSLog("Resume requested successfully \(requested)")
            }
        }) {
            HStack {
                Image("Print")
                Text("Resume")
            }
        }
    }
}

struct MaximizedCameraView: View {
    let geometry: GeometryProxy
    let cameraService: CameraService
    let namespace: Namespace.ID
    @Binding var cameraMaximized: Bool
    
    var body: some View {
        ZStack {
            VStack {
                if self.cameraService.image != nil {
                    Image(uiImage: self.cameraService.image!)
                        .resizable()
                        .scaledToFit()
                } else if cameraService.detailedPlayer != nil {
                    VideoPlayer(player: cameraService.detailedPlayer!)
                        .prefersDefaultFocus(false, in: self.namespace)
                        .disabled(true)  // Disable so cannot be selected
                        .rotation3DEffect(cameraService.avPlayerEffect3D1!.angle, axis: cameraService.avPlayerEffect3D1!.axis)
                        .rotation3DEffect(cameraService.avPlayerEffect3D2!.angle, axis: cameraService.avPlayerEffect3D2!.axis)
                        .rotationEffect(cameraService.avPlayerEffect!)
                } else {
                    Image("Image")
                    if self.cameraService.errorMessage != nil {
                        Text(self.cameraService.errorMessage!)
                    }
                }
            }
            VStack(alignment: .trailing) {
                HStack(alignment: .top) {
                    Spacer()
                    Button(action: {
                        cameraMaximized = false
                    }) {
                        HStack {
                            Image("Restore")
                            Text("Restore")
                        }
                    }
                    .prefersDefaultFocus(true, in: self.namespace)
                }
                Spacer()
            }
        }
    }
}

struct PrintJobButton: View {
    enum JobType {
        case Cancel
        case Pause
        case Restart
    }
    let confirmationText: String
    let type: JobType
    let service: ViewService
    
    @State private var showingAlert = false
    
    var body: some View {
        Button(action: {
            self.showingAlert = true
        }) {
            if self.type == JobType.Cancel {
                HStack {
                    Image("Cancel")
                    Text("Cancel")
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                }
            } else if self.type == JobType.Pause {
                HStack {
                    Image("Pause")
                    Text("Pause")
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                }
            } else {
                HStack {
                    Image("Print")
                    Text("Restart")
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                }
            }
        }
        .alert(isPresented:$showingAlert) {
            Alert(title: Text("Confirm"), message: Text(confirmationText), primaryButton: .destructive(Text("Yes")) {
                switch self.type {
                case JobType.Cancel:
                    self.service.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        NSLog("Cancel requested successfully \(requested)")
                    }
                case JobType.Pause:
                    self.service.pauseCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        NSLog("Pause requested successfully \(requested)")
                    }
                case JobType.Restart:
                    self.service.restartCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        NSLog("Restart requested successfully \(requested)")
                    }
                }
            }, secondaryButton: .cancel())
        }
    }
}
