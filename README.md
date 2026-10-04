# OpenAir

<img src="docs/assets/openair-icon.png" alt="OpenAir app icon" width="160" />

**Know when to open your windows.**

OpenAir is an iOS 26 SwiftUI app that recommends when outdoor temperature, dew point, rain, and wind are suitable for opening windows.

<a href="https://apps.apple.com/us/app/openair-window-weather/id6777466080">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" width="150" />
</a>

## Screenshots

<p>
  <img src="project-resources/screenshots/v3/01_open_now.png" alt="OpenAir dashboard showing current window recommendation" width="300" />
  <img src="project-resources/screenshots/v3/02_48_hour_outlook.png" alt="OpenAir forecast showing 48-hour window outlook" width="300" />
  <img src="project-resources/screenshots/v3/03_hourly_details.png" alt="OpenAir showing hourly detail" width="300" />
  <img src="project-resources/screenshots/v3/04_custom_comfort.png" alt="OpenAir custom comfort settings" width="300" />
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

## Background Refresh Debugging

To manually trigger the `BGAppRefreshTask` handler while the app is running from Xcode, paste this into the LLDB console:

```lldb
(lldb) e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.openairapp.openair.refresh"]
```

This tests the registered background refresh handler only. It does not prove iOS will run background refresh on a predictable schedule.

## Recommendation Logic

OpenAir considers:

- Outdoor temperature
- Dew point
- Rain
- Wind speed
- Current window state

The recommendation engine is deterministic and covered by unit tests.

## Architecture

OpenAir uses SwiftUI Model–View with focused observable stores. Views observe the
stores they need; `AppCoordinator` connects workflows across stores.

- `Stores`: `WeatherStore` owns forecast state, refresh queuing, caching,
  recommendation stabilization, and widget publication. `LocationStore` owns
  location selection, authorization, monitoring, and background-follow guidance.
  `NotificationStore` owns notification permissions and alert scheduling.
  `UserPreferenceStore` persists onboarding, comfort preferences, and settings.
- `Coordinators`: `AppCoordinator` handles lifecycle refreshes, onboarding
  completion, location changes followed by refresh, preference updates,
  background execution, and review events. Feature stores do not reference one
  another. `WeatherRequestCoordinator` resolves request targets and refresh
  eligibility; `LocationFollowController` manages location-follow permissions
  and monitoring.
- `App`: `DependencyContainer` constructs shared adapters and stores, wires the
  coordinator, and injects dependencies into SwiftUI.
- `Domain`: weather models and the deterministic recommendation engine.
- `Services`: protocol-based WeatherKit, Core Location, MapKit, notification,
  cache, widget/watch publication, and background-execution adapters.
- `Features`: onboarding, dashboard, forecast, hour detail, settings, and tip jar
  views and presentation models.
- `OpenAirWidgetShared`: snapshot models, persistence, and shared widget views
  used by the iOS/watch widget targets and watch app.
- `OpenAirTests`: focused store tests and coordinator integration tests, alongside
  recommendation boundaries, notification transitions, persistence, and
  presentation-model tests, written with Swift Testing.

The main dependency direction is views → stores/coordinator → service protocols
and domain logic. Concrete adapters implement those protocols using Apple
frameworks. The coordinator wires store callbacks for cross-feature effects;
stores keep their own state and share one preference-store instance.

## Contributing

Contributions are welcome.

Good first contributions include bug fixes, UI polish, accessibility improvements, documentation updates, and recommendation logic tests.

Before opening a large pull request, please start a GitHub issue to discuss the change.

## Privacy

OpenAir uses location to fetch local weather conditions. Alerts are local and best-effort. iOS can delay or skip background refreshes.
Weather and location data are used only for the app's window-opening recommendations.

## Support

[Leave a review on the App Store](https://apps.apple.com/app/id6777466080?action=write-review)

[openairappsupport@gmail.com](mailto:openairappsupport@gmail.com)
