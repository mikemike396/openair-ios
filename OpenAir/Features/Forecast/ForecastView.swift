import SwiftUI

struct ForecastView: View {
    let plan: RecommendationPlan
    let unit: TemperatureUnit
    var initialSelectedDate: Date? = nil

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    ForecastTimelineCard(
                        items: plan.hourly,
                        unit: unit,
                        initialSelectedDate: initialSelectedDate
                    )
                    HourlyDetailsCard(items: plan.hourly, unit: unit)
                }
                .padding()
            }
        }
        .navigationTitle("Forecast")
        .navigationBarTitleDisplayMode(.inline)
    }
}
