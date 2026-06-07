# OpenAir

<img src="project-resources/icon/openair_icon_exports/openair_app_store_icon_1024.png" alt="OpenAir app icon" width="160" />

**Know when to open your windows.**

Window weather & dew point alerts.


OpenAir is an iOS 26 SwiftUI app that recommends when outdoor temperature, dew point, rain, and wind are suitable for opening windows.

## Screenshots

<p>
  <img src="doc/resources/openair-dashboard.png" alt="OpenAir dashboard showing current window recommendation" width="300" />
  <img src="doc/resources/openair-forecast.png" alt="OpenAir forecast showing 48-hour window outlook" width="300" />
</p>

## Features

- Window open/close recommendations based on outdoor conditions.
- Dew point aware comfort checks.
- Rain and wind safety checks.
- Local alerts when conditions change.
- Demo weather mode for unsigned simulator builds.

## Requirements

- Xcode 26
- iOS 26 simulator or device
- Apple Developer account with WeatherKit enabled
- Bundle ID: `com.openairapp.openair`

## Run

1. Open `OpenAir.xcodeproj`.
2. Select a development team for the `OpenAir` target.
3. Enable WeatherKit for the bundle ID `com.openairapp.openair` in the Apple Developer portal.
4. Build on an iOS 26 simulator or device.

Unsigned simulator builds can use **Use Demo Weather** when WeatherKit authentication is unavailable.

## Recommendation Logic

OpenAir considers:

- Outdoor temperature
- Dew point
- Rain
- Wind speed
- Current window state

The recommendation engine is deterministic and covered by unit tests.

## Architecture

- `Domain`: weather models and the deterministic recommendation engine.
- `Services`: WeatherKit, Core Location, MapKit, notification, and cache adapters.
- `Features`: onboarding, dashboard, schedule, hour detail, and settings.
- `OpenAirTests`: recommendation boundaries, windows, notification transitions, persistence, and location fallback behavior.

## Privacy

OpenAir uses location to fetch local weather conditions. Alerts are local and best-effort. iOS can delay or skip background refreshes.
Weather and location data are used only for the app's window-opening recommendations.

## Support

[openairappsupport@gmail.com](mailto:openairappsupport@gmail.com)
