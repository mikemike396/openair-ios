import SwiftUI

struct ForecastView: View {
    let plan: RecommendationPlan
    let preferences: ComfortPreferences
    var initialSelectedDate: Date? = nil

    private var unit: TemperatureUnit {
        preferences.temperatureUnit
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    ForecastTimelineCard(
                        items: plan.hourly,
                        unit: unit,
                        preferences: preferences,
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
