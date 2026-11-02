import Foundation

extension Cat {
    /// Adds a weigh-in (ENGINE.md "Current weight"): when its date is on or after the date of every other entry,
    /// it also sets the current weight and, if it has a BCS, the profile BCS. The engine uses `weightKg` as the current weight.
    /// An existing entry on the same date is replaced rather than duplicated.
    public mutating func addWeighIn(id: String, date: String, weightKg weight: Double, bcs: Int?) {
        weightLog.removeAll { $0.date == date }
        let isNewest = weightLog.allSatisfy { $0.date <= date }
        weightLog.append(WeightEntry(id: id, date: date, weightKg: weight, bcs: bcs))
        if isNewest {
            weightKg = weight
            if let bcs { profile.bcs = bcs }
        }
    }
    /// Removes a weigh-in. If it was the newest, the newest remaining entry becomes the current weight (and BCS, if it has one);
    /// removing the last entry leaves the weight unchanged.
    public mutating func removeWeighIn(id: String) {
        guard let removed = weightLog.first(where: { $0.id == id }) else { return }
        weightLog.removeAll { $0.id == id }
        guard weightLog.allSatisfy({ $0.date <= removed.date }),
              let newest = weightLog.max(by: { $0.date != $1.date ? $0.date < $1.date : $0.id < $1.id }) else { return }
        weightKg = newest.weightKg
        if let bcs = newest.bcs { profile.bcs = bcs }
    }
}
