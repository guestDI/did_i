import Testing
import Foundation
@testable import DidICore

@Test func decodesAConfirmMessage() {
    let id = UUID()
    let action = WatchActionDecoding.decode(["action": "confirm", "id": id.uuidString])
    #expect(action == .confirm(id: id))
}

@Test func decodesAClearMessage() {
    let id = UUID()
    let action = WatchActionDecoding.decode(["action": "clear", "id": id.uuidString])
    #expect(action == .clear(id: id))
}

@Test func decodingRejectsAnUnknownAction() {
    let action = WatchActionDecoding.decode(["action": "delete", "id": UUID().uuidString])
    #expect(action == nil)
}

@Test func decodingRejectsAMissingID() {
    let action = WatchActionDecoding.decode(["action": "confirm"])
    #expect(action == nil)
}

@Test func decodingRejectsAMalformedID() {
    let action = WatchActionDecoding.decode(["action": "confirm", "id": "not-a-uuid"])
    #expect(action == nil)
}

@Test func applyingConfirmStampsTheItem() {
    var s = Store(items: [item()])
    let id = s.items[0].id
    WatchActionDecoding.apply(.confirm(id: id), to: &s, at: at("2026-08-11 08:42:00"))
    #expect(s.items[0].lastConfirmedAt == at("2026-08-11 08:42:00"))
}

@Test func applyingClearRemovesTheConfirmation() {
    var s = Store(items: [item()])
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)
    WatchActionDecoding.apply(.clear(id: id), to: &s, at: at("2026-08-11 09:00:00"))
    #expect(s.items[0].lastConfirmedAt == nil)
}
