import Foundation

struct RacketPointRailEntry: Identifiable, Equatable {
    let id: String
    let serverSide: String?
    let displaySide: String
    let displaySideLabel: String
    let displayScore: String
    let isCurrentServe: Bool
    let actionLabel: String?

    init(
        id: String,
        serverSide: String?,
        displaySide: String,
        displaySideLabel: String,
        displayScore: String,
        isCurrentServe: Bool,
        actionLabel: String? = nil
    ) {
        self.id = id
        self.serverSide = serverSide
        self.displaySide = displaySide
        self.displaySideLabel = displaySideLabel
        self.displayScore = displayScore
        self.isCurrentServe = isCurrentServe
        self.actionLabel = actionLabel
    }
}

enum RacketPointRailReducer {
    static func replacingLatestServiceSide(
        in history: [RacketPointRailEntry],
        sideLabel: String,
        eventID: String
    ) -> [RacketPointRailEntry] {
        guard let lastEntry = history.last else {
            return history
        }

        var reconciled = history
        reconciled[reconciled.count - 1] = RacketPointRailEntry(
            id: eventID,
            serverSide: lastEntry.serverSide,
            displaySide: lastEntry.displaySide,
            displaySideLabel: sideLabel,
            displayScore: lastEntry.displayScore,
            isCurrentServe: true,
            actionLabel: lastEntry.actionLabel
        )
        return reconciled
    }

    static func reconcile(
        history: [RacketPointRailEntry],
        currentServe: RacketPointRailEntry
    ) -> [RacketPointRailEntry] {
        guard let lastEntry = history.last else {
            return [currentServe]
        }

        guard lastEntry.serverSide == currentServe.serverSide,
              lastEntry.displayScore == currentServe.displayScore else {
            return history + [currentServe]
        }

        if lastEntry.displaySideLabel == currentServe.displaySideLabel {
            return history
        }

        var reconciled = history
        reconciled[reconciled.count - 1] = currentServe
        return reconciled
    }
}
