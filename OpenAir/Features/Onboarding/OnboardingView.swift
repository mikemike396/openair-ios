import CoreLocation
import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var page = 0
    @State private var query = ""
    @State private var hasChosenLocation = false
    @State private var isChoosingCurrentLocation = false
    @State private var currentLocationMessage: String?

    var body: some View {
        ZStack {
            AppBackground()
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 12)
                        Image("AppIconPreview")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .padding(18)
                            .background(.openAirTeal, in: .rect(cornerRadius: 28))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(.openAirMint.opacity(0.35), lineWidth: 1)
                            }
                            .shadow(color: .openAirTeal.opacity(0.25), radius: 18, y: 8)
                            .accessibilityHidden(true)

                        Group {
                            switch page {
                            case 0: welcome
                            case 1: location
                            default: notifications
                            }
                        }
                        .frame(maxWidth: 520)
                        Spacer(minLength: 16)
                        controls
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Text("OpenAir")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.openAirBrandText)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            Text("Know when to open your windows.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
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
                .foregroundStyle(.openAirTeal)
            Text("Choose your weather location")
                .font(.title2.bold())
            Text("Use your current location, or search for one city. OpenAir never requests continuous background location.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await chooseCurrentLocation() }
            } label: {
                if isChoosingCurrentLocation {
                    Label("Finding Location", systemImage: "location.fill")
                } else {
                    Label("Use Current Location", systemImage: "location.fill")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(isChoosingCurrentLocation)

            if isChoosingCurrentLocation {
                ProgressView()
            } else if let currentLocationMessage {
                Text(currentLocationMessage)
                    .font(.footnote)
                    .foregroundStyle(hasChosenLocation ? Color.secondary : Color.red)
                    .multilineTextAlignment(.center)
            }

            TextField("Search city", text: $query)
                .textContentType(.addressCity)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .onSubmit { Task { await store.searchPlaces(query) } }
                .task(id: query) {
                    await searchAfterDebounce()
                }
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
                .foregroundStyle(.openAirTeal)
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

    private func searchAfterDebounce() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            store.clearSearchResults()
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await store.searchPlaces(trimmedQuery)
    }

    private func chooseCurrentLocation() async {
        isChoosingCurrentLocation = true
        currentLocationMessage = nil
        let didChoose = await store.useCurrentLocation()
        isChoosingCurrentLocation = false
        hasChosenLocation = didChoose
        currentLocationMessage = didChoose ? "Current location selected" : store.searchError
    }
}
