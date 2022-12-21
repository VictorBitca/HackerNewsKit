import UIKit
import SwiftScanner
import SwiftSoup

/// Turns the html of a comment from Hacker News to an AttributedString, valid html = `https://news.ycombinator.com/formatdoc`
public class CommentParser {
    static let htmlEntities = ["quot":"\"","amp":"&","apos":"'","lt":"<","gt":">", "#x2F":"/", "#38":"&", "#62":">", "#x27":"'", "#60":"<"]
    
    public static func buildAttributedText(from markup: String,
                                           textColor: UIColor = UIColor.darkText, font: UIFont,
                                           linkColor: UIColor = UIColor.link) -> NSAttributedString? {
        let preprocessed = CommentParser.preprocess(markup)

        guard let (text, tags) = try? parse(preprocessed) else {
            return nil
        }

        let attributedText = NSMutableAttributedString(string: text)
        let fontSize = font.pointSize
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 0.4 * font.lineHeight
        paragraphStyle.lineSpacing = 0.1 * font.lineHeight
        attributedText.addAttributes([.font: font,
                                      .foregroundColor: textColor,
                                      NSAttributedString.Key.paragraphStyle: paragraphStyle],
                                     range: NSRange.init(location: 0, length: text.count))

        for tag in tags {
            if tag.name == "a" {
                let initialLen = text.count
                var linkText = String(text.dropFirst(tag.range!.lowerBound))
                linkText = String(linkText.dropLast(initialLen - tag.range!.upperBound))
                let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: linkColor,
                                                                 .link: linkText,
                                                                 .underlineStyle: NSUnderlineStyle.single.rawValue]
                attributedText.addAttributes(attributes, range: NSRange(tag.range!))
            } else if tag.name == "code" {
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Courier", size: fontSize - 2)! ]
                attributedText.addAttributes(attributes, range: NSRange(tag.range!))
            } else if tag.name == "i" {
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: fontSize - 1)]
                attributedText.addAttributes(attributes, range: NSRange(tag.range!))
            } else if tag.name == "h1" { // for AskHN only
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
                attributedText.addAttributes(attributes, range: NSRange(tag.range!))
            }
        }
        return NSAttributedString(attributedString: attributedText)
    }

    // targets: <a href="https://hypebeast.com/2019/12/apple-airpods-stats-third-largest-product-2021-analysts" rel="nofollow">https://hypebeast.com/2019/12/apple-airpods-stats-third-larg...</a>
    static func preprocess(_ parentInput: String) -> String {
        var procesedIndices = Set<Int>()
        var processedContent = parentInput

        func subprocess(_ childInput: String) -> String {
            var tempInput = childInput

            let starts = childInput.indices(of: "<a href=\"")
            let ends = childInput.indices(of: "</a>")

            if starts.count != ends.count { return childInput }

            let pairs = starts.enumerated().map({ (index, element) in
                return (element, ends[index])
            })

            for (index, pair) in pairs.enumerated() {
                if !procesedIndices.contains(index) {
                    procesedIndices.insert(index)

                    let workingText = childInput[pair.0..<pair.1]
                    let quoteIndices = workingText.indices(of: "\"")
                    if quoteIndices.count < 2 { return tempInput }
                    if workingText.index(after: quoteIndices[0]) > quoteIndices[1] { return tempInput }
                    let sourceText = workingText[workingText.index(after: quoteIndices[0])..<quoteIndices[1]]
                    guard let endMark = workingText.indices(of: ">").last else { return tempInput }
                    tempInput = childInput.replacingCharacters(in: workingText.index(after: endMark)..<pair.1, with: sourceText)
                    break
                }
            }

            return tempInput
        }


        let starts = parentInput.indices(of: "<a href=\"")
        let ends = parentInput.indices(of: "</a>")

        if starts.count != ends.count { return parentInput }

        starts.forEach { _ in
            processedContent = subprocess(processedContent)
        }

        return processedContent
    }
    
    static func parse(_ content: String) throws -> (text: String, tags: [Tag]) {
        let scanner = StringScanner(content)
        var tagStacks: [Tag] = [] // temporary stack
        var tagsList: [Tag] = [] // final stack with all found tags
        
        var plainText = String()
        while !scanner.isAtEnd {
            // scan text and accumulate it until we found a special entity (starting with &) or an open tag character (<)
            if let textString = try scanner.scan(upTo: CharacterSet(charactersIn: "<&")) {
                plainText += textString
            } else {
                // We have encountered a special entity or an open/close tag
                if scanner.match("&") == true {
                    // It's a special entity so get it until the end (; character) and replace it with encoded char
                    if let entityValue = try scanner.scan(upTo: ";") {
                        if let spec = htmlEntities[entityValue] {
                            plainText += spec
                        }
                        try scanner.skip()
                    }
                    continue
                } else if scanner.match("<") == true {
                    let rawTag = try scanner.scan(upTo: ">")

                    if var tag = Tag(raw: rawTag) {
                        if tag.name == "p" { // it's a return carriage, we want to translate it directly
                            plainText += "\n"
                            try scanner.skip()
                            continue
                        }
                        let endIndex = plainText.count
                        if tag.isOpenTag == true {
                            // it's an open tag, store the start index
                            // (the upperbund is temporary the same of the lower bound, we will update it
                            // at the end, before adding it to the list of the tags)
                            tag.range = endIndex..<endIndex
                            tagStacks.append(tag)
                        } else {
                            let enumerator = tagStacks.enumerated().reversed()
                            for (index, var currentTag) in enumerator {
                                // Search back to the first opening closure for this tag, update the upper bound
                                // with the end position of the closing tag and put on the list
                                if currentTag.name == tag.name {
                                    currentTag.range = currentTag.range!.lowerBound..<endIndex
                                    tagsList.append(currentTag)
                                    tagStacks.remove(at: index)
                                    break
                                }
                            }
                        }
                    }
                    try scanner.skip()
                }
            }
        }
        return (plainText,tagsList)
    }
    
    public struct Tag {
        /// The name of the tag
        public let name: String
        /// Range of tag
        public var range: Range<Int>?
        /// true if tag represent an open tag
        fileprivate(set) var isOpenTag: Bool
        /// the content of the href attribute (only if the tag name is 'a'
        public var href: String?

        public var parsedLink: String? {
            if name != "a" { return nil }
            guard let output = href else { return nil }
            guard let endIndex = output.indices(of: "\" rel=\"nofollow").first else { return nil }

            return try? parse(String(output[..<endIndex])).0
        }
        
        public init?(raw content: String?) {
            guard let content = content else {
                return nil
            }

            // Read tag name
            let tagScanner = StringScanner(content)
            do {
                self.isOpenTag = (tagScanner.match("/") == false)
                guard let name = try tagScanner.scan(untilIn: CharacterSet.alphanumerics) else {
                    return nil
                }
                self.name = name

                if self.name == "a" {
                    let linkPattern = "href=\\\"(.*)\\\"" // #bestURLRegexEver
                    let linkRegex = try! NSRegularExpression(pattern: linkPattern, options: [])
                    let matches = linkRegex.matches(in: content, options: [], range: NSRange(location: 0, length: content.count))
                    if matches.count > 0 {
                        let linkMatch = matches[0]
                        if linkMatch.numberOfRanges == 2 {
                            let startIndex = String.Index(utf16Offset: linkMatch.range(at: 1).lowerBound, in: content)
                            //String.Index(encodedOffset: linkMatch.range(at: 1).lowerBound)
                            let endIndex = String.Index(utf16Offset: linkMatch.range(at: 1).upperBound, in: content)
                            //String.Index(encodedOffset: linkMatch.range(at: 1).upperBound)
                            self.href = String(content[startIndex..<endIndex])
                        }
                    }
                }
            } catch {
                return nil
            }
        }
    }
}
