import SwiftUI

struct RichMessageView: View {
    let richLines: [RichLine]
    var compact: Bool = false
    var font: String = "monospace"

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 2) {
            ForEach(Array(richLines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(_ line: RichLine) -> some View {
        let hAlign: HorizontalAlignment = line.align == "center" ? .center : .leading
        let textAlign: TextAlignment = line.align == "center" ? .center : .leading

        richText(for: line)
            .multilineTextAlignment(textAlign)
            .frame(maxWidth: .infinity, alignment: hAlign == .center ? .center : .leading)
    }

    private func richText(for line: RichLine) -> Text {
        line.spans.reduce(Text("")) { acc, span in
            acc + styledText(span, size: line.size)
        }
    }

    private func styledText(_ span: RichSpan, size: String) -> Text {
        let swiftFont: Font
        if font == "handwriting" {
            let pointSize: CGFloat = compact ? 12 : (size == "header" ? 22 : size == "large" ? 19 : 16)
            let name = span.bold ? "SnellRoundhand-Bold" : "SnellRoundhand"
            swiftFont = Font.custom(name, size: pointSize)
        } else {
            let design: Font.Design = font == "serif" ? .serif : font == "sans" ? .default : .monospaced
            let style: Font.TextStyle = compact ? .caption : (size == "header" ? .title2 : size == "large" ? .title3 : .body)
            let base = Font.system(style, design: design)
            swiftFont = span.bold ? base.bold() : base
        }
        return Text(span.text).font(swiftFont)
    }
}
