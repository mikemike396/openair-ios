import SwiftUI
import WeatherKit

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var attribution: WeatherAttribution?
    
    private func markURL(for attribution: WeatherAttribution) -> URL {
        colorScheme == .dark
            ? attribution.combinedMarkDarkURL
            : attribution.combinedMarkLightURL
    }
    
    var body: some View {
        HStack(alignment: .center) {
            if let attribution {
                Button {
                    openURL(attribution.legalPageURL)
                } label: {
                    HStack(spacing: 8) {
                        AsyncImage(url: markURL(for: attribution)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .empty:
                                ProgressView()
                            case .failure:
                                Color.clear
                            @unknown default:
                                Color.clear
                            }
                        }
                        .frame(height: 18)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apple Weather legal attribution")
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 18)
                    .accessibilityLabel("Loading Apple Weather attribution")
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            attribution = try? await WeatherService.shared.attribution
        }
    }
}

struct WeatherLegalLinkView: View {
    @State private var attribution: WeatherAttribution?

    var body: some View {
        Group {
            if let attribution {
                Link(destination: attribution.legalPageURL) {
                    LabeledContent("Weather legal attribution", value: "Apple Weather")
                }
                .accessibilityLabel("Apple Weather legal attribution")
            } else {
                LabeledContent("Weather legal attribution", value: "Loading…")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Loading Apple Weather legal attribution")
            }
        }
        .task {
            attribution = try? await WeatherService.shared.attribution
        }
    }
}

#Preview("WeatherAttributionView") {
    WeatherAttributionView()
}

#Preview("WeatherLegalLinkView") {
    WeatherLegalLinkView()
}
