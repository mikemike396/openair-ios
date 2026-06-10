import Foundation

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
