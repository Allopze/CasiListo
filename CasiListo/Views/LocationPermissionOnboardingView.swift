import SwiftUI

struct LocationPermissionOnboardingView: View {
    let onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsGranted = false
    @State private var isRequestingNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Recordatorios cerca del supermercado", systemImage: "location.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text("CasiListo activa los permisos por pasos: primero notificaciones, luego ubicacion en uso y solo despues ubicacion siempre para avisos en segundo plano.")
                        .font(.body)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    permissionStep(
                        number: "1",
                        title: "Notificaciones",
                        description: "Permiten mostrar el aviso cuando hay pendientes cerca de Jumbo o Lider.",
                        isDone: notificationsGranted
                    )

                    permissionStep(
                        number: "2",
                        title: "Ubicacion al usar",
                        description: "Permite validar que el flujo de ubicacion tiene sentido antes de pedir permisos mas amplios.",
                        isDone: false
                    )

                    permissionStep(
                        number: "3",
                        title: "Ubicacion siempre",
                        description: "Solo se solicita al confirmar que quieres recordatorios en segundo plano.",
                        isDone: false
                    )

                    VStack(spacing: 12) {
                        Button {
                            requestNotifications()
                        } label: {
                            Label(
                                notificationsGranted ? "Notificaciones listas" : "Permitir notificaciones",
                                systemImage: notificationsGranted ? "checkmark.circle.fill" : "bell.badge"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accentYellow)
                        .foregroundStyle(.black)
                        .disabled(isRequestingNotifications || notificationsGranted)

                        Button {
                            GeofenceService.shared.requestWhenInUsePermission()
                            GeofenceService.shared.requestAlwaysPermissionForBackgroundReminders()
                            onFinished()
                            dismiss()
                        } label: {
                            Label("Activar recordatorios", systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Color.appBackground)
            .navigationTitle("Permisos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func permissionStep(number: String, title: String, description: String, isDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(isDone ? "✓" : number)
                .font(.headline)
                .foregroundStyle(isDone ? Color.green : Color.appTextPrimary)
                .frame(width: 32, height: 32)
                .background(Color.appCardBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func requestNotifications() {
        isRequestingNotifications = true
        Task { @MainActor in
            notificationsGranted = await GeofenceService.shared.requestNotificationPermission()
            isRequestingNotifications = false
        }
    }
}

