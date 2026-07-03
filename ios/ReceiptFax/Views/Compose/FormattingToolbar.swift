import SwiftUI

struct FormattingToolbar: View {
    let isBoldActive: Bool
    let currentSize: String
    let currentAlign: String
    let currentFont: String
    let onToggleBold: () -> Void
    let onSetSize: (String) -> Void
    let onSetAlign: (String) -> Void
    let onSetFont: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                FormatButton(label: "B", font: .body.bold(), isOn: isBoldActive, action: onToggleBold)

                Divider().frame(height: 22)

                FormatButton(label: "a", font: .footnote.weight(.medium), isOn: currentSize == "normal") { onSetSize("normal") }
                FormatButton(label: "A", font: .callout.weight(.medium), isOn: currentSize == "large") { onSetSize("large") }
                FormatButton(label: "A", font: .title3.bold(), isOn: currentSize == "header") { onSetSize("header") }

                Divider().frame(height: 22)

                FormatButton(systemImage: "text.alignleft", isOn: currentAlign == "left") { onSetAlign("left") }
                FormatButton(systemImage: "text.aligncenter", isOn: currentAlign == "center") { onSetAlign("center") }

                Divider().frame(height: 22)

                FormatButton(label: "Mn", font: .system(size: 11, weight: .semibold, design: .monospaced), isOn: currentFont == "monospace") { onSetFont("monospace") }
                FormatButton(label: "Sr", font: .system(size: 11, weight: .semibold, design: .serif), isOn: currentFont == "serif") { onSetFont("serif") }
                FormatButton(label: "Sa", font: .system(size: 11, weight: .semibold), isOn: currentFont == "sans") { onSetFont("sans") }
                FormatButton(systemImage: "f.cursive", isOn: currentFont == "handwriting") { onSetFont("handwriting") }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
        }
    }
}

private struct FormatButton: View {
    var label: String?
    var systemImage: String?
    var font: Font = .body
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let label {
                    Text(label).font(font)
                } else if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 15, weight: .regular))
                }
            }
            .frame(width: 36, height: 36)
            .background(isOn ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
