import SwiftUI

struct SettingsCategoriesSection: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CATEGORÍAS")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()

            NavigationLink {
                CategoryManagementView()
            } label: {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accentYellow)
                        .frame(width: 32, height: 32)
                        .background(Theme.accentYellow.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Administrar Categorías")
                            .font(Theme.bodyBoldDynamic)
                            .foregroundStyle(Color.appTextPrimary)
                        Text("Crea, edita, ordena o elimina las categorías de tus productos.")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .buttonStyle(.plain)
            .padding(Theme.cardPadding)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, Theme.cardPadding)
    }
}
