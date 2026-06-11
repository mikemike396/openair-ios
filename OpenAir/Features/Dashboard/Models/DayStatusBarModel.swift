import CoreGraphics
import Foundation

struct DayStatusBarModel {
    let start: Date
    let end: Date
    let edgeOverscan: CGFloat

    init(start: Date, end: Date, edgeOverscan: CGFloat = 1) {
        self.start = start
        self.end = end
        self.edgeOverscan = edgeOverscan
    }

    func fraction(for date: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(start) / duration, 0), 1)
    }

    func segmentOffset(for window: RecommendationWindow, in width: CGFloat) -> CGFloat {
        let startFraction = fraction(for: window.start)
        let offset = width * startFraction
        return startFraction == 0 ? -edgeOverscan : offset
    }

    func segmentWidth(for window: RecommendationWindow, in width: CGFloat) -> CGFloat {
        let startFraction = fraction(for: window.start)
        let endFraction = fraction(for: window.end)
        var segmentWidth = width * max(0, endFraction - startFraction)

        if startFraction == 0 {
            segmentWidth += edgeOverscan
        }
        if endFraction == 1 {
            segmentWidth += edgeOverscan
        }

        return segmentWidth
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
