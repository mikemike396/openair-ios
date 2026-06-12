import SwiftUI

struct ForecastStatusBandView: View {
    let segments: [ForecastStatusSegment]
    let xDomain: ClosedRange<Date>
    @State private var availableSize: CGSize = .zero

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ForecastAxisMetrics.plotLeadingInset)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))

                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.status.color)
                        .frame(
                            width: segmentWidth(segment, totalWidth: availableSize.width),
                            height: availableSize.height
                        )
                        .offset(
                            x: position(for: segment.start, totalWidth: availableSize.width)
                        )
                }

                ForEach(
                    ForecastDayBoundary.boundaries(
                        for: xDomain,
                        width: availableSize.width
                    )
                ) { boundary in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: max(availableSize.height - 5, 0))
                        .offset(x: boundary.position)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.capsule)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                availableSize = newSize
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
