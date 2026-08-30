import Foundation

/// Future instants at which `resolve` would change its answer for this item:
/// the fresh→aging transition and the aging→unknown transition.
///
/// For `.onComingHome` only the 24h ceiling is predictable; the geofence
/// transition arrives as an explicit timeline reload.
public func boundaries(
    for item: Item,
    after date: Date,
    calendar: Calendar = .current
) -> [Date] {
    guard let last = item.lastConfirmedAt,
          let end = expiry(
            for: item.lastConfirmationRule ?? item.resetRule,
            confirmedAt: last,
            calendar: calendar
          )
    else { return [] }

    let window = end.timeIntervalSince(last)
    let agesAt = last.addingTimeInterval(window * agingThreshold)
    return [agesAt, end].filter { $0 > date }
}
