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

                Menu {
                    ForEach([("monospace", "Monospace"), ("serif", "Serif"), ("sans", "Sans-serif"), ("handwriting", "Handwriting")], id: \.0) { value, label in
                        Button {
                            onSetFont(value)
                        } label: {
                            if currentFont == value {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(width: 48, height: 36)
                    .background(Color(.systemGray5))
                    .foregroundStyle(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
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
