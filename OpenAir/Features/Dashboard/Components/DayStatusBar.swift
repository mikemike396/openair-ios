import SwiftUI

struct DayStatusBar: View {
    let windows: [RecommendationWindow]
    let start: Date
    let end: Date

    private let barHeight: CGFloat = 12
    private let edgeOverscan: CGFloat = 1

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
                                width: segmentWidth(for: window, in: proxy.size.width),
                                height: barHeight
                            )
                            .offset(x: segmentOffset(for: window, in: proxy.size.width))
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

    private func startFraction(for window: RecommendationWindow) -> Double {
        fraction(for: window.start)
    }

    private func widthFraction(for window: RecommendationWindow) -> Double {
        max(0, fraction(for: window.end) - fraction(for: window.start))
    }

    private func segmentOffset(for window: RecommendationWindow, in width: CGFloat) -> CGFloat {
        let offset = width * startFraction(for: window)
        return startFraction(for: window) == 0 ? -edgeOverscan : offset
    }

    private func segmentWidth(for window: RecommendationWindow, in width: CGFloat) -> CGFloat {
        var segmentWidth = width * widthFraction(for: window)
        if startFraction(for: window) == 0 {
            segmentWidth += edgeOverscan
        }
        if fraction(for: window.end) == 1 {
            segmentWidth += edgeOverscan
        }
        return segmentWidth
    }

    private func fraction(for date: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(start) / duration, 0), 1)
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
                let fraction = fraction(for: $0)
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
                    tickPosition: width * fraction(for: $0.start),
                    labelPosition: width * fraction(for: $0.start)
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
            tickPosition: width * fraction(for: date),
            labelPosition: min(max(width * fraction(for: date), 28), width - 28)
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

struct DayStatusBarAxis {
    static func markerDates(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return [] }

        let intervalHours: Int
        if duration > 8 * 60 * 60 {
            intervalHours = 4
        } else if duration >= 3 * 60 * 60 {
            intervalHours = 2
        } else {
            intervalHours = 1
        }

        var components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        components.minute = 0
        components.second = 0
        components.nanosecond = 0

        guard var marker = calendar.date(from: components) else { return [] }
        if marker <= start {
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: marker) else { return [] }
            marker = nextHour
        }

        while calendar.component(.hour, from: marker) % intervalHours != 0 {
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: marker) else { return [] }
            marker = nextHour
        }

        var markers: [Date] = []
        while marker < end {
            markers.append(marker)
            guard let nextMarker = calendar.date(byAdding: .hour, value: intervalHours, to: marker) else {
                break
            }
            marker = nextMarker
        }

        return markers
    }
}
