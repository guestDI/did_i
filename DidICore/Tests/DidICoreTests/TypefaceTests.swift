import Testing
@testable import DidICore

@Test func everyIBMTypefaceResourceIsBundledAndRegisters() {
    #expect(BoardTypeface.missingResources.isEmpty)
    #expect(BoardTypeface.registrationSucceeded)
}

@Test func boardWeightsResolveToTheBundledFaces() {
    #expect(BoardTypeface.name(for: .regular) == "IBMPlexMono")
    #expect(BoardTypeface.name(for: .medium) == "IBMPlexMono-Medm")
    #expect(BoardTypeface.name(for: .semibold) == "IBMPlexMono-SmBld")
    #expect(BoardTypeface.name(for: .bold) == "IBMPlexMono-Bold")
}
