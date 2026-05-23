import SwiftUI

/// Vista que muestra los logros desbloqueados y estadísticas acumuladas del usuario.
struct AchievementsView: View {
    @State private var stats = UserStats.load()
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    
    // Columnas de la cuadrícula de logros
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24 * CGFloat(accessibilityTextSizeScale)) {
                // Tarjeta de Resumen / Stats Principales
                statsSummaryCard
                
                // Sección de Logros
                VStack(alignment: .leading, spacing: 14) {
                    Text("MEDALLAS DE LOGROS")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.leading, 6)
                        .bold()
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Achievement.all) { achievement in
                            let isUnlocked = stats.unlockedAchievements.contains(achievement.id)
                            achievementGridItem(achievement: achievement, isUnlocked: isUnlocked)
                        }
                    }
                }
                .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
            }
            .padding(.vertical, 16)
        }
        .background(Color.appBackground)
        .navigationTitle("Mis Logros")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Recargar estadísticas al abrir
            stats = UserStats.load()
        }
    }
    
    // Tarjeta superior de estadísticas
    private var statsSummaryCard: some View {
        VStack(spacing: 20 * CGFloat(accessibilityTextSizeScale)) {
            // Racha Actual
            VStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 48 * CGFloat(accessibilityTextSizeScale)))
                
                Text("\(stats.currentStreak) Semanas Seguidas")
                    .font(.system(size: 20 * CGFloat(accessibilityTextSizeScale), weight: .black))
                    .foregroundStyle(Theme.accentYellow)
                
                Text("Racha de Compras")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.vertical, 8)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Grid de 2 columnas de números
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(stats.totalPurchases)")
                        .font(.system(size: 24 * CGFloat(accessibilityTextSizeScale), weight: .black).monospacedDigit())
                        .foregroundStyle(.white)
                    
                    Text("Compras Totales")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 4) {
                    Text("\(stats.totalProductsBought)")
                        .font(.system(size: 24 * CGFloat(accessibilityTextSizeScale), weight: .black).monospacedDigit())
                        .foregroundStyle(.white)
                    
                    Text("Productos")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24 * CGFloat(accessibilityTextSizeScale))
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
    }
    
    // Tarjeta individual de logro
    @ViewBuilder
    private func achievementGridItem(achievement: Achievement, isUnlocked: Bool) -> some View {
        VStack(spacing: 12) {
            // Círculo del Emoji
            ZStack {
                Circle()
                    .fill(isUnlocked ? Theme.accentYellow.opacity(0.15) : Color.white.opacity(0.04))
                    .frame(width: 64, height: 64)
                
                Text(achievement.emoji)
                    .font(.system(size: 32))
                    .grayscale(isUnlocked ? 0.0 : 1.0)
                    .opacity(isUnlocked ? 1.0 : 0.4)
            }
            .overlay(alignment: .bottomTrailing) {
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }
            
            Text(achievement.title)
                .font(.system(size: 14 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                .foregroundStyle(isUnlocked ? Color.appTextPrimary : Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            Text(achievement.description)
                .font(.system(size: 11 * CGFloat(accessibilityTextSizeScale)))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(height: 40, alignment: .top)
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isUnlocked ? Theme.accentYellow.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1.5)
        }
        .shadow(color: isUnlocked ? Theme.accentYellow.opacity(0.04) : .clear, radius: 6, y: 3)
    }
}

#if DEBUG
#Preview {
    AchievementsView()
}
#endif
