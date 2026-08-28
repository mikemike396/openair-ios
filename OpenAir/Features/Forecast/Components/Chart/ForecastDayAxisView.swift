import SwiftUI

struct ForecastDayAxisView: View {
    let xDomain: ClosedRange<Date>

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ForecastAxisMetrics.plotLeadingInset)

            GeometryReader { proxy in
                ZStack {
                    ForEach(labels(for: proxy.size.width)) { label in
                        Text(label.text)
                            .frame(width: 44)
                            .position(x: label.position, y: 10)
                    }
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private func labels(for width: CGFloat) -> [ForecastDayAxisLabel] {
        ForecastDayAxisLabel.labels(for: xDomain, width: width)
    }
}
