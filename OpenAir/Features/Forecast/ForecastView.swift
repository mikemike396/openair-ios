import SwiftUI

struct ForecastView: View {
    let plan: RecommendationPlan
    let preferences: ComfortPreferences
    @Binding var forecastRange: ForecastRange
    var initialSelectedDate: Date? = nil

    private var unit: TemperatureUnit {
        preferences.temperatureUnit
    }

    private var displayedItems: [(weather: HourlyWeather, recommendation: Recommendation)] {
        Array(plan.hourly.prefix(forecastRange.hourCount))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForecastTimelineCard(
                    items: displayedItems,
                    unit: unit,
                    preferences: preferences,
                    initialSelectedDate: initialSelectedDate,
                    rangeTitle: forecastRange.title
                )
                HourlyDetailsCard(
                    items: displayedItems,
                    unit: unit,
                    temperatureSource: preferences.temperatureEvaluationSource
                )
                WeatherAttributionView()
            }
            .padding()
        }
        .navigationTitle("Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Forecast range", selection: $forecastRange) {
                        ForEach(ForecastRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(forecastRange.title)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .accessibilityLabel("Forecast range: \(forecastRange.title)")
            }
        }
        .appBackground()
    }
}
