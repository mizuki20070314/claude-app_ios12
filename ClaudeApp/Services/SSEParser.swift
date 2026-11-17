import Foundation

struct SSEEvent {
    let event: String?
    let data: String
}

final class SSEParser {
    private var buffer = Data()
    private var currentEvent: String?
    private var dataLines: [String] = []
    private var hasData: Bool = false

    func feed(_ data: Data) -> [SSEEvent] {
        buffer.append(data)
        var events: [SSEEvent] = []

        while true {
            // find next line terminator (\n, \r, or \r\n)
            var termIndex: Data.Index? = nil
            var termLength = 0
            for i in buffer.indices {
                let b = buffer[i]
                if b == 0x0A {
                    termIndex = i
                    termLength = 1
                    break
                }
                if b == 0x0D {
                    let next = buffer.index(after: i)
                    if next < buffer.endIndex && buffer[next] == 0x0A {
                        termIndex = i
                        termLength = 2
                    } else {
                        termIndex = i
                        termLength = 1
                    }
                    break
                }
            }
            guard let idx = termIndex else { break }
            let lineData = buffer[buffer.startIndex..<idx]
            buffer.removeSubrange(buffer.startIndex..<buffer.index(idx, offsetBy: termLength))
            if let line = String(data: lineData, encoding: .utf8) {
                processLine(line, events: &events)
            }
        }

        return events
    }

    func finish() -> [SSEEvent] {
        var events: [SSEEvent] = []
        if !buffer.isEmpty {
            if let line = String(data: buffer, encoding: .utf8) {
                var l = line
                if l.hasSuffix("\r") { l.removeLast() }
                processLine(l, events: &events)
            }
            buffer = Data()
        }
        if hasData || currentEvent != nil {
            let data = dataLines.joined(separator: "\n")
            events.append(SSEEvent(event: currentEvent, data: data))
            currentEvent = nil
            dataLines = []
            hasData = false
        }
        return events
    }

    private func processLine(_ line: String, events: inout [SSEEvent]) {
        if line.isEmpty {
            if hasData || currentEvent != nil {
                let data = dataLines.joined(separator: "\n")
                events.append(SSEEvent(event: currentEvent, data: data))
                currentEvent = nil
                dataLines = []
                hasData = false
            }
            return
        }
        if line.hasPrefix(":") { return } // comment
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        var value = parts.count > 1 ? String(parts[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }
        switch field {
        case "event":
            currentEvent = value
        case "data":
            dataLines.append(value)
            hasData = true
        case "id", "retry":
            break
        default:
            break
        }
    }

    func reset() {
        buffer = Data()
        currentEvent = nil
        dataLines = []
        hasData = false
    }
}