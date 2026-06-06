import CoreLocation
import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var page = 0
    @State private var query = ""
    @State private var hasChosenLocation = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 24) {
                Spacer(minLength: 12)
                Image("AppIconPreview")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .clipShape(.rect(cornerRadius: 26))
                    .shadow(color: OpenAirColor.teal.opacity(0.25), radius: 18, y: 8)
                    .accessibilityHidden(true)

                Group {
                    switch page {
                    case 0: welcome
                    case 1: location
                    default: notifications
                    }
                }
                .frame(maxWidth: 520)
                Spacer()
                controls
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden()
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Text("OpenAir")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(OpenAirColor.navy)
            Text("Know when to open your windows.")
                .font(.title2.weight(.semibold))
            Text("OpenAir evaluates outdoor temperature, dew point, rain, and wind. It does not measure or compare your indoor air.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var location: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(OpenAirColor.teal)
            Text("Choose your weather location")
                .font(.title2.bold())
            Text("Use your current location, or search for one city. OpenAir never requests continuous background location.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Use Current Location", systemImage: "location.fill") {
                store.useCurrentLocation()
                store.requestLocationPermission()
                hasChosenLocation = true
            }
            .buttonStyle(.glassProminent)

            TextField("Search city", text: $query)
                .textContentType(.addressCity)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .onSubmit { Task { await store.searchPlaces(query) } }
                .accessibilityIdentifier("citySearchField")

            if store.isSearching {
                ProgressView()
            } else {
                ForEach(store.searchResults.prefix(4)) { place in
                    Button {
                        store.choose(place: place)
                        query = place.name
                        hasChosenLocation = true
                    } label: {
                        HStack {
                            Image(systemName: store.savedPlace == place ? "checkmark.circle.fill" : "mappin.circle")
                            Text(place.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notifications: some View {
        VStack(spacing: 18) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(OpenAirColor.teal)
            Text("Best-effort alerts")
                .font(.title2.bold())
            Text("OpenAir can schedule the next forecasted open and close times. iOS may delay background updates, so alerts can become stale.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Allow Notifications", systemImage: "bell.fill") {
                Task { await store.requestNotificationPermission() }
            }
            .buttonStyle(.glassProminent)
            Text(notificationLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack {
            if page > 0 {
                Button("Back") { page -= 1 }
                    .buttonStyle(.glass)
            }
            Spacer()
            if page < 2 {
                Button("Continue") { page += 1 }
                    .buttonStyle(.glassProminent)
                    .disabled(page == 1 && !hasChosenLocation && store.savedPlace == nil)
            } else {
                Button("Get Started") {
                    Task { await store.completeOnboarding() }
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("completeOnboardingButton")
            }
        }
    }

    private var notificationLabel: String {
        switch store.notificationStatus {
        case .authorized, .provisional, .ephemeral: "Notifications enabled"
        case .denied: "Notifications are disabled in Settings"
        default: "You can change this later"
        }
    }
}
