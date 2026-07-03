import SwiftUI

extension Color {
    static let receiptPaper = Color(red: 0.973, green: 0.960, blue: 0.937)
}

struct ReceiptPreview: View {
    let richLines: [RichLine]
    let selectedImage: UIImage?
    var font: String = "monospace"

    private let toothHeight: CGFloat = 7

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: toothHeight)

            VStack(alignment: .leading, spacing: 6) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .grayscale(1)
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
                if richLines.contains(where: { $0.spans.contains { !$0.text.isEmpty } }) {
                    RichMessageView(richLines: richLines, font: font)
                }
            }
            .padding(14)

            Color.clear.frame(height: toothHeight)
        }
        .background(Color.receiptPaper)
        .clipShape(ReceiptShape(toothHeight: toothHeight))
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
    }
}

private struct ReceiptShape: Shape {
    var toothHeight: CGFloat = 7
    var teethCount: Int = 22

    func path(in rect: CGRect) -> Path {
        let tw = rect.width / CGFloat(teethCount)
        var p = Path()

        p.move(to: CGPoint(x: 0, y: toothHeight))
        for i in 0..<teethCount {
            p.addLine(to: CGPoint(x: CGFloat(i) * tw + tw / 2, y: 0))
            p.addLine(to: CGPoint(x: CGFloat(i + 1) * tw, y: toothHeight))
        }

        p.addLine(to: CGPoint(x: rect.width, y: rect.height - toothHeight))

        for i in stride(from: teethCount - 1, through: 0, by: -1) {
            p.addLine(to: CGPoint(x: CGFloat(i) * tw + tw / 2, y: rect.height))
            p.addLine(to: CGPoint(x: CGFloat(i) * tw, y: rect.height - toothHeight))
        }

        p.closeSubpath()
        return p
    }
}
