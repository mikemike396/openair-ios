import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    @State private var page = 0
    @State private var query = ""
    @State private var hasChosenLocation = false
    @State private var isChoosingCurrentLocation = false
    @State private var currentLocationMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field {
        case citySearch
    }

    private let searchResultsAnchor = "searchResultsAnchor"

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: page == 0 ? 44 : 34) {
                            Color.clear
                                .frame(height: focusedField == .citySearch ? 12 : 32)

                            if page == 0 && focusedField != .citySearch {
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
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            Group {
                                switch page {
                                case 0:
                                    welcome
                                case 1:
                                    location
                                default:
                                    notifications
                                }
                            }
                            .frame(maxWidth: 520)
                        }
                        .padding(24)
                        .padding(.bottom, 96)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaPadding(.bottom, focusedField == .citySearch ? 24 : 0)
                    .animation(.easeOut(duration: 0.2), value: focusedField)
                    .onChange(of: focusedField) { _, newValue in
                        guard newValue == .citySearch else { return }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            guard focusedField == .citySearch else { return }

                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy.scrollTo(searchResultsAnchor, anchor: .center)
                            }
                        }
                    }
                }
            }

            controls
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .background {
                    LinearGradient(
                        colors: [.clear, Color(.systemBackground).opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
                .opacity(focusedField == .citySearch ? 0 : 1)
                .allowsHitTesting(focusedField != .citySearch)
                .animation(.easeOut(duration: 0.2), value: focusedField)
        }
        .navigationBarBackButtonHidden()
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Text("OpenAir")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.openAirBrandText)
                .minimumScaleFactor(0.85)
                .lineLimit(1)

            Text("Know when to open your windows.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

            Text("OpenAir evaluates outdoor temperature, dew point, rain, and wind. It does not measure or compare your indoor air.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var location: some View {
        VStack(spacing: focusedField == .citySearch ? 12 : 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: focusedField == .citySearch ? 40 : 56))
                .foregroundStyle(.openAirTeal)
                .animation(.easeOut(duration: 0.2), value: focusedField)

            Text("Choose your weather location")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if focusedField != .citySearch {
                Text("Use your current location, or search for one city. OpenAir never requests continuous background location.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)

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
                .transition(.opacity)
            }

            if isChoosingCurrentLocation {
                ProgressView()
            } else if let currentLocationMessage {
                Text(currentLocationMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
            }

            selectedLocationSummary

            TextField("Search city", text: $query)
                .textContentType(.addressCity)
                .focused($focusedField, equals: .citySearch)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .onSubmit {
                    Task { await store.searchPlaces(query) }
                }
                .task(id: query) {
                    await searchAfterDebounce()
                }
                .accessibilityIdentifier("citySearchField")

            searchResults
        }
    }

    @ViewBuilder
    private var selectedLocationSummary: some View {
        if let selectedLocationLabel {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.openAirTeal)

                Text(selectedLocationLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)
            .accessibilityIdentifier("selectedLocationLabel")
        }
    }

    private var selectedLocationLabel: String? {
        if let savedPlace = store.savedPlace {
            return "Selected: \(savedPlace.name)"
        }

        if hasChosenLocation {
            return "Selected: Current location"
        }

        return nil
    }

    private var searchResults: some View {
        VStack(spacing: 8) {
            Color.clear
                .frame(height: 1)
                .id(searchResultsAnchor)

            if store.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(store.searchResults.prefix(4)) { place in
                    Button {
                        store.choose(place: place)
                        query = ""
                        hasChosenLocation = true
                        currentLocationMessage = nil
                        focusedField = nil
                    } label: {
                        HStack {
                            Image(systemName: store.savedPlace == place ? "checkmark.circle.fill" : "mappin.circle")

                            Text(place.name)

                            Spacer()
                        }
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minHeight: store.isSearching || !store.searchResults.isEmpty ? 128 : 1, alignment: .top)
    }

    private var notifications: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.openAirTeal)

            Text("Best-effort alerts")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

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
                Button("Back") {
                    page -= 1
                }
                .buttonStyle(.glass)
            }

            Spacer()

            if page < 2 {
                Button("Continue") {
                    page += 1
                }
                .buttonStyle(.glassProminent)
                .disabled(!canContinue)
            } else {
                Button("Get Started") {
                    Task { await store.completeOnboarding() }
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("completeOnboardingButton")
            }
        }
    }

    private var canContinue: Bool {
        switch page {
        case 1:
            (hasChosenLocation || store.savedPlace != nil) && !isChoosingCurrentLocation
        default:
            true
        }
    }

    private var notificationLabel: String {
        switch store.notificationStatus {
        case .authorized, .provisional, .ephemeral:
            "Notifications enabled"
        case .denied:
            "Notifications are disabled in Settings"
        default:
            "You can change this later"
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
        currentLocationMessage = didChoose ? nil : store.searchError

        if didChoose {
            query = ""
            store.clearSearchResults()
            focusedField = nil
        }
    }
}
