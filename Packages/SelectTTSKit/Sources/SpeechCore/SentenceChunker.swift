import Foundation

/// Splits long text into synthesis-sized chunks on sentence boundaries.
///
/// Mandatory because OpenAI caps `input` at 4096 chars and selections routinely exceed that. The
/// TTS module synthesizes chunk N+1 while chunk N plays.
///
/// Algorithm: segment into sentences (preferring the platform's sentence tokenizer, falling back to
/// punctuation), then greedily pack sentences into chunks up to `maxCharacters`. A single sentence
/// longer than the limit is split on word boundaries, and an unbreakable run is hard-split by
/// character so the limit is never exceeded.
public enum SentenceChunker {

    public static let defaultMaxCharacters = 4096

    /// Returns chunks each with `count <= maxCharacters`. Whitespace-only input yields `[]`.
    public static func chunk(_ text: String, maxCharacters: Int = defaultMaxCharacters) -> [String] {
        precondition(maxCharacters > 0, "maxCharacters must be positive")

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if trimmed.count <= maxCharacters { return [trimmed] }

        var chunks: [String] = []
        var current = ""

        func flush() {
            let c = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !c.isEmpty { chunks.append(c) }
            current = ""
        }

        for sentence in sentences(in: trimmed) {
            if sentence.count > maxCharacters {
                // Sentence alone exceeds the limit — emit what we have, then split it.
                flush()
                for piece in splitOversized(sentence, maxCharacters: maxCharacters) {
                    chunks.append(piece)
                }
                continue
            }
            // +1 accounts for the space we insert between joined sentences.
            let projected = current.isEmpty ? sentence.count : current.count + 1 + sentence.count
            if projected > maxCharacters {
                flush()
                current = sentence
            } else {
                current = current.isEmpty ? sentence : current + " " + sentence
            }
        }
        flush()
        return chunks
    }

    // MARK: - Sentence segmentation

    private static func sentences(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.bySentences, .localized]
        ) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                result.append(s)
            }
        }
        // Fallback if the tokenizer produced nothing (e.g. exotic input): split on newlines.
        if result.isEmpty {
            result = text
                .split(whereSeparator: { $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return result.isEmpty ? [text] : result
    }

    // MARK: - Oversized handling

    /// Splits a single over-long sentence on word boundaries, hard-splitting any single word that is
    /// itself longer than the limit. Every returned piece has `count <= maxCharacters`.
    private static func splitOversized(_ sentence: String, maxCharacters: Int) -> [String] {
        var pieces: [String] = []
        var current = ""

        func flush() {
            if !current.isEmpty { pieces.append(current); current = "" }
        }

        for word in sentence.split(separator: " ", omittingEmptySubsequences: true) {
            let word = String(word)
            if word.count > maxCharacters {
                flush()
                pieces.append(contentsOf: hardSplit(word, maxCharacters: maxCharacters))
                continue
            }
            let projected = current.isEmpty ? word.count : current.count + 1 + word.count
            if projected > maxCharacters {
                flush()
                current = word
            } else {
                current = current.isEmpty ? word : current + " " + word
            }
        }
        flush()
        return pieces
    }

    /// Last resort: split an unbreakable run by character count.
    private static func hardSplit(_ run: String, maxCharacters: Int) -> [String] {
        var pieces: [String] = []
        var index = run.startIndex
        while index < run.endIndex {
            let end = run.index(index, offsetBy: maxCharacters, limitedBy: run.endIndex) ?? run.endIndex
            pieces.append(String(run[index..<end]))
            index = end
        }
        return pieces
    }
}
