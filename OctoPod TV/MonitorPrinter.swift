import SwiftUI

struct MonitorPrinter : View {
    @EnvironmentObject var service: ViewService
    @EnvironmentObject var cameraService: CameraService

    var body: some View {
        HStack {
            VStack() {
                HStack() {
                    Text("State")
                    Spacer()
                    Text(service.printerStatus)
                }
                HStack() {
                    Text("File")
                    Spacer()
                    Text(service.printingFile)
                }
                HStack() {
                    Text("Progress")
                    Spacer()
                    Text(service.progress)
                }
                HStack() {
                    Text("Print Time")
                    Spacer()
                    Text(service.printTime)
                }
                HStack() {
                    Text("Print Time Left")
                    Spacer()
                    Text(service.printTimeLeft)
                }
                HStack() {
                    Text("Print Completion")
                    Spacer()
                    Text(service.printEstimatedCompletion)
                }
                HStack() {
                    Text("Extruder Temp")
                    Spacer()
                    Text("\(service.tool0Actual) / \(service.tool0Target)")
                }
                HStack() {
                    Text("Bed Temp")
                    Spacer()
                    Text("\(service.bedActual) / \(service.bedTarget)")
                }
                if service.currentHeight != nil {
                    HStack() {
                        Text("Current Height")
                        Spacer()
                        Text(service.currentHeight!)
                    }
                }
                if service.layer != nil {
                    HStack() {
                        Text("Layer")
                        Spacer()
                        Text(service.layer!)
                    }
                }
            }
            .frame(width: 500.0)
            VStack {
                if cameraService.image != nil {
                    Image(uiImage: cameraService.image!)
                } else {
                    Image("Image", bundle: nil)
                    if cameraService.errorMessage != nil {
                        Text(cameraService.errorMessage!)
                    }
                }
//                if cameraService.hasPrevious || cameraService.hasNext {
//                    HStack {
//                        if cameraService.hasPrevious {
//                            Button(action: {
//                                self.cameraService.renderPrevious()
//                            }) {
//                                Image("PreviousCamera", bundle: nil)
//                            }.buttonStyle(PlainButtonStyle())
//                        }
//                        if cameraService.hasNext {
//                            Button(action: {
//                                self.cameraService.renderNext()
//                            }) {
//                                Image("NextCamera", bundle: nil)
//                            }.buttonStyle(PlainButtonStyle())
//                        }
//                    }
//                }
            }
        }
    }
}

struct MonitorPrinter_Previews: PreviewProvider {
    static var previews: some View {
        MonitorPrinter()
            .environmentObject(ViewService())
            .environmentObject(CameraService())
    }
}
