import SwiftUI

/// Vista de celebración cuando el usuario completa la lista de compras del supermercado.
struct CompletionCelebrationView: View {
    let storeName: String
    let productsCount: Int
    let duration: String
    let totalSpent: Double
    let onDismiss: () -> Void
    
    @State private var confettiOffset: CGFloat = -100
    @State private var animateStats: Bool = false
    @State private var confettiParticles: [ConfettiParticle] = []
    
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
            
            // Confeti animado
            ForEach(confettiParticles) { particle in
                ConfettiView(particle: particle)
            }
            
            VStack(spacing: 24 * CGFloat(accessibilityTextSizeScale)) {
                Spacer()
                
                // Emoji / Ícono animado
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 130 * CGFloat(accessibilityTextSizeScale), height: 130 * CGFloat(accessibilityTextSizeScale))
                        .scaleEffect(animateStats ? 1.0 : 0.8)
                    
                    Circle()
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 150 * CGFloat(accessibilityTextSizeScale), height: 150 * CGFloat(accessibilityTextSizeScale))
                        .scaleEffect(animateStats ? 1.0 : 0.7)
                    
                    Text("🎉")
                        .font(.system(size: 70 * CGFloat(accessibilityTextSizeScale)))
                        .rotationEffect(.degrees(animateStats ? 0 : -35))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: animateStats)
                
                VStack(spacing: 8) {
                    Text("¡Compra Completada!")
                        .font(.system(size: 32 * CGFloat(accessibilityTextSizeScale), weight: .black))
                        .foregroundStyle(.white)
                    
                    Text("Todo listo en \(storeName)")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.green)
                }
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateStats)
                
                // Tarjeta de estadísticas con Glassmorphic style
                VStack(spacing: 16 * CGFloat(accessibilityTextSizeScale)) {
                    statRow(title: "Productos Comprados", value: "\(productsCount)", icon: "cart.fill", color: .green)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    statRow(title: "Tiempo Transcurrido", value: duration, icon: "clock.fill", color: .blue)
                    
                    if totalSpent > 0 {
                        Divider().background(Color.white.opacity(0.1))
                        statRow(title: "Gasto Estimado", value: totalSpent.formattedPriceWithSymbol, icon: "dollarsign.circle.fill", color: .yellow)
                    }
                }
                .padding(24 * CGFloat(accessibilityTextSizeScale))
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 30)
                .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.6), value: animateStats)
                
                Spacer()
                
                // Botones
                VStack(spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
                    // Botón Compartir Resumen
                    ShareLink(item: shareSummaryText) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Text("Compartir Resumen")
                                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16 * CGFloat(accessibilityTextSizeScale))
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    // Botón Volver
                    Button {
                        HapticFeedback.selection()
                        onDismiss()
                    } label: {
                        Text("Volver a la Lista")
                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16 * CGFloat(accessibilityTextSizeScale))
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 40)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: animateStats)
            }
        }
        .onAppear {
            generateConfetti()
            
            // Triple haptic feedback secuencial
            triggerTripleHaptic()
            
            animateStats = true
        }
    }
    
    private func statRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
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
        text += "⏱️ Tiempo: *\(duration)*\n"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            HapticFeedback.impact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticFeedback.success()
        }
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
