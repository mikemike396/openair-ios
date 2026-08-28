import Foundation

struct HourlyDetailsDay: Identifiable {
    let date: Date
    let items: [(weather: HourlyWeather, recommendation: Recommendation)]

    var id: Date { date }

    static func groups(
        for items: [(weather: HourlyWeather, recommendation: Recommendation)],
        calendar: Calendar = .current
    ) -> [HourlyDetailsDay] {
        Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.weather.date)
        }
        .map { date, items in
            HourlyDetailsDay(
                date: date,
                items: items.sorted { $0.weather.date < $1.weather.date }
            )
        }
        .sorted { $0.date < $1.date }
    }
}
