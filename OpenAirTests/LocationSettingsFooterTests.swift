import Testing
@testable import OpenAir

struct LocationSettingsFooterTests {
    @Test
    func footerExplainsBackgroundFollowingWhenEnabled() {
        let text = LocationSettingsSection.followingFooter(isEnabled: true)
        #expect(text.contains("significant location changes"))
        #expect(text.contains("iOS controls when updates arrive"))
        #expect(!text.contains("When off"))
    }

    @Test
    func footerExplainsLastKnownPlaceWhenDisabled() {
        let text = LocationSettingsSection.followingFooter(isEnabled: false)
        #expect(text.contains("When off"))
        #expect(text.contains("last known place"))
    }
}
