import SwiftUI

struct FormattingToolbar: View {
    @Binding var style: MessageStyle

    var body: some View {
        HStack(spacing: 12) {
            ToggleButton(label: "B", font: .body.bold(), isOn: style.bold) {
                style.bold.toggle()
            }

            Divider().frame(height: 28)

            Picker("Size", selection: $style.size) {
                Text("Normal").tag("normal")
                Text("Large").tag("large")
                Text("Header").tag("header")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            Divider().frame(height: 28)

            ToggleButton(systemImage: "text.alignleft", isOn: style.align == "left") {
                style.align = "left"
            }
            ToggleButton(systemImage: "text.aligncenter", isOn: style.align == "center") {
                style.align = "center"
            }
        }
    }
}

private struct ToggleButton: View {
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
                    Image(systemName: systemImage)
                }
            }
            .frame(width: 32, height: 32)
            .background(isOn ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
