import SwiftUI
import AVKit

struct BriefView: View {
    let printer: Printer
    
    @EnvironmentObject private var service: ViewService
    @EnvironmentObject private var cameraService: CameraService
    
    var body: some View {
        VStack() {
            HStack {
                VStack() {
                    NavigationLink(destination: DetailedView(name: printer.name)
                        .environmentObject(service)
                        .environmentObject(cameraService)
                    ) {
                        VStack() {
                            HStack {
                                Text("Printer")
                                    .font(.subheadline)
                                Spacer()
                                value(text: printer.name)
                                    .bold()
                            }
                            HStack {
                                Text("State")
                                    .font(.subheadline)
                                Spacer()
                                value(text: service.printerStatus)
                            }
                            HStack {
                                Text("Progress")
                                    .font(.subheadline)
                                Spacer()
                                value(text: service.progress)
                            }
                            HStack {
                                Text("Print Time Left")
                                    .font(.subheadline)
                                Spacer()
                                value(text: service.printTimeLeft)
                            }
                            if service.layer != nil {
                                HStack() {
                                    Text("Layer")
                                        .font(.subheadline)
                                    Spacer()
                                    value(text: service.layer!)
                                }
                            }
                        }.frame(minWidth: 400)
                    }.buttonStyle(PlainButtonStyle())
                }
                VStack {
                    if cameraService.image != nil {
                        Image(uiImage: cameraService.image!)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 320)
                    } else if cameraService.player != nil {
                        VideoPlayer(player: cameraService.player!)
                            .disabled(true)  // Disable so cannot be selected
                            .rotation3DEffect(cameraService.avPlayerEffect3D1!.angle, axis: cameraService.avPlayerEffect3D1!.axis)
                            .rotation3DEffect(cameraService.avPlayerEffect3D2!.angle, axis: cameraService.avPlayerEffect3D2!.axis)
                            .rotationEffect(cameraService.avPlayerEffect!)
                            .frame(height: 320)
                    } else {
                        Image("Image")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 320)
                        if cameraService.errorMessage != nil {
                            Text(cameraService.errorMessage!)
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func value(text: String) -> Text {
        return Text(text)
            .font(.subheadline)
            .foregroundColor(Color(red: 47/255, green: 79/255, blue: 79/256))
    }
}

struct BriefView_Previews: PreviewProvider {
    static var previews: some View {
        BriefView(printer: Printer())
    }
}
