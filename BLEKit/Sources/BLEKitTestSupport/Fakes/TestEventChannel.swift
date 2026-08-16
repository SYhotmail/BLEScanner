import Foundation

/// A synchronous, thread-safe, replaying event channel used to back the fake dependency
/// clients. Buffers every sent element so a subscriber that attaches after some events have
/// already been sent still receives the full history, then finishing propagates to all
/// subscribers so `TestStore`'s exhaustive assertions can rely on the stream actually ending.
public final class TestEventChannel<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [AsyncStream<Element>.Continuation] = []
    private var buffered: [Element] = []
    private var isFinished = false

    public init() {}

    public func stream() -> AsyncStream<Element> {
        lock.lock()
        defer { lock.unlock() }
        return AsyncStream { continuation in
            for element in buffered {
                continuation.yield(element)
            }
            if isFinished {
                continuation.finish()
            } else {
                continuations.append(continuation)
            }
        }
    }

    public func send(_ element: Element) {
        lock.lock()
        buffered.append(element)
        let currentContinuations = continuations
        lock.unlock()
        for continuation in currentContinuations {
            continuation.yield(element)
        }
    }

    public func finish() {
        lock.lock()
        isFinished = true
        let currentContinuations = continuations
        continuations.removeAll()
        lock.unlock()
        for continuation in currentContinuations {
            continuation.finish()
        }
    }
}
