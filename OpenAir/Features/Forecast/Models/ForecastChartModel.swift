import Foundation
import SwiftUI

struct ForecastReferenceLine: Identifiable, Equatable {
    let accessibilityLabel: String
    let value: Double

    var id: String { accessibilityLabel }
}

enum ForecastChartScale {
    static func domain(
        values: [Double],
        referenceValues: [Double]
    ) -> ClosedRange<Double> {
        let plottedValues = values + referenceValues
        guard let minimum = plottedValues.min(), let maximum = plottedValues.max() else {
            return 40...80
        }

        let padding = max((maximum - minimum) * 0.18, 6)
        return (minimum - padding)...(maximum + padding)
    }
}

enum ForecastMetric {
    case temperature
    case dewPoint

    var color: Color {
        switch self {
        case .temperature: .openAirAmber
        case .dewPoint: .openAirBlue
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .temperature: 2.25
        case .dewPoint: 3.5
        }
    }

    func value(for item: ForecastTimelineItem) -> Double {
        switch self {
        case .temperature: item.temperature
        case .dewPoint: item.dewPoint
        }
    }

    func referenceLines(
        for preferences: ComfortPreferences,
        unit: TemperatureUnit
    ) -> [ForecastReferenceLine] {
        switch self {
        case .temperature:
            [
                ForecastReferenceLine(
                    accessibilityLabel: "minimum comfort temperature",
                    value: unit.chartValue(preferences.idealMinimumFahrenheit)
                ),
                ForecastReferenceLine(
                    accessibilityLabel: "maximum comfort temperature",
                    value: unit.chartValue(preferences.idealMaximumFahrenheit)
                )
            ]
        case .dewPoint:
            [
                ForecastReferenceLine(
                    accessibilityLabel: "maximum comfortable dew point",
                    value: unit.chartValue(preferences.maximumDewPointFahrenheit)
                )
            ]
        }
    }
}

struct ForecastChartData {
    let items: [ForecastTimelineItem]
    let xDomain: ClosedRange<Date>
    let temperature: ForecastLineChartData
    let dewPoint: ForecastLineChartData
    let statusSegments: [ForecastStatusSegment]

    init(
        items: [(weather: HourlyWeather, recommendation: Recommendation)],
        unit: TemperatureUnit,
        preferences: ComfortPreferences
    ) {
        let timelineItems = items.map {
            ForecastTimelineItem(
                weather: $0.weather,
                status: $0.recommendation.status,
                reasons: $0.recommendation.reasons,
                unit: unit,
                temperatureSource: preferences.temperatureEvaluationSource
            )
        }
        let firstDate = timelineItems.first?.date ?? .now
        let lastDate = timelineItems.last?.date.addingTimeInterval(60 * 60)
            ?? firstDate.addingTimeInterval(60 * 60)

        self.items = timelineItems
        self.xDomain = firstDate...lastDate
        self.temperature = ForecastLineChartData(
            title: preferences.temperatureEvaluationSource.temperatureLabel,
            metric: .temperature,
            items: timelineItems,
            unit: unit,
            preferences: preferences
        )
        self.dewPoint = ForecastLineChartData(
            title: "Dew point",
            metric: .dewPoint,
            items: timelineItems,
            unit: unit,
            preferences: preferences
        )
        self.statusSegments = ForecastStatusSegment.segments(for: timelineItems)
    }

    func nearestItem(to date: Date?) -> ForecastTimelineItem? {
        guard let date else { return nil }
        return items.nearest(to: date)
    }
}

struct ForecastLineChartData {
    let title: String
    let metric: ForecastMetric
    let referenceLines: [ForecastReferenceLine]
    let yDomain: ClosedRange<Double>
    let accessibilitySummary: String

    init(
        title: String,
        metric: ForecastMetric,
        items: [ForecastTimelineItem],
        unit: TemperatureUnit,
        preferences: ComfortPreferences
    ) {
        let referenceLines = metric.referenceLines(for: preferences, unit: unit)

        self.title = title
        self.metric = metric
        self.referenceLines = referenceLines
        self.yDomain = ForecastChartScale.domain(
            values: items.map { metric.value(for: $0) },
            referenceValues: referenceLines.map(\.value)
        )
        self.accessibilitySummary = Self.accessibilitySummary(
            title: title,
            items: items,
            referenceLines: referenceLines,
            unit: unit
        )
    }

    private static func accessibilitySummary(
        title: String,
        items: [ForecastTimelineItem],
        referenceLines: [ForecastReferenceLine],
        unit: TemperatureUnit
    ) -> String {
        guard let first = items.first, let last = items.last else {
            return "\(title) forecast chart unavailable"
        }

        let thresholds = referenceLines.map {
            "\($0.accessibilityLabel) \(Int($0.value.rounded()))\(unit.symbol)"
        }
        .joined(separator: ", ")

        return "\(title) forecast chart from \(first.date.formatted(date: .omitted, time: .shortened)) to \(last.date.formatted(date: .abbreviated, time: .shortened)). Comfort thresholds: \(thresholds)."
    }
}
