import SwiftUI

struct OnboardingLocationPage: View {
    @Binding var query: String
    var isSearchFocused: FocusState<Bool>.Binding

    let isChoosingCurrentLocation: Bool
    let currentLocationMessage: String?
    let selectedLocationLabel: String?
    let savedPlace: SavedPlace?
    let searchResults: [SavedPlace]
    let isSearching: Bool
    let searchResultsAnchor: String
    let chooseCurrentLocation: () -> Void
    let submitSearch: () -> Void
    let searchAfterDebounce: (String) async -> Void
    let choosePlace: (SavedPlace) -> Void

    var body: some View {
        VStack(spacing: isSearchFocused.wrappedValue ? 12 : 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: isSearchFocused.wrappedValue ? 40 : 56))
                .foregroundStyle(.openAirTeal)
                .animation(.easeOut(duration: 0.2), value: isSearchFocused.wrappedValue)

            Text("Choose your weather location")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !isSearchFocused.wrappedValue {
                Text("Use your current location, or search for one city. OpenAir never requests continuous background location.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)

                Button(action: chooseCurrentLocation) {
                    Label(
                        isChoosingCurrentLocation ? "Finding Location" : "Use Current Location",
                        systemImage: "location.fill"
                    )
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
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

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

            TextField("Search city", text: $query)
                .textContentType(.addressCity)
                .focused(isSearchFocused)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .onSubmit(submitSearch)
                .task(id: query) {
                    await searchAfterDebounce(query)
                }
                .accessibilityIdentifier("citySearchField")

            VStack(spacing: 8) {
                Color.clear
                    .frame(height: 1)
                    .id(searchResultsAnchor)

                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(searchResults) { place in
                        Button {
                            choosePlace(place)
                        } label: {
                            HStack {
                                Image(systemName: savedPlace == place ? "checkmark.circle.fill" : "mappin.circle")
                                Text(place.name)
                                Spacer()
                            }
                            .frame(minHeight: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: isSearching || !searchResults.isEmpty ? 128 : 1, alignment: .top)
        }
    }
}
