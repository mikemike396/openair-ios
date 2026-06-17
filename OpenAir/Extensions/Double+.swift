import Foundation

extension Double {
    // MARK: - Defaults
    
    static let defaultIdealMinimumFahrenheit = 52.0
    static let defaultIdealMaximumFahrenheit = 78.0
    static let defaultMaximumDewPointFahrenheit = 62.0
    static let defaultMaximumRainChance = 0.50
    static let defaultMaximumWindMPH = 20.0
    static let defaultMaximumGustMPH = 35.0

    // MARK: - Configurable Max / Min
    
    // Temperature
    static let minimumConfigurableTemperatureFahrenheit = 45.0
    static let maximumConfigurableIdealMinimumFahrenheit = 70.0
    static let minimumConfigurableIdealMaximumFahrenheit = 65.0
    static let maximumConfigurableTemperatureFahrenheit = 85.0
    
    // Dew point
    static let minimumConfigurableDewPointFahrenheit = 45.0
    static let maximumConfigurableDewPointFahrenheit = 68.0

    // Rain
    static let minimumConfigurableRainChance = 0.05
    static let maximumConfigurableRainChance = 0.90
    
    // Wind
    static let minimumConfigurableWindMPH = 1.0
    static let maximumConfigurableWindMPH = 30.0
    
    // Gust
    static let minimumConfigurableGustMPH = 20.0
    static let maximumConfigurableGustMPH = 50.0
}
