import Compression
import Foundation

enum ZipArchiveError: LocalizedError {
    case invalidArchive
    case entryMissing(String)
    case inflateFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "不是有效的 ZIP / OOXML 包。"
        case .entryMissing(let name):
            return "压缩包内没有 \(name)。"
        case .inflateFailed(let name):
            return "无法解压 \(name)。"
        }
    }
}

/// 读取 STORE / DEFLATE 的 ZIP 条目。用于打开真实 .xlsx / .docx，不改写原件。
enum ZipArchive {
    static func data(named name: String, in url: URL) throws -> Data {
        try data(named: name, from: Data(contentsOf: url))
    }

    static func data(named name: String, from archive: Data) throws -> Data {
        guard let entry = try locate(name: name, in: archive) else {
            throw ZipArchiveError.entryMissing(name)
        }
        return try extract(entry, from: archive)
    }

    static func hasEntry(named name: String, in url: URL) -> Bool {
        guard let archive = try? Data(contentsOf: url) else { return false }
        return (try? locate(name: name, in: archive)) != nil
    }

    private struct Entry {
        var name: String
        var method: UInt16
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    private static func locate(name: String, in data: Data) throws -> Entry? {
        guard let eocd = findEOCD(in: data) else { throw ZipArchiveError.invalidArchive }
        let cdOffset = Int(readU32(data, eocd + 16))
        let cdSize = Int(readU32(data, eocd + 12))
        let count = Int(readU16(data, eocd + 10))
        var cursor = cdOffset
        let end = min(data.count, cdOffset + max(cdSize, 0))
        var found: Entry?
        for _ in 0..<max(count, 1) {
            if cursor + 46 > end { break }
            if readU32(data, cursor) != 0x02014b50 { break }
            let method = readU16(data, cursor + 10)
            let compressed = Int(readU32(data, cursor + 20))
            let uncompressed = Int(readU32(data, cursor + 24))
            let nameLen = Int(readU16(data, cursor + 28))
            let extraLen = Int(readU16(data, cursor + 30))
            let commentLen = Int(readU16(data, cursor + 32))
            let localOff = Int(readU32(data, cursor + 42))
            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else { break }
            let entryName = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? ""
            if entryName == name {
                found = Entry(
                    name: entryName,
                    method: method,
                    compressedSize: compressed,
                    uncompressedSize: uncompressed,
                    localHeaderOffset: localOff
                )
                break
            }
            cursor = nameEnd + extraLen + commentLen
        }
        return found
    }

    private static func extract(_ entry: Entry, from data: Data) throws -> Data {
        let local = entry.localHeaderOffset
        guard local + 30 <= data.count, readU32(data, local) == 0x04034b50 else {
            throw ZipArchiveError.invalidArchive
        }
        let nameLen = Int(readU16(data, local + 26))
        let extraLen = Int(readU16(data, local + 28))
        let dataStart = local + 30 + nameLen + extraLen
        let dataEnd = dataStart + entry.compressedSize
        guard dataEnd <= data.count else { throw ZipArchiveError.invalidArchive }
        let payload = data.subdata(in: dataStart..<dataEnd)
        switch entry.method {
        case 0:
            return payload
        case 8:
            return try inflate(payload, expected: entry.uncompressedSize, name: entry.name)
        default:
            throw ZipArchiveError.inflateFailed(entry.name)
        }
    }

    private static func inflate(_ input: Data, expected: Int, name: String) throws -> Data {
        let destCount = max(expected, input.count * 8, 256)
        if let raw = decodeZlib(input, destCount: destCount) {
            return raw
        }
        // ZIP 是 raw DEFLATE；个别运行时只吃 zlib 头。
        var wrapped = Data([0x78, 0x9C])
        wrapped.append(input)
        if let zlib = decodeZlib(wrapped, destCount: destCount) {
            return zlib
        }
        throw ZipArchiveError.inflateFailed(name)
    }

    private static func decodeZlib(_ input: Data, destCount: Int) -> Data? {
        var dest = Data(count: destCount)
        let written = dest.withUnsafeMutableBytes { destPtr -> Int in
            input.withUnsafeBytes { srcPtr -> Int in
                guard let dst = destPtr.bindMemory(to: UInt8.self).baseAddress,
                      let src = srcPtr.bindMemory(to: UInt8.self).baseAddress
                else { return 0 }
                return compression_decode_buffer(dst, destCount, src, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        dest.count = written
        return dest
    }

    private static func findEOCD(in data: Data) -> Int? {
        let minEOCD = 22
        guard data.count >= minEOCD else { return nil }
        let start = data.count - minEOCD
        let oldest = max(0, start - 65_535)
        var i = start
        while i >= oldest {
            if readU32(data, i) == 0x06054b50 { return i }
            if i == 0 { break }
            i -= 1
        }
        return nil
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
