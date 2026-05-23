import Foundation

/// Modelo para persistir y calcular las estadísticas de uso de la app y gamificación.
struct UserStats: Codable {
    var totalPurchases: Int = 0
    var totalProductsBought: Int = 0
    var currentStreak: Int = 0
    var lastPurchaseDate: Date? = nil
    var unlockedAchievements: Set<String> = []
    
    /// Carga las estadísticas desde UserDefaults.
    static func load() -> UserStats {
        guard let data = UserDefaults.standard.data(forKey: "user_stats"),
              let stats = try? JSONDecoder().decode(UserStats.self, from: data) else {
            return UserStats()
        }
        return stats
    }
    
    /// Guarda las estadísticas en UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "user_stats")
        }
    }
    
    /// Registra una compra completada y calcula la racha de semanas consecutivas.
    mutating func recordPurchase(productsCount: Int) {
        totalPurchases += 1
        totalProductsBought += productsCount
        
        let now = Date()
        if let lastDate = lastPurchaseDate {
            let calendar = Calendar.current
            let lastWeek = calendar.component(.weekOfYear, from: lastDate)
            let currentWeek = calendar.component(.weekOfYear, from: now)
            let lastYear = calendar.component(.yearForWeekOfYear, from: lastDate)
            let currentYear = calendar.component(.yearForWeekOfYear, from: now)
            
            if currentYear == lastYear {
                if currentWeek == lastWeek {
                    // Ya compró esta semana, la racha se mantiene
                } else if currentWeek == lastWeek + 1 {
                    // Semana consecutiva, incrementar racha
                    currentStreak += 1
                } else {
                    // Rompió racha, restablecer a 1
                    currentStreak = 1
                }
            } else {
                // Cambio de año, verificar si es semana consecutiva
                let diff = calendar.dateComponents([.weekOfYear], from: lastDate, to: now).weekOfYear ?? 0
                if diff == 1 {
                    currentStreak += 1
                } else if diff > 1 {
                    currentStreak = 1
                }
            }
        } else {
            currentStreak = 1
        }
        
        lastPurchaseDate = now
        checkAchievements()
        save()
    }
    
    /// Re-evalúa los logros y desbloquea los que cumplan la condición.
    mutating func checkAchievements() {
        if totalPurchases >= 1 {
            unlockedAchievements.insert("primera_compra")
        }
        if totalPurchases >= 5 {
            unlockedAchievements.insert("cliente_estrella")
        }
        if totalPurchases >= 15 {
            unlockedAchievements.insert("gran_comprador")
        }
        if totalProductsBought >= 50 {
            unlockedAchievements.insert("casilisto_bronce")
        }
        if totalProductsBought >= 200 {
            unlockedAchievements.insert("casilisto_oro")
        }

        if currentStreak >= 2 {
            unlockedAchievements.insert("racha_activa")
        }
        if currentStreak >= 5 {
            unlockedAchievements.insert("super_racha")
        }
    }
}

/// Definición de logro.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    
    static let all: [Achievement] = [
        Achievement(id: "primera_compra", title: "Primera de Muchas", description: "Completa tu primera lista de compras.", emoji: "🎉"),
        Achievement(id: "cliente_estrella", title: "Cliente Estrella", description: "Completa 5 compras en total.", emoji: "⭐"),
        Achievement(id: "gran_comprador", title: "El Gran Comprador", description: "Completa 15 compras en total.", emoji: "👑"),
        Achievement(id: "casilisto_bronce", title: "CasiListo de Bronce", description: "Compra un total de 50 productos.", emoji: "🥉"),
        Achievement(id: "casilisto_oro", title: "CasiListo de Oro", description: "Compra un total de 200 productos.", emoji: "🥇"),

        Achievement(id: "racha_activa", title: "Racha Activa", description: "Mantén una racha de compras de 2 semanas.", emoji: "🔥"),
        Achievement(id: "super_racha", title: "Super Racha", description: "Mantén una racha de compras de 5 semanas.", emoji: "⚡")
    ]
}
