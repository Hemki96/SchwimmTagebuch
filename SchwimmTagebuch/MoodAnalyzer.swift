import Foundation

struct MoodSummary {
    let positive: Int
    let negative: Int
    let neutral: Int
    let keywordFrequencies: [(String, Int)]

    var total: Int { positive + negative + neutral }
    var sentiment: Double {
        guard total > 0 else { return 0 }
        return Double(positive - negative) / Double(total)
    }
}

enum MoodAnalyzer {
    private static let positiveKeywords: Set<String> = [
        "stark", "gut", "locker", "frisch", "motiviert", "zufrieden", "flow", "energie", "leicht", "fokus"
    ]
    private static let negativeKeywords: Set<String> = [
        "müde", "schwer", "hart", "zäh", "schlecht", "verletzt", "heftig", "gestresst", "krank", "dunkel"
    ]

    static func analyze(notes: [String]) -> MoodSummary? {
        let cleaned = notes.map { $0.lowercased() }
        guard !cleaned.isEmpty else { return nil }

        var positive = 0
        var negative = 0
        var neutral = 0
        var keywords: [String: Int] = [:]

        for note in cleaned {
            var localScore = 0
            let words = note.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            for word in words {
                if positiveKeywords.contains(word) {
                    positive += 1
                    localScore += 1
                    keywords[word, default: 0] += 1
                } else if negativeKeywords.contains(word) {
                    negative += 1
                    localScore -= 1
                    keywords[word, default: 0] += 1
                } else if word.count > 3 {
                    keywords[word, default: 0] += 1
                }
            }
            if localScore == 0 {
                neutral += 1
            }
        }

        let sortedKeywords = keywords
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(8)
            .map { ($0.key, $0.value) }

        return MoodSummary(
            positive: positive,
            negative: negative,
            neutral: neutral,
            keywordFrequencies: Array(sortedKeywords)
        )
    }
}
