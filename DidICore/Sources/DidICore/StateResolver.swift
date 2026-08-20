import Foundation

public enum Freshness: Sendable, Equatable {
    case fresh
    case aging   // past 60% of the window
}

public enum ItemState: Sendable, Equatable {
    case unknown
    case confirmed(age: TimeInterval, freshness: Freshness)
}

/// Fraction of the window after which a confirmation reads as aging.
let agingThreshold = 0.6

/// The instant at which a confirmation made at `confirmedAt` stops counting.
/// `nil` means it never does (`.never`).
///
/// Calendar arithmetic goes through `nextDate(after:matching:)` so a `.dailyAt`
/// boundary survives DST — never 86400 arithmetic.
func expiry(for rule: ResetRule, confirmedAt: Date, calendar: Calendar) -> Date? {
    switch rule {
    case .dailyAt(let hour):
        return calendar.nextDate(
            after: confirmedAt,
            matching: DateComponents(hour: hour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
    case .afterHours(let n):
        return confirmedAt.addingTimeInterval(TimeInterval(n) * 3600)
    case .onLeavingHome:
        // 24h ceiling. The geofence exit is ORed in by the caller.
        return confirmedAt.addingTimeInterval(24 * 3600)
    case .never:
        return nil
    }
}

/// Pure. `now` is injected; nothing here calls `Date()`.
public func resolve(
    _ item: Item,
    lastLeftHome: Date? = nil,
    now: Date,
    calendar: Calendar = .current
) -> ItemState {
    guard let last = item.lastConfirmedAt else { return .unknown }
    let rule = item.lastConfirmationRule ?? item.resetRule

    if rule == .onLeavingHome, let left = lastLeftHome, left > last {
        return .unknown
    }

    let age = now.timeIntervalSince(last)
    guard let end = expiry(for: rule, confirmedAt: last, calendar: calendar) else {
        return .confirmed(age: age, freshness: .fresh)
    }
    if now >= end { return .unknown }

    let window = end.timeIntervalSince(last)
    let agesAt = last.addingTimeInterval(window * agingThreshold)
    return .confirmed(age: age, freshness: now >= agesAt ? .aging : .fresh)
}
