import SwiftUI

struct RichMessageView: View {
    let richLines: [RichLine]
    var compact: Bool = false

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

        (richText(for: line))
            .multilineTextAlignment(textAlign)
            .frame(maxWidth: .infinity, alignment: hAlign == .center ? .center : .leading)
    }

    private func richText(for line: RichLine) -> Text {
        line.spans.reduce(Text("")) { acc, span in
            acc + styledText(span, size: line.size)
        }
    }

    private func styledText(_ span: RichSpan, size: String) -> Text {
        let base: Font
        if compact {
            base = .system(.caption, design: .monospaced)
        } else {
            switch size {
            case "large":  base = .system(.title3, design: .monospaced)
            case "header": base = .system(.title2, design: .monospaced)
            default:       base = .system(.body, design: .monospaced)
            }
        }
        let font = span.bold ? base.bold() : base
        return Text(span.text).font(font)
    }
}
