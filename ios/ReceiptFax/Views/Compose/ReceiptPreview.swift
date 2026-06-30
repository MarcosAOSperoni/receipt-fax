import SwiftUI

struct ReceiptPreview: View {
    let lines: [String]
    let style: MessageStyle
    let selectedImage: UIImage?

    private var previewFont: Font {
        let base: Font
        switch style.size {
        case "large":  base = .system(.title3, design: .monospaced)
        case "header": base = .system(.title2, design: .monospaced)
        default:       base = .system(.body, design: .monospaced)
        }
        return style.bold ? base.bold() : base
    }

    private var hAlignment: HorizontalAlignment { style.align == "center" ? .center : .leading }
    private var textAlignment: TextAlignment { style.align == "center" ? .center : .leading }

    var body: some View {
        VStack(alignment: hAlignment, spacing: 4) {
            Text(String(repeating: "─", count: 32))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .grayscale(1)
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }

            if lines.contains(where: { !$0.isEmpty }) {
                VStack(alignment: hAlignment, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(previewFont)
                            .multilineTextAlignment(textAlignment)
                            .frame(maxWidth: .infinity, alignment: hAlignment == .center ? .center : .leading)
                    }
                }
            }

            Text(String(repeating: "─", count: 32))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}
