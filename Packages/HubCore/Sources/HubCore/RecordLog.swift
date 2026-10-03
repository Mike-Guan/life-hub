import Foundation

/// An append-only list of records stored as one JSON document.
public protocol RecordLog: Codable, Sendable {
    associatedtype Record: Identifiable & Sendable where Record.ID == UUID

    var records: [Record] { get set }
    init()
}

extension RecordLog {
    /// `self` plus the records in `other` that `self` doesn't have yet, matched by `id`.
    func merged(with other: Self) -> Self {
        let known = Set(records.map(\.id))
        var result = self
        result.records += other.records.filter { !known.contains($0.id) }
        return result
    }
}

/// Decodes one list element, keeping the raw JSON when the element can't be read.
struct LossyRecord<Value: Decodable>: Decodable {
    let value: Value?
    let raw: JSONValue

    init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        value = try? Value(from: decoder)
    }
}

/// Shared JSON settings for files the hub writes.
enum HubJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Reads and writes one `RecordLog` file.
struct LogFile<Log: RecordLog> {
    let url: URL?
    /// Name used in error messages, e.g. "mode 记录".
    let name: String
    // Set when the file exists but can't be read (for example before first unlock). Saving then
    // would overwrite records we never saw, so saves wait until a read succeeds.
    private(set) var readBlocked = false

    init(url: URL?, name: String) {
        self.url = url
        self.name = name
    }

    /// Loads the file and merges it into `log`.
    /// - Returns: an error message for the UI, or `nil` when the file was read or doesn't exist.
    mutating func load(into log: inout Log) -> String? {
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            readBlocked = false
            return nil
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            readBlocked = true
            return "暂时读不到\(name)，改动先留在内存里：\(error.localizedDescription)"
        }
        readBlocked = false
        do {
            log = try HubJSON.decoder().decode(Log.self, from: data).merged(with: log)
            return nil
        } catch {
            // Keep the unreadable file aside so the next save can't overwrite it.
            let backup = url.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return "\(name)读不出来，已备份到 \(backup.lastPathComponent)：\(error.localizedDescription)"
        }
    }

    /// Writes `log`, first merging in the file if an earlier read was blocked.
    /// - Returns: an error message for the UI, or `nil` on success.
    mutating func save(_ log: inout Log) -> String? {
        guard let url else { return nil }
        if readBlocked, let error = load(into: &log) {
            return error
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try HubJSON.encoder().encode(log).write(to: url, options: .atomic)
            return nil
        } catch {
            return "保存\(name)失败：\(error.localizedDescription)"
        }
    }
}
