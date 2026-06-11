import SwiftUI

struct DayStatusBar: View {
    let windows: [RecommendationWindow]
    let start: Date
    let end: Date

    private let barHeight: CGFloat = 12

    private var model: DayStatusBarModel {
        DayStatusBarModel(start: start, end: end)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))

                    ForEach(windows) { window in
                        Rectangle()
                            .fill(window.status.color)
                            .frame(
                                width: model.segmentWidth(for: window, in: proxy.size.width),
                                height: barHeight
                            )
                            .offset(x: model.segmentOffset(for: window, in: proxy.size.width))
                    }

                    ForEach(segmentDividers(in: proxy.size.width)) { mark in
                        Rectangle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 2, height: barHeight)
                            .offset(x: mark.tickPosition - 1)
                    }
                }
                .clipShape(.capsule)
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
            }
            .frame(height: barHeight)

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ForEach(axisMarks(in: proxy.size.width)) { mark in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.28))
                            .frame(width: 1, height: 9)
                            .position(x: mark.tickPosition, y: 4)

                        Text(mark.label)
                            .frame(width: 56, alignment: mark.alignment)
                            .position(
                                x: mark.labelPosition,
                                y: 24
                            )
                    }
                }
            }
            .frame(height: 34)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var accessibilitySummary: String {
        windows.map {
            "\($0.status.shortTitle) from \($0.start.formatted(date: .omitted, time: .shortened)) to \($0.end.formatted(date: .omitted, time: .shortened))"
        }
        .joined(separator: ". ")
    }

    private var dividerDates: [Date] {
        DayStatusBarAxis.markerDates(start: start, end: end)
    }

    private func axisMarks(in width: CGFloat) -> [AxisMark] {
        return dividerDates
            .map {
                let fraction = model.fraction(for: $0)
                return positionedAxisMark(
                    date: $0,
                    label: timeMarkLabel(for: $0),
                    alignment: axisAlignment(for: fraction),
                    width: width
                )
            }
    }

    private func segmentDividers(in width: CGFloat) -> [AxisMark] {
        windows
            .dropFirst()
            .map {
                AxisMark(
                    date: $0.start,
                    label: "",
                    alignment: .center,
                    tickPosition: width * model.fraction(for: $0.start),
                    labelPosition: width * model.fraction(for: $0.start)
                )
            }
            .filter { 0 < $0.tickPosition && $0.tickPosition < width }
    }

    private func positionedAxisMark(
        date: Date,
        label: String,
        alignment: Alignment,
        width: CGFloat
    ) -> AxisMark {
        AxisMark(
            date: date,
            label: label,
            alignment: alignment,
            tickPosition: width * model.fraction(for: date),
            labelPosition: min(max(width * model.fraction(for: date), 28), width - 28)
        )
    }

    private func timeMarkLabel(for date: Date) -> String {
        date.formatted(.dateTime.hour())
    }

    private func axisAlignment(for fraction: Double) -> Alignment {
        if fraction == 0 { return .leading }
        if fraction == 1 { return .trailing }
        return .center
    }

    private struct AxisMark: Identifiable {
        let date: Date
        let label: String
        let alignment: Alignment
        let tickPosition: CGFloat
        let labelPosition: CGFloat

        var id: Date { date }
    }
}
