import SwiftUI

/// Vista de celebración cuando el usuario completa la lista de compras del supermercado.
struct CompletionCelebrationView: View {
    let storeName: String
    let productsCount: Int
    let totalSpent: Double
    let onDismiss: () -> Void
    let onClearPurchasedAndDismiss: () -> Void
    
    @State private var confettiOffset: CGFloat = -100
    @State private var animateStats: Bool = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .body) private var scaledVStackSpacing: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var circleSizeSmall: CGFloat = 130
    @ScaledMetric(relativeTo: .body) private var circleSizeLarge: CGFloat = 150
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 70
    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var buttonsSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var buttonPaddingVertical: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    
    var body: some View {
        ZStack {
            // Fondo oscuro premium con gradiente
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.1, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if !reduceMotion {
                ForEach(confettiParticles) { particle in
                    ConfettiView(particle: particle)
                }
            }
            
            VStack(spacing: scaledVStackSpacing) {
                Spacer()
                
                // Emoji / Ícono animado
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: circleSizeSmall, height: circleSizeSmall)
                        .scaleEffect(animateStats ? 1.0 : 0.8)
                    
                    Circle()
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: circleSizeLarge, height: circleSizeLarge)
                        .scaleEffect(animateStats ? 1.0 : 0.7)
                    
                    Text("🎉")
                        .font(.system(size: emojiSize))
                        .rotationEffect(.degrees(animateStats ? 0 : -35))
                }
                .animation(motionAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)), value: animateStats)
                
                VStack(spacing: 8) {
                    Text("¡Compra Completada!")
                        .font(Theme.titleFont(scale: accessibilityTextSizeScale).weight(.black))
                        .foregroundStyle(.white)
                    
                    Text("Todo listo en \(storeName)")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.green)
                }
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 20)
                .animation(motionAnimation(.easeOut(duration: 0.5).delay(0.4)), value: animateStats)
                
                // Tarjeta de estadísticas con Glassmorphic style
                VStack(spacing: cardSpacing) {
                    statRow(title: "Productos Comprados", value: "\(productsCount)", icon: "cart.fill", color: .green)
                    
                    if totalSpent > 0 {
                        Divider().background(Color.white.opacity(0.1))
                        statRow(title: "Gasto Estimado", value: totalSpent.formattedPriceWithSymbol, icon: "dollarsign.circle.fill", color: .yellow)
                    }
                }
                .padding(cardPadding)
                .background {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 30)
                .animation(motionAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.6)), value: animateStats)
                
                Spacer()
                
                // Botones
                VStack(spacing: buttonsSpacing) {
                    // Botón Compartir Resumen
                    ShareLink(item: shareSummaryText) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Text("Compartir Resumen")
                                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, buttonPaddingVertical)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        HapticFeedback.impact()
                        onClearPurchasedAndDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.bin.fill")
                                .fontWeight(.semibold)
                            Text("Archivar comprados")
                                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, buttonPaddingVertical)
                        .background(Theme.accentYellow)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Elimina los productos comprados de esta compra y vuelve a la lista")
                    
                    // Botón Volver
                    Button {
                        HapticFeedback.selection()
                        onDismiss()
                    } label: {
                        Text("Volver a la Lista")
                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, buttonPaddingVertical)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 40)
                .animation(motionAnimation(.easeOut(duration: 0.5).delay(0.8)), value: animateStats)
            }
        }
        .onAppear {
            if !reduceMotion {
                generateConfetti()
            }
            
            // Triple haptic feedback secuencial
            triggerTripleHaptic()
            
            animateStats = true
        }
    }
    
    private func statRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(color)
                .frame(width: iconSize + 12, height: iconSize + 12)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            Text(title)
                .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(.white)
        }
    }
    
    private var shareSummaryText: String {
        var text = "🏆 *¡Compra terminada en CasiListo!*\n\n"
        text += "🏪 Supermercado: *\(storeName)*\n"
        text += "📦 Productos: *\(productsCount)*\n"
        if totalSpent > 0 {
            text += "💰 Total Estimado: *\(totalSpent.formattedPriceWithSymbol)*\n"
        }
        return text
    }
    
    private func generateConfetti() {
        var particles: [ConfettiParticle] = []
        let colors: [Color] = [.red, .blue, .green, .yellow, .pink, .purple, .orange]
        
        for _ in 0..<70 {
            let x = CGFloat.random(in: 0...400)
            let y = CGFloat.random(in: -100...0)
            let size = CGFloat.random(in: 6...12)
            let color = colors.randomElement() ?? .yellow
            let rotation = Double.random(in: 0...360)
            let speed = Double.random(in: 2.0...5.0)
            
            particles.append(ConfettiParticle(x: x, y: y, size: size, color: color, rotation: rotation, speed: speed))
        }
        
        self.confettiParticles = particles
    }
    
    private func triggerTripleHaptic() {
        HapticFeedback.success()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            HapticFeedback.impact()
            try? await Task.sleep(for: .milliseconds(250))
            HapticFeedback.success()
        }
    }

    private func motionAnimation(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Double
    var speed: Double
}

struct ConfettiView: View {
    let particle: ConfettiParticle
    @State private var offset: CGFloat = -100
    @State private var rotation: Double = 0
    @State private var horizontalDrift: CGFloat = 0
    
    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .offset(x: particle.x + horizontalDrift, y: offset)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                offset = particle.y
                rotation = particle.rotation
                
                withAnimation(Animation.linear(duration: particle.speed).repeatForever(autoreverses: false)) {
                    offset = 900
                }
                
                withAnimation(Animation.linear(duration: particle.speed * 0.8).repeatForever(autoreverses: false)) {
                    rotation = particle.rotation + 360
                }
                
                withAnimation(Animation.easeInOut(duration: particle.speed / 2).repeatForever(autoreverses: true)) {
                    horizontalDrift = CGFloat.random(in: -30...30)
                }
            }
    }
}
