import SwiftUI

/// Componente visual que muestra la barra de progreso del presupuesto actual.
struct BudgetMeterView: View {
    let currentTotal: Double
    let selectedStore: Store?
    
    // Configuración desde UserDefaults
    @AppStorage(BudgetConfig.isEnabledKey) private var isBudgetEnabled = true
    @AppStorage(BudgetConfig.totalKey) private var totalBudget = BudgetConfig.defaultTotal
    @AppStorage(BudgetConfig.jumboKey) private var jumboBudget = BudgetConfig.defaultJumbo
    @AppStorage(BudgetConfig.liderKey) private var liderBudget = BudgetConfig.defaultLider
    @AppStorage(BudgetConfig.warningThresholdKey) private var warningThreshold = BudgetConfig.defaultWarningThreshold
    
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    
    @State private var hasTriggeredWarningHaptic = false
    
    private var activeBudget: Double {
        switch selectedStore {
        case .jumbo: return jumboBudget
        case .lider: return liderBudget
        case nil: return totalBudget
        }
    }
    
    private var budgetPercentage: Double {
        guard activeBudget > 0 else { return 0 }
        return currentTotal / activeBudget
    }
    
    private var isOverWarningThreshold: Bool {
        budgetPercentage >= warningThreshold
    }
    
    private var isOverBudget: Bool {
        budgetPercentage >= 1.0
    }
    
    private var progressColor: Color {
        if isOverBudget {
            return .red
        } else if isOverWarningThreshold {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        guard isBudgetEnabled && activeBudget > 0 && currentTotal > 0 else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 8 * CGFloat(accessibilityTextSizeScale)) {
                HStack {
                    // Título e indicador de tienda
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(progressColor)
                        Text(selectedStore == nil ? "Presupuesto Total" : "Presupuesto \(selectedStore!.displayName)")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .bold()
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    // Gastado / Presupuesto
                    Text("\(currentTotal.formattedCLP) de \(activeBudget.formattedCLP)")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextPrimary)
                }
                
                // Barra de progreso
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [progressColor.opacity(0.8), progressColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * budgetPercentage)))
                    }
                }
                .frame(height: 8)
                
                // Mensajes de Alerta
                if isOverBudget {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("Has superado el presupuesto por \((currentTotal - activeBudget).formattedCLP)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .scale))
                } else if isOverWarningThreshold {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("Cerca del límite (has usado el \(Int(budgetPercentage * 100))%)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 16 * CGFloat(accessibilityTextSizeScale))
            .padding(.vertical, 12 * CGFloat(accessibilityTextSizeScale))
            .glassFilterSurface(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale))
            .onChange(of: isOverWarningThreshold) { _, newValue in
                if newValue && !hasTriggeredWarningHaptic {
                    HapticFeedback.impact()
                    hasTriggeredWarningHaptic = true
                } else if !newValue {
                    hasTriggeredWarningHaptic = false
                }
            }
        )
    }
}
