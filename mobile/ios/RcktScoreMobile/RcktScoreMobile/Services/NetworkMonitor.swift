import Foundation
import Combine
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true

    private let monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "rcktscore.network-monitor")

    init(forcedOnlineState: Bool? = nil) {
        if let forcedOnlineState {
            isOnline = forcedOnlineState
            monitor = nil
            return
        }

        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            DispatchQueue.main.async { [weak self] in
                self?.isOnline = isOnline
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor?.cancel()
    }
}
