import Foundation

enum NumberLockError: Error, Equatable, LocalizedError {
    case changedOrDroppedTokens([String])
    case sectionsNotMapped

    var errorDescription: String? {
        switch self {
        case .changedOrDroppedTokens(let tokens):
            let preview = tokens.prefix(6).joined(separator: "、")
            return "润色改动了锁定项（\(preview)）。已保留本地骨架。"
        case .sectionsNotMapped:
            return "润色回文无法按原章节套回。已保留本地骨架。"
        }
    }
}

/// 骨架里的数字、金额、合同条号、日历日期必须在润色稿中原样出现。
enum NumberLock {
    static func lockSource(of draft: DraftDocument) -> String {
        ([draft.title] + draft.sections.map { "\($0.heading)\n\($0.body)" })
            .joined(separator: "\n")
    }

    static func lockedTokens(in text: String) -> [String] {
        var found: [String] = []
        var seen = Set<String>()
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let patterns = [
            #"第[一二三四五六七八九十百千万零〇两0-9]+条(?:第[一二三四五六七八九十百千万零〇两0-9]+款)?"#,
            #"\d{4}年\d{1,2}月\d{1,2}日"#,
            #"\d{4}年\d{1,2}月"#,
            #"\d{1,3}(?:,\d{3})+(?:\.\d+)?"#,
            #"\d+\.\d+"#,
            #"\d{2,}"#,
            #"\d+(?=元)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: full) {
                let token = ns.substring(with: match.range)
                if seen.insert(token).inserted {
                    found.append(token)
                }
            }
        }
        return found
    }

    static func validate(skeleton: String, polished: String) throws {
        let missing = lockedTokens(in: skeleton).filter { !polished.contains($0) }
        if !missing.isEmpty {
            throw NumberLockError.changedOrDroppedTokens(missing)
        }
    }

    static func merge(_ polishedMarkdown: String, into draft: DraftDocument) -> Result<DraftDocument, NumberLockError> {
        do {
            try validate(skeleton: lockSource(of: draft), polished: polishedMarkdown)
        } catch let error as NumberLockError {
            return .failure(error)
        } catch {
            return .failure(.changedOrDroppedTokens([]))
        }

        let cleaned = FeeReportVoice.sanitize(polishedMarkdown, dropMarkdownHeadings: false)
        do {
            try validate(skeleton: lockSource(of: draft), polished: cleaned)
        } catch {
            // 清洗后若丢掉锁定数字，仍以未清洗稿做章节套回前的硬锁结果为准：失败则回退。
            return .failure((error as? NumberLockError) ?? .changedOrDroppedTokens([]))
        }

        var copy = draft
        var mapped = 0
        for index in copy.sections.indices {
            if let body = extractSection(copy.sections[index].heading, from: cleaned) {
                copy.sections[index].body = FeeReportVoice.sanitize(body)
                mapped += 1
            }
        }
        if mapped != copy.sections.count {
            return .failure(.sectionsNotMapped)
        }
        return .success(copy)
    }

    static func extractSection(_ heading: String, from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        var collecting = false
        var body: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let title = headingTitle(trimmed) {
                if collecting { break }
                collecting = title.contains(heading) || heading.contains(title)
                continue
            }
            if collecting { body.append(line) }
        }
        let text = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func headingTitle(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("#") else { return nil }
        return trimmed.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
    }
}
