import SwiftUI

struct UndoToastView: View {
    let itemName: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(Color.appTextSecondary)

            Text("Eliminado \"\(itemName)\"")
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)

            Spacer()

            Button("Deshacer") {
                onUndo()
            }
            .font(.subheadline.bold())
            .foregroundStyle(Theme.accentInteractive)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.accentYellow.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}
