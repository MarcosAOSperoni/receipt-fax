import SwiftUI
import UIKit

let richSizeKey = NSAttributedString.Key("richSize")

private func fontSizeFor(_ size: String) -> CGFloat {
    switch size {
    case "large":  return 18
    case "header": return 22
    default:       return 14
    }
}

func richLinesToAttrString(_ lines: [RichLine]) -> NSMutableAttributedString {
    let result = NSMutableAttributedString()
    for (i, line) in lines.enumerated() {
        let para = NSMutableParagraphStyle()
        para.alignment = line.align == "center" ? .center : .natural
        for span in line.spans {
            let font = UIFont.monospacedSystemFont(
                ofSize: fontSizeFor(line.size),
                weight: span.bold ? .bold : .regular
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: para,
                richSizeKey: line.size,
            ]
            result.append(NSAttributedString(string: span.text, attributes: attrs))
        }
        if i < lines.count - 1 {
            let newlinePara = NSMutableParagraphStyle()
            newlinePara.alignment = line.align == "center" ? .center : .natural
            let newlineAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeFor(line.size), weight: .regular),
                .paragraphStyle: newlinePara,
                richSizeKey: line.size,
            ]
            result.append(NSAttributedString(string: "\n", attributes: newlineAttrs))
        }
    }
    if result.length == 0 {
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .paragraphStyle: NSMutableParagraphStyle(),
            richSizeKey: "normal",
        ]
        result.append(NSAttributedString(string: "", attributes: defaultAttrs))
    }
    return result
}

func attrStringToRichLines(_ attrStr: NSAttributedString) -> [RichLine] {
    let fullText = attrStr.string
    guard !fullText.isEmpty else {
        return [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "", bold: false)])]
    }

    // Build UTF-16 ranges for each line
    var lineRanges: [NSRange] = []
    var start = 0
    let utf16 = fullText.utf16
    var idx = 0
    for scalar in fullText.unicodeScalars {
        let len = String(scalar).utf16.count
        if scalar == "\n" {
            lineRanges.append(NSRange(location: start, length: idx - start))
            start = idx + len
        }
        idx += len
    }
    lineRanges.append(NSRange(location: start, length: utf16.count - start))

    return lineRanges.map { lineRange in
        var size = "normal"
        var align = "left"

        if lineRange.length > 0 {
            let firstCharRange = NSRange(location: lineRange.location, length: 1)
            attrStr.enumerateAttribute(richSizeKey, in: firstCharRange, options: []) { val, _, _ in
                if let s = val as? String { size = s }
            }
            attrStr.enumerateAttribute(.paragraphStyle, in: firstCharRange, options: []) { val, _, _ in
                if let ps = val as? NSParagraphStyle, ps.alignment == .center { align = "center" }
            }
        }

        guard lineRange.length > 0 else {
            return RichLine(size: size, align: align, spans: [RichSpan(text: "", bold: false)])
        }

        var spans: [RichSpan] = []
        var currentText = ""
        var currentBold = false
        var first = true

        attrStr.enumerateAttribute(.font, in: lineRange, options: []) { val, range, _ in
            let isBold: Bool
            if let font = val as? UIFont {
                isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            } else {
                isBold = false
            }
            let spanText = (attrStr.string as NSString).substring(with: range)
            if first {
                currentText = spanText
                currentBold = isBold
                first = false
            } else if isBold == currentBold {
                currentText += spanText
            } else {
                spans.append(RichSpan(text: currentText, bold: currentBold))
                currentText = spanText
                currentBold = isBold
            }
        }
        if !first { spans.append(RichSpan(text: currentText, bold: currentBold)) }
        if spans.isEmpty { spans = [RichSpan(text: "", bold: false)] }

        return RichLine(size: size, align: align, spans: spans)
    }
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var richLines: [RichLine]
    @Binding var isBoldActive: Bool
    @Binding var currentLineIndex: Int
    var boldTrigger: UUID

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isEditable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.attributedText = richLinesToAttrString(richLines)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        guard !context.coordinator.isUpdatingFromTextView else { return }
        let sel = tv.selectedRange
        let newAttr = richLinesToAttrString(richLines)
        // Only rewrite if content differs (avoids cursor jump on every keystroke)
        if !tv.attributedText.isEqual(to: newAttr) {
            tv.attributedText = newAttr
            let loc = min(sel.location, newAttr.length)
            let len = min(sel.length, newAttr.length - loc)
            tv.selectedRange = NSRange(location: loc, length: len)
        }
        if context.coordinator.lastBoldTrigger != boldTrigger {
            context.coordinator.lastBoldTrigger = boldTrigger
            context.coordinator.toggleBoldOnSelection(in: tv)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(richLines: $richLines, isBoldActive: $isBoldActive, currentLineIndex: $currentLineIndex)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var richLines: [RichLine]
        @Binding var isBoldActive: Bool
        @Binding var currentLineIndex: Int
        var isUpdatingFromTextView = false
        var lastBoldTrigger = UUID()

        init(richLines: Binding<[RichLine]>, isBoldActive: Binding<Bool>, currentLineIndex: Binding<Int>) {
            _richLines = richLines
            _isBoldActive = isBoldActive
            _currentLineIndex = currentLineIndex
        }

        func textViewDidChange(_ tv: UITextView) {
            isUpdatingFromTextView = true
            richLines = attrStringToRichLines(tv.attributedText)
            isUpdatingFromTextView = false
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            let pos = tv.selectedRange.location
            let prefix = (tv.text ?? "") as NSString
            let safeLen = min(pos, prefix.length)
            let linesBefore = prefix.substring(to: safeLen).components(separatedBy: "\n")
            currentLineIndex = max(0, min(linesBefore.count - 1, richLines.count - 1))

            let sel = tv.selectedRange
            if sel.length == 0 {
                if let font = tv.typingAttributes[.font] as? UIFont {
                    isBoldActive = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                } else {
                    isBoldActive = false
                }
            } else {
                var allBold = sel.length > 0
                tv.attributedText.enumerateAttribute(.font, in: sel, options: []) { val, _, stop in
                    if let f = val as? UIFont, !f.fontDescriptor.symbolicTraits.contains(.traitBold) {
                        allBold = false
                        stop.pointee = true
                    }
                }
                isBoldActive = allBold
            }
        }

        func toggleBoldOnSelection(in tv: UITextView) {
            let sel = tv.selectedRange
            let newBold = !isBoldActive

            if sel.length == 0 {
                var attrs = tv.typingAttributes
                let cur = attrs[.font] as? UIFont ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                attrs[.font] = UIFont.monospacedSystemFont(ofSize: cur.pointSize, weight: newBold ? .bold : .regular)
                tv.typingAttributes = attrs
                isBoldActive = newBold
                return
            }

            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            mutable.enumerateAttribute(.font, in: sel, options: []) { val, range, _ in
                let cur = val as? UIFont ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                mutable.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: cur.pointSize, weight: newBold ? .bold : .regular), range: range)
            }
            isUpdatingFromTextView = true
            tv.attributedText = mutable
            tv.selectedRange = sel
            richLines = attrStringToRichLines(tv.attributedText)
            isUpdatingFromTextView = false
            isBoldActive = newBold
        }
    }
}
