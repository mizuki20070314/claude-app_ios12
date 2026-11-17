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
            guard let nlRange = buffer.range(of: Data([0x0A])) else { break }
            var lineData = buffer.subdata(in: buffer.startIndex..<nlRange.lowerBound)
            // remove through newline
            buffer.removeSubrange(buffer.startIndex..<nlRange.upperBound)
            if lineData.last == 0x0D {
                lineData.removeLast()
            }
            guard let line = String(data: lineData, encoding: .utf8) else {
                // invalid UTF-8; skip line
                continue
            }
            processLine(line, events: &events)
        }

        return events
    }

    func finish() -> [SSEEvent] {
        var events: [SSEEvent] = []
        // process any remaining buffered partial line
        if !buffer.isEmpty {
            var lineData = buffer
            buffer = Data()
            if lineData.last == 0x0D { lineData.removeLast() }
            if let line = String(data: lineData, encoding: .utf8) {
                processLine(line, events: &events)
            }
        }
        // flush pending event if data present
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
