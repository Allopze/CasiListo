# 🛒 CasiListo

**CasiListo** es una app iOS nativa de lista de compras, construida con **SwiftUI** y **SwiftData**. Diseñada para ser minimalista, rápida y visualmente cálida, permite organizar productos por categorías predefinidas, marcar lo que ya compraste y buscar en tu lista al instante.

> *"Casi listo para ir al súper."*

---

## ✨ Características principales

| Característica | Descripción |
|---|---|
| **Categorías inteligentes** | 15 categorías predefinidas (Frutas y verduras, Lácteos y huevos, Carnes, Despensa, Bebidas, Vinos, Congelados, Conservas, Hogar y limpieza, Aseo personal, Mascotas, Panadería y dulces, Pescados, Condimentos, Varios) con íconos SF Symbols y orden personalizable |
| **Autocompletado** | Base de datos integrada de ~290 productos frecuentes con sugerencias en tiempo real |
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
| **Notas de Voz por Producto 🎤** | Grabación inline de audios de hasta 30 segundos para añadir indicaciones de marcas o pasillos. |

---

## 🏗️ Arquitectura

El proyecto sigue el patrón **MVVM (Model-View-ViewModel)** con una estructura clara:

```
CasiListo/
├── CasiListoApp.swift          # Punto de entrada (@main)
├── Models/
│   ├── ShoppingItem.swift      # Modelo SwiftData del producto
│   ├── Category.swift          # Modelo SwiftData + DefaultCategory enum
│   ├── ShoppingList.swift      # Modelo SwiftData de sesión/historial
│   ├── Store.swift             # Supermercados (Jumbo / Líder)
│   ├── ProductCatalogItem.swift # Productos frecuentes catalogados
│   ├── SuggestedProducts.swift # Base de datos de ~290 sugerencias
├── ViewModels/
│   └── ShoppingListViewModel.swift  # Lógica de filtrado, agrupación y acciones
├── Services/
│   ├── AppSettings.swift             # Estado global observable de ajustes
│   ├── VoiceNoteService.swift        # Grabación y reproducción de audio
│   ├── ShoppingListLifecycleService.swift # Ciclo de vida e historial de listas
│   ├── CategoryBootstrapService.swift # Inicialización de categorías
│   └── WidgetDataBridge.swift        # Sincronización con widget nativo
├── Views/
│   ├── ContentView.swift       # Vista principal con NavigationStack
│   ├── ShoppingListView.swift  # Lista activa agrupada por categoría
│   ├── AddEditItemSheet.swift  # Modal para crear/editar productos
│   └── SettingsSheet.swift     # Hojas de ajustes y accesibilidad
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
| **Xcode** | 26.0+ para archivar y subir a App Store Connect |
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

## 📸 Capturas de pantalla

`ci/capture-screenshots.sh` recorre la app con `ScreenshotCaptureTests` y deja 21 PNG por variante, organizados en `<salida>/<dispositivo>/<apariencia>/<tamaño-texto>/`.

```bash
ci/capture-screenshots.sh                 # iPhone, claro + oscuro (~8 min)
ci/capture-screenshots.sh --full          # + iPad y texto XXL (~30 min)
ci/capture-screenshots.sh --out ~/Desktop/capturas
ci/capture-screenshots.sh --devices "iPad Pro 11-inch (M5)" --appearances dark
```

Cubre el menú general de listas (vacío, con una y con varias), el sheet de personalización con paleta e iconos, el detalle en sus estados de categoría, el cierre con boleta, plantillas, importador, catálogo, historial y ajustes.

Dos detalles a tener en cuenta si se toca este arnés:

- **Las variables de entorno necesitan el prefijo `TEST_RUNNER_`.** `xcodebuild` no propaga variables sueltas al proceso del runner; les quita ese prefijo al reenviarlas. Por eso el script exporta `TEST_RUNNER_SCREENSHOT_DIR` y el test lee `SCREENSHOT_DIR`.
- **La apariencia se fuerza por partida doble.** La app respeta `-ui-testing-light` / `-ui-testing-dark`, pero las hojas modales se presentan fuera de esa jerarquía y siguen al sistema, así que el script además fija la apariencia del simulador con `simctl ui`.

---

## 🧩 Modelo de datos

### `ShoppingItem` (SwiftData `@Model`)

| Propiedad | Tipo | Descripción |
|---|---|---|
| `id` | `UUID` | Identificador único |
| `name` | `String` | Nombre del producto |
| `quantity` | `String` | Cantidad libre (ej: "2", "1 kg", "500 g") |
| `category` | `Category` | Categoría asociada (relación SwiftData) |
| `store` | `Store` | Supermercado preferido (.jumbo / .lider) |
| `note` | `String` | Nota opcional |
| `status` | `ShoppingItemStatus` | Estado (pending, purchased, skipped, unavailable) |
| `price` | `Double?` | Precio estimado opcional |
| `voiceNoteFilename` | `String?` | Archivo de nota de voz asociante |
| `sortOrder` | `Int` | Orden dentro de su categoría |
| `createdAt` | `Date` | Fecha de creación |

### `Category` (SwiftData `@Model`)

15 categorías predefinidas con modelo persistido y soporte para personalización:

- Nombre (`name`)
- Ícono SF Symbol (`sfSymbol`)
- Orden (`sortIndex`)
- Sistema / Personalizada (`isSystem`)

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
