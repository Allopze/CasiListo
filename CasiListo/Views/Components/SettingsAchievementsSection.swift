import SwiftUI

struct SettingsAchievementsSection: View {
    let accessibilityTextSizeScale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MIS LOGROS")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()

            NavigationLink {
                AchievementsView()
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accentYellow)
                        .frame(width: 32, height: 32)
                        .background(Theme.accentYellow.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ver Medallas y Rachas")
                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("Consulta tus estadísticas y logros de compras completadas.")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .buttonStyle(.plain)
            .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
    }
}
