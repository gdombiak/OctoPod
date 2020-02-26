import SwiftUI

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
                                Text(printer.name)
                                    .font(.subheadline)
                                    .bold()
                            }
                            HStack {
                                Text("State")
                                    .font(.subheadline)
                                Spacer()
                                Text(service.printerStatus)
                                    .font(.subheadline)
                            }
                            HStack {
                                Text("Progress")
                                    .font(.subheadline)
                                Spacer()
                                Text(service.progress)
                                    .font(.subheadline)
                            }
                            HStack {
                                Text("Print Time Left")
                                    .font(.subheadline)
                                Spacer()
                                Text(service.printTimeLeft)
                                    .font(.subheadline)
                            }
                            if service.layer != nil {
                                HStack() {
                                    Text("Layer")
                                    Spacer()
                                    Text(service.layer!)
                                }
                            }
                        }.frame(minWidth: 500)
                    }.buttonStyle(PlainButtonStyle())
                }
                if cameraService.image != nil {
                    Image(uiImage: cameraService.image!)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                } else {
                    Image("Image")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                    if cameraService.errorMessage != nil {
                        Text(cameraService.errorMessage!)
                    }
                }
            }
        }
    }
}

struct BriefView_Previews: PreviewProvider {
    static var previews: some View {
        BriefView(printer: Printer())
    }
}
