import SwiftUI

struct ForecastStatusBandView: View {
    let segments: [ForecastStatusSegment]
    let xDomain: ClosedRange<Date>

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ForecastAxisMetrics.plotLeadingInset)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))

                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.status.color)
                            .frame(
                                width: segmentWidth(segment, totalWidth: proxy.size.width),
                                height: proxy.size.height
                            )
                            .offset(
                                x: position(for: segment.start, totalWidth: proxy.size.width)
                            )
                    }

                    ForEach(
                        ForecastDayBoundary.boundaries(
                            for: xDomain,
                            width: proxy.size.width
                        )
                    ) { boundary in
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: max(proxy.size.height - 5, 0))
                            .offset(x: boundary.position)
                    }
                }
                .clipShape(.capsule)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open and closed recommendation status over the forecast period")
    }

    private func segmentWidth(
        _ segment: ForecastStatusSegment,
        totalWidth: CGFloat
    ) -> CGFloat {
        max(
            position(for: segment.end, totalWidth: totalWidth)
                - position(for: segment.start, totalWidth: totalWidth),
            0
        )
    }

    private func position(for date: Date, totalWidth: CGFloat) -> CGFloat {
        let duration = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
        guard duration > 0 else { return 0 }

        let fraction = date.timeIntervalSince(xDomain.lowerBound) / duration
        return totalWidth * min(max(fraction, 0), 1)
    }
}
