import XCTest
@testable import OpenAir

final class NotificationTransitionPlannerTests: XCTestCase {
    func testOnlyOpenClosedBoundaryChangesProduceNotifications() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let statuses: [RecommendationStatus] = [.open, .open, .keepClosed, .keepClosed, .open]
        let hourly = statuses.enumerated().map { index, status in
            (
                weather: HourlyWeather(
                    date: now.addingTimeInterval(Double(index + 1) * 3600),
                    temperatureFahrenheit: 65,
                    dewPointFahrenheit: 55,
                    precipitationChance: 0,
                    isPrecipitating: false,
                    isThunderstorm: false,
                    windMPH: 5,
                    gustMPH: 7,
                    symbolName: "sun.max"
                ),
                recommendation: Recommendation(status: status, reasons: [])
            )
        }
        let plan = RecommendationPlan(
            current: hourly[0].recommendation,
            hourly: hourly,
            windows: [],
            nextChange: nil
        )

        let transitions = NotificationTransitionPlanner().transitions(in: plan, after: now)

        XCTAssertEqual(transitions.map(\.status), [.keepClosed, .open])
    }

    func testPastTransitionsAreIgnored() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let weather = HourlyWeather(
            date: now.addingTimeInterval(-3600),
            temperatureFahrenheit: 65,
            dewPointFahrenheit: 55,
            precipitationChance: 0,
            isPrecipitating: false,
            isThunderstorm: false,
            windMPH: 5,
            gustMPH: 7,
            symbolName: "sun.max"
        )
        let plan = RecommendationPlan(
            current: .init(status: .open, reasons: []),
            hourly: [
                (weather, .init(status: .open, reasons: [])),
                (weather, .init(status: .keepClosed, reasons: []))
            ],
            windows: [],
            nextChange: nil
        )

        XCTAssertTrue(NotificationTransitionPlanner().transitions(in: plan, after: now).isEmpty)
    }
}
