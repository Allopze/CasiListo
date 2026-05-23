# 🛒 CasiListo

**CasiListo** es una app iOS nativa de lista de compras, construida con **SwiftUI** y **SwiftData**. Diseñada para ser minimalista, rápida y visualmente cálida, permite organizar productos por categorías predefinidas, marcar lo que ya compraste y buscar en tu lista al instante.

> *"Casi listo para ir al súper."*

---

## ✨ Características principales

| Característica | Descripción |
|---|---|
| **Categorías inteligentes** | 9 categorías predefinidas (Frutas, Lácteos, Carnes, Despensa, Bebidas, Limpieza, Higiene, Congelados, Otros) con íconos SF Symbols |
| **Autocompletado** | Base de datos integrada de ~90 productos frecuentes con sugerencias en tiempo real |
| **Categorización automática** | Al seleccionar un producto sugerido, la categoría se asigna automáticamente |
| **Marcar como comprado** | Checkbox animado con feedback háptico para tachar productos |
| **Búsqueda** | Filtrado en tiempo real por nombre, nota o categoría |
| **Filtro de comprados** | Ocultar/mostrar productos ya comprados |
| **Swipe actions** | Deslizar para eliminar, editar o marcar como comprado |
| **Context menu** | Menú contextual con acciones rápidas en cada producto |
| **Persistencia local** | Datos guardados automáticamente con SwiftData |
| **Modo claro/oscuro** | Paleta adaptativa que sigue la configuración del sistema |
| **Liquid Glass** | Efectos glassmorphism nativos en iOS 26+ con fallback elegante para versiones anteriores |
| **Feedback háptico** | Vibraciones sutiles en cada interacción |
| **Accesibilidad** | Labels, hints y acciones accesibles en todos los elementos interactivos |
| **Filtro por Supermercado** | Asignación de cada producto a un supermercado (Jumbo o Líder) con filtro rápido en la cabecera. |
| **Modo Compra 🛒** | Interfaz de pantalla completa enfocada categoría por categoría con checkboxes gigantes, temporizador y auto-avance. |
| **Recordatorios Geolocalizados 📍** | Alertas cuando pasas cerca de Jumbo o Líder (Los Ángeles, Chile) con el recuento de artículos pendientes en esa tienda. |
| **Notas de Voz por Producto 🎤** | Grabación inline de audios de hasta 30 segundos para añadir indicaciones de marcas o pasillos. |
| **Mis Logros y Rachas 🏆** | Sistema de medallas y racha semanal para incentivar el hábito de compra. |

---

## 🏗️ Arquitectura

El proyecto sigue el patrón **MVVM (Model-View-ViewModel)** con una estructura clara:

```
CasiListo/
├── CasiListoApp.swift          # Punto de entrada (@main)
├── Models/
│   ├── ShoppingItem.swift      # Modelo SwiftData del producto
│   ├── Category.swift          # Enum de categorías con iconos y orden
│   └── SuggestedProducts.swift # Base de datos de productos sugeridos
├── ViewModels/
│   └── ShoppingListViewModel.swift  # Lógica de filtrado, agrupación y acciones
├── Views/
│   ├── ContentView.swift       # Vista principal con NavigationStack
│   ├── AddEditItemSheet.swift  # Modal para crear/editar productos
│   ├── CategorySectionView.swift # Sección agrupada por categoría
│   ├── ItemRowView.swift       # Fila individual de producto
│   ├── EmptyStateView.swift    # Pantalla cuando la lista está vacía
│   ├── PreviewSupport.swift    # Fixtures y previews de Xcode
│   └── Components/
│       └── CategoryPickerView.swift  # Selector visual de categorías (grid de chips)
└── Theme/
    └── Theme.swift             # Sistema de diseño (colores, fuentes, animaciones, glass effects)
```

---

## 🎨 Sistema de diseño

CasiListo utiliza un sistema de diseño centralizado en `Theme.swift`:

- **Color de acento**: Amarillo cálido `#F5C518`
- **Tipografía**: System Rounded en múltiples pesos
- **Animaciones**: Springs con damping personalizado
- **Superficies**: Efectos glass adaptativos (iOS 26 nativo / `ultraThinMaterial` fallback)
- **Colores adaptativos**: Definidos programáticamente con variantes light/dark

---

## 📱 Requisitos

| Requisito | Versión |
|---|---|
| **iOS** | 17.0+ |
| **Xcode** | 16.0+ |
| **Swift** | 5.9+ |

> Los efectos Liquid Glass nativos (`glassEffect`) requieren **iOS 26+**. En versiones anteriores se aplica un fallback visual con `ultraThinMaterial`.

---

## 🚀 Instalación y ejecución

1. **Clona el repositorio**:
   ```bash
   git clone https://github.com/tu-usuario/CasiListo.git
   cd CasiListo
   ```

2. **Abre el proyecto en Xcode**:
   ```bash
   open CasiListo.xcodeproj
   ```
   > Si usas Swift Package Manager o un `.xcworkspace`, ajusta según corresponda.

3. **Selecciona un simulador o dispositivo** con iOS 17+.

4. **Ejecuta** con `⌘R`.

No se requieren dependencias externas — el proyecto utiliza únicamente frameworks nativos de Apple (`SwiftUI`, `SwiftData`, `UIKit`).

---

## 🧩 Modelo de datos

### `ShoppingItem` (SwiftData `@Model`)

| Propiedad | Tipo | Descripción |
|---|---|---|
| `id` | `UUID` | Identificador único |
| `name` | `String` | Nombre del producto |
| `quantity` | `String` | Cantidad libre (ej: "2", "1 kg", "500 g") |
| `categoryRawValue` | `String` | Clave de categoría (persistencia) |
| `note` | `String` | Nota opcional |
| `isPurchased` | `Bool` | Estado comprado/pendiente |
| `sortOrder` | `Int` | Orden dentro de su categoría |
| `createdAt` | `Date` | Fecha de creación |

### `Category` (enum)

9 categorías predefinidas, cada una con:
- Nombre para mostrar (`displayName`)
- Ícono SF Symbol (`sfSymbol`)
- Índice de orden (`sortIndex`)

---

## 🔄 Flujo de la app

```
┌─────────────────────────────────┐
│         CasiListoApp            │
│   SwiftData ModelContainer      │
└──────────────┬──────────────────┘
               │
       ┌───────▼───────┐
       │  ContentView   │  ← NavigationStack + búsqueda + toolbar
       └───────┬───────┘
               │
    ┌──────────┼──────────────┐
    │          │              │
    ▼          ▼              ▼
EmptyState  ShoppingList   AddEditSheet
  View        View           (modal)
               │
        ┌──────┼──────┐
        ▼             ▼
  CategorySection  SummaryBar
     View            View
        │
        ▼
   ItemRowView
```

---

## 📐 Normas del Repositorio / Código

Para mantener la base de código limpia, modular y fácil de mantener:
- **Límite de tamaño de archivo**: Los archivos de código (`.swift`) **no deben superar las 100 líneas** a menos que sea estrictamente necesario. Si un archivo empieza a crecer más allá de este límite, se debe considerar refactorizarlo o dividirlo en componentes o extensiones independientes.

---

## 📄 Licencia

Este proyecto es de uso personal / educativo. Agrega una licencia según tus necesidades.
