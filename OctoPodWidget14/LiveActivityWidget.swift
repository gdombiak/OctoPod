import SwiftUI
import WidgetKit
import ActivityKit

//@main
@available(iOSApplicationExtension 16.1, *)
struct LiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrintJobAttributes.self) { context in
            // Create the presentation that appears on the Lock Screen and as a
            // banner on the Home Screen of devices that don't support the
            // Dynamic Island.
            LockScreenLiveActivityView(context: context)
                .widgetURL(URL(string: "octopod://\(context.attributes.urlSafePrinter)")!)
        } dynamicIsland: { context in
            // Create the presentations that appear in the Dynamic Island.
            DynamicIsland {
                // Create the expanded presentation.
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("\(context.state.completion)%")
                            .font(.body)
                    } icon: {
                        Image("Progress")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("\(UIUtils.secondsToETA(seconds: context.state.printTimeLeft))")
                            .font(.body)
                    } icon: {
                        Image("ETA")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Image("OctoPod")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Spacer()
                    Text("\(context.attributes.printerName)")
                        .font(.headline)
                    Text("\(context.state.printerStatus)")
                        .font(.subheadline)
                    Spacer()
                }
            } compactLeading: {
                Image("Progress")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Text("\(context.state.completion)%")
                    .font(.body)
            } minimal: {
                Text("\(context.state.completion)%")
                    .font(.body)
                    .minimumScaleFactor(0.7)
            }.widgetURL(URL(string: "octopod://\(context.attributes.urlSafePrinter)")!)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PrintJobAttributes>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack {
                Image("OctoPod")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .padding(.leading)
                    .padding(.top)
                Spacer()
            }
            VStack {
                Spacer()
                Text("\(context.attributes.printerName)")
                    .font(.headline)
                if context.state.completion == 100 {
                    // Display printer name
                    Text("\(context.attributes.printFileName)")
                        .font(.subheadline)
                } else {
                    // Display printer statu since we are still printing
                    Text("\(context.state.printerStatus)")
                        .font(.subheadline)
                }
                Spacer()
                HStack {
                    Spacer()
                    Label {
                        Text("\(context.state.completion)%")
                            .font(.body)
                    } icon: {
                        Image("Progress")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    }
                    .font(.title2)
                    Spacer()
                    if context.state.completion < 100 {
                        Label {
                            Text("\(UIUtils.secondsToETA(seconds: context.state.printTimeLeft))")
                                .font(.body)
                        } icon: {
                            Image("ETA")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                        .font(.title2)
                        Spacer()
                    }
                }
                Spacer()
                if !context.attributes.pluginInstalled {
                    HStack {
                        Image("Warning")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("Install OctoPod plugin for updates")
                            .font(.caption2)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                }
            }
        }
        .activityBackgroundTint(colorScheme == .dark ? Color(.sRGB, red: 115 / 255, green: 115 / 255, blue: 115 / 255, opacity: 0.75) : Color(.sRGB, red: 204 / 255, green: 204 / 255, blue: 204 / 255, opacity: 0.75))
    }
}

@available(iOSApplicationExtension 16.2, *)
struct LockScreenLiveActivityView_Previews: PreviewProvider {
    static var initialContentState = PrintJobAttributes.ContentState(printerStatus: "Printing", completion: 45, printTimeLeft: 15000)
    static var activityAttributes = PrintJobAttributes(urlSafePrinter: "targetURLSafePrinter", printerName: "MBP 16", printFileName: "File Name Being Printed.gcode", pluginInstalled: true)
    static var activityContent = ActivityContent(state: initialContentState, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())!)
    
    static var previews: some View {
        Group {
            activityAttributes.previewContext(initialContentState, viewKind: .content)

            activityAttributes.previewContext(initialContentState, viewKind: .dynamicIsland(.expanded))

            activityAttributes.previewContext(initialContentState, viewKind: .dynamicIsland(.compact))

            activityAttributes.previewContext(initialContentState, viewKind: .dynamicIsland(.minimal))
        }
    }
}
