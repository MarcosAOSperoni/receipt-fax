import SwiftUI

struct ReceiptPreview: View {
    let richLines: [RichLine]
    let selectedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            if richLines.contains(where: { $0.spans.contains { !$0.text.isEmpty } }) {
                RichMessageView(richLines: richLines)
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
