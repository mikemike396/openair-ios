import Testing
@testable import OpenAir

@Test
func tipProductIdentifiersAreStableAndRecognized() {
    #expect(TipProductID.allIdentifiers == [
        "com.openairapp.openair.tip.small",
        "com.openairapp.openair.tip.medium",
        "com.openairapp.openair.tip.large"
    ])
    #expect(TipProductID(rawValue: "com.openairapp.openair.tip.small") == .small)
    #expect(TipProductID(rawValue: "com.openairapp.openair.tip.unknown") == nil)
}

@Test(arguments: [
    TipPurchaseOutcome.purchased,
    TipPurchaseOutcome.pending,
    TipPurchaseOutcome.failed
])
func nonCancelledTipOutcomesPresentFeedback(_ outcome: TipPurchaseOutcome) {
    #expect(outcome.alert != nil)
}

@Test
func cancelledTipDoesNotPresentFeedback() {
    #expect(TipPurchaseOutcome.cancelled.alert == nil)
}
