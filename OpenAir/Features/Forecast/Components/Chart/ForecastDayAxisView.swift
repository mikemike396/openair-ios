import SwiftUI

struct ForecastDayAxisView: View {
    let xDomain: ClosedRange<Date>
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ForecastAxisMetrics.plotLeadingInset)

            ZStack {
                ForEach(labels) { label in
                    Text(label.text)
                        .frame(width: 44)
                        .position(x: label.position, y: 11)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                availableWidth = newWidth
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private var labels: [ForecastDayAxisLabel] {
        ForecastDayAxisLabel.labels(for: xDomain, width: availableWidth)
    }
}
