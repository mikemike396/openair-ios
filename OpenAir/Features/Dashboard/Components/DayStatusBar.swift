import SwiftUI

struct DayStatusBar: View {
    let windows: [RecommendationWindow]
    let start: Date
    let end: Date

    private let barHeight: CGFloat = 22
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

                    ForEach(visibleDividerMarks(in: proxy.size.width)) { mark in
                        Rectangle()
                            .fill(.white.opacity(0.22))
                            .frame(width: 1, height: barHeight)
                            .offset(x: mark.xPosition)
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
                ZStack(alignment: .leading) {
                    ForEach(axisMarks(in: proxy.size.width)) { mark in
                        Text(mark.label)
                            .frame(width: 56, alignment: mark.alignment)
                            .position(
                                x: mark.xPosition,
                                y: 8
                            )
                    }
                }
            }
            .frame(height: 16)
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
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: start)
        return [6, 12, 18].compactMap {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: dayStart)
        }
        .filter { start < $0 && $0 < end }
    }

    private func axisMarks(in width: CGFloat) -> [AxisMark] {
        let startMark = positionedAxisMark(date: start, label: "Now", alignment: .leading, width: width)
        let endMark = positionedAxisMark(date: end, label: "12 AM", alignment: .trailing, width: width)
        return [startMark] + visibleDividerMarks(in: width) + [endMark]
    }

    private func visibleDividerMarks(in width: CGFloat) -> [AxisMark] {
        let startMark = positionedAxisMark(date: start, label: "Now", alignment: .leading, width: width)
        let endMark = positionedAxisMark(date: end, label: "12 AM", alignment: .trailing, width: width)
        let minimumSpacing: CGFloat = 64
        return dividerDates
            .map {
                positionedAxisMark(
                    date: $0,
                    label: $0.formatted(.dateTime.hour()),
                    alignment: .center,
                    width: width
                )
            }
            .filter {
                abs($0.xPosition - startMark.xPosition) >= minimumSpacing &&
                abs(endMark.xPosition - $0.xPosition) >= minimumSpacing
            }
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
            xPosition: min(max(width * fraction(for: date), 28), width - 28)
        )
    }

    private struct AxisMark: Identifiable {
        let date: Date
        let label: String
        let alignment: Alignment
        let xPosition: CGFloat

        var id: Date { date }
    }
}
