import SwiftUI

struct DetailedView : View {
    let name: String
    
    @EnvironmentObject var service: ViewService
    @EnvironmentObject var cameraService: CameraService
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                HStack {
                    VStack() {
                        HStack() {
                            Text("State")
                            Spacer()
                            Text(self.service.printerStatus)
                        }
                        HStack() {
                            Text("File")
                            Spacer()
                            Text(self.service.printingFile)
                        }
                        HStack() {
                            Text("Progress")
                            Spacer()
                            Text(self.service.progress)
                        }
                        HStack() {
                            Text("Print Time")
                            Spacer()
                            Text(self.service.printTime)
                        }
                        HStack() {
                            Text("Print Time Left")
                            Spacer()
                            Text(self.service.printTimeLeft)
                        }
                        HStack() {
                            Text("Print Completion")
                            Spacer()
                            Text(self.service.printEstimatedCompletion)
                        }
                        HStack() {
                            Text("Extruder Temp")
                            Spacer()
                            Text("\(self.service.tool0Actual) / \(self.service.tool0Target)")
                        }
                        HStack() {
                            Text("Bed Temp")
                            Spacer()
                            Text("\(self.service.bedActual) / \(self.service.bedTarget)")
                        }
                        if self.service.currentHeight != nil {
                            HStack() {
                                Text("Current Height")
                                Spacer()
                                Text(self.service.currentHeight!)
                            }
                        }
                        if self.service.layer != nil {
                            HStack() {
                                Text("Layer")
                                Spacer()
                                Text(self.service.layer!)
                            }
                        }
                    }
                    VStack {
                        if self.cameraService.image != nil {
                            Image(uiImage: self.cameraService.image!)
                                .resizable()
                                .scaledToFill()
                                .frame(maxHeight: geometry.size.height * 0.85)
                        } else {
                            Image("Image", bundle: nil)
                            if self.cameraService.errorMessage != nil {
                                Text(self.cameraService.errorMessage!)
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
                }.navigationBarTitle(self.name)
            }
        }
    }
}

struct DetailedView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedView(name: "MK3")
            .environmentObject(ViewService())
            .environmentObject(CameraService())
    }
}
