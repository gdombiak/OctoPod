import SwiftUI
import WidgetKit

@available(iOS 14.0, *)
struct ProgressBarView: View {
    @Binding var progress: Double
    @Binding var color: Color
    
    init(progress: Binding<Double>, color: Binding<Color> = .constant(.red)) {
        _progress = progress
        _color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10.0)
                .opacity(0.3)
                .foregroundColor(color)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear)
            Text(String(format: "%.0f%%", min(self.progress, 1.0)*100.0))
                .font(.callout)
                .bold()
        }
    }
}

struct ProgressBarView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressBarView(progress: .constant(0.28), color: .constant(.red))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
