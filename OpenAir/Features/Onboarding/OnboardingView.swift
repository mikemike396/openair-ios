import SwiftUI

struct OnboardingView: View {
    @Environment(LocationStore.self) private var location
    @Environment(NotificationStore.self) private var notifications
    @AppCoordinatorEnvironment private var coordinator

    @State private var page = 0
    @State private var query = ""
    @State private var hasChosenLocation = false
    private var selection: LocationSelectionModel { location.selection }

    @FocusState private var isSearchFocused: Bool

    private let searchResultsAnchor = "searchResultsAnchor"

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: page == 0 ? 44 : 34) {
                            Color.clear
                                .frame(height: isSearchFocused ? 12 : 32)

                            if page == 0 && !isSearchFocused {
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
                                    OnboardingWelcomePage()
                                case 1:
                                    OnboardingLocationPage(
                                        query: $query,
                                        isSearchFocused: $isSearchFocused,
                                        isChoosingCurrentLocation: selection.isChoosingCurrentLocation,
                                        currentLocationMessage: selection.errorMessage,
                                        selectedLocationLabel: selectedLocationLabel,
                                        savedPlace: location.savedPlace,
                                        searchResults: Array(selection.searchResults.prefix(4)),
                                        isSearching: selection.isSearching,
                                        searchResultsAnchor: searchResultsAnchor,
                                        chooseCurrentLocation: {
                                            Task { await chooseCurrentLocation() }
                                        },
                                        submitSearch: {
                                            Task { await selection.searchPlaces(query) }
                                        },
                                        searchAfterDebounce: { query in
                                            await selection.searchPlaces(query, debounce: true)
                                        },
                                        choosePlace: choosePlace
                                    )
                                default:
                                    OnboardingNotificationsPage(
                                        authorizationStatus: notifications.authorizationStatus,
                                        statusLabel: notificationLabel,
                                        requestPermission: {
                                            Task { await notifications.requestPermission() }
                                        }
                                    )
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
                    .safeAreaPadding(.bottom, isSearchFocused ? 24 : 0)
                    .animation(.easeOut(duration: 0.2), value: isSearchFocused)
                    .onChange(of: isSearchFocused) { _, isFocused in
                        guard isFocused else { return }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            guard isSearchFocused else { return }

                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy.scrollTo(searchResultsAnchor, anchor: .center)
                            }
                        }
                    }
                }
            }

            OnboardingControls(
                page: page,
                canContinue: canContinue,
                goBack: { page -= 1 },
                continueForward: { page += 1 },
                complete: {
                    Task { await coordinator.completeOnboarding() }
                }
            )
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
            .opacity(isSearchFocused ? 0 : 1)
            .allowsHitTesting(!isSearchFocused)
            .animation(.easeOut(duration: 0.2), value: isSearchFocused)
        }
        .navigationBarBackButtonHidden()
        .appBackground()
    }

    private var selectedLocationLabel: String? {
        if let savedPlace = location.savedPlace {
            return "Selected: \(savedPlace.name)"
        }

        if hasChosenLocation {
            return "Selected: Current location"
        }

        return nil
    }

    private var canContinue: Bool {
        switch page {
        case 1:
            location.savedPlace != nil || (hasChosenLocation && !selection.isChoosingCurrentLocation)
        default:
            true
        }
    }

    private var notificationLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "Notifications enabled"
        case .denied:
            "Notifications are disabled in Settings"
        default:
            "You can change this later"
        }
    }

    private func chooseCurrentLocation() async {
        let didChoose = await coordinator.useCurrentLocation()

        hasChosenLocation = didChoose

        if didChoose {
            query = ""
            selection.clearSearchResults()
            isSearchFocused = false
        }
    }

    private func choosePlace(_ place: SavedPlace) {
        location.choose(place: place)
        query = ""
        hasChosenLocation = true
        selection.errorMessage = nil
        isSearchFocused = false
    }
}
