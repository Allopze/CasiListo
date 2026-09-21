# 🛒 CasiListo

**CasiListo** es una app iOS nativa de lista de compras, construida con **SwiftUI** y **SwiftData**. Diseñada para ser minimalista, rápida y visualmente cálida, permite organizar productos por categorías predefinidas, marcar lo que ya compraste y buscar en tu lista al instante.

> *"Casi listo para ir al súper."*

---

## ✨ Características principales

| Característica | Descripción |
|---|---|
| **Categorías inteligentes** | 15 categorías predefinidas (Frutas y verduras, Lácteos y huevos, Carnes, Despensa, Bebidas, Vinos, Congelados, Conservas, Hogar y limpieza, Aseo personal, Mascotas, Panadería y dulces, Pescados, Condimentos, Varios) con íconos SF Symbols y orden personalizable |
| **Autocompletado** | Base de datos integrada de 355 productos frecuentes con sugerencias en tiempo real |
| **Categorización automática** | Al seleccionar un producto sugerido, la categoría se asigna automáticamente |
| **Marcar como comprado** | Checkbox animado con feedback háptico para tachar productos |
| **Búsqueda** | Filtrado en tiempo real por nombre, nota o categoría |
| **Filtro de comprados** | Ocultar/mostrar productos ya comprados |
| **Swipe actions** | Deslizar para eliminar, editar o marcar como comprado |
| **Context menu** | Menú contextual con acciones rápidas en cada producto |
| **Persistencia local** | Datos guardados automáticamente con SwiftData |
| **Modo claro/oscuro** | Paleta adaptativa que sigue la configuración del sistema |
| **Liquid Glass** | Efectos glassmorphism nativos de iOS 26 en toda la interfaz |
| **Feedback háptico** | Vibraciones sutiles en cada interacción |
| **Accesibilidad** | Labels, hints y acciones accesibles en todos los elementos interactivos |
| **Filtro por Supermercado** | Asignación de cada producto a un supermercado (Jumbo o Líder) con filtro rápido en la cabecera. |
| **Notas de Voz por Producto 🎤** | Grabación inline de audios de hasta 30 segundos para añadir indicaciones de marcas o pasillos. |
| **OCR de boletas 🧾** | Escaneo de boletas de Jumbo y Líder con VisionKit + Vision: reconoce productos, cantidades y precios, los concilia con el total impreso y los registra en el historial. |
| **Múltiples listas** | Varias listas activas en paralelo, cada una con su paleta, ícono y supermercado. |
| **Catálogo** | Pestaña dedicada con los productos frecuentes agrupados por categoría, para añadir en lote. |
| **Plantillas** | Listas prearmadas que se materializan en una lista nueva. |
| **Importador de texto** | Pegar un texto suelto y convertirlo en ítems, con detección de cantidad y categoría. |
| **Historial y export CSV** | Las listas archivadas quedan en Historial, con detalle de gasto y exportación a CSV. |
| **Widget de WidgetKit** | Widget de pantalla de inicio con pendientes, comprados y los primeros 5 productos. |
| **Deep link** | Esquema `casilisto://` para abrir directo la pestaña de compra. |

---

## 🏗️ Arquitectura

El proyecto sigue el patrón **MVVM (Model-View-ViewModel)** con una estructura clara:

```
CasiListo/
├── CasiListoApp.swift              # @main; monta el ModelContainer
├── Models/
│   ├── ShoppingItem.swift          # @Model producto (+ formateo de precios)
│   ├── Category.swift              # @Model categoría (name es @Attribute(.unique))
│   ├── ShoppingList.swift          # @Model lista/sesión + ShoppingListStatus
│   ├── ProductCatalogItem.swift    # @Model producto catalogado
│   ├── Store.swift                 # Jumbo / Líder
│   ├── SuggestedProducts.swift     # Semilla del catálogo
│   ├── ListAppearanceCatalog.swift # Paletas e íconos por lista
│   ├── AppDateFormatting.swift
│   └── CasiListoSchemaMigration.swift
├── ViewModels/
│   └── ShoppingListViewModel.swift # Único ViewModel (@Observable)
├── Services/
│   ├── ShoppingPersistenceCoordinator.swift # Punto transaccional de escritura
│   ├── ShoppingListLifecycleService.swift   # Ciclo de vida e historial
│   ├── CategoryBootstrapService.swift       # Inicialización de categorías
│   ├── CatalogService.swift
│   ├── ReceiptServices.swift                # OCR: reconocimiento + matcher + registro
│   ├── ReceiptLineParser.swift              # Gramática de montos CLP
│   ├── ReceiptTextLine.swift                # Ensamblado de filas
│   ├── ProductNameNormalizer.swift          # Normalización + DuplicatePolicy
│   ├── VoiceNoteService.swift               # Grabación y reproducción
│   ├── LocalFileStore.swift                 # Blobs en disco
│   ├── WidgetDataBridge.swift               # Snapshot JSON al App Group
│   ├── CSVSerializer.swift
│   ├── AppRoute.swift                       # Deep link casilisto://
│   └── CategoryIconMapper.swift
├── Views/
│   ├── MainTabView.swift           # Raíz real: 4 pestañas
│   ├── ContentView.swift           # Pestaña Compra + bootstrap de datos
│   ├── ListsOverviewView.swift     # Menú general de listas
│   ├── ShoppingListDetailView.swift
│   ├── ShoppingListView.swift
│   ├── CategorySectionView.swift
│   ├── ItemRowView.swift
│   ├── CatalogView.swift
│   ├── ShoppingHistoryView.swift / ShoppingHistoryDetailView.swift
│   ├── SettingsView.swift / CategoryManagementView.swift
│   ├── AddEditItemSheet.swift / AddEditListSheet.swift / AddEditCategorySheet.swift
│   ├── ReceiptCaptureSheet.swift / TemplatesSheet.swift / TextImporterSheet.swift
│   ├── PreviewSupport.swift        # Todos los #Preview viven aquí
│   └── Components/                 # ~18 componentes reutilizables
├── Theme/
│   └── Theme.swift                 # Sistema de diseño
└── CasiListoWidget/                # Target aparte; no comparte fuentes con la app
```

---

## 🎨 Sistema de diseño

CasiListo utiliza un sistema de diseño centralizado en `Theme.swift`:

- **Color de acento**: Amarillo cálido `#F5C518`
- **Tipografía**: System Rounded en múltiples pesos
- **Animaciones**: Springs con damping personalizado
- **Superficies**: `glassEffect` nativo de iOS 26
- **Colores adaptativos**: Definidos programáticamente con variantes light/dark

---

## 📱 Requisitos

| Requisito | Versión |
|---|---|
| **iOS** | 26.0+ (solo iPhone) |
| **Xcode** | 26.0+ para archivar y subir a App Store Connect |
| **Swift** | 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`) |

> El piso es **iOS 26.0**: la capa de compatibilidad con versiones anteriores se eliminó porque nunca llegó a ejecutarse en ninguna de ellas, y mantenerla sin verificar era peor que no tenerla. iPad queda fuera de 1.0.

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

3. **Selecciona un simulador o dispositivo** iPhone con iOS 26+.

4. **Ejecuta** con `⌘R`.

No se requieren dependencias externas — el proyecto utiliza únicamente frameworks nativos de Apple (`SwiftUI`, `SwiftData`, `UIKit`).

---

## 📸 Capturas de pantalla

`ci/capture-screenshots.sh` recorre la app con `ScreenshotCaptureTests`, conserva los `.xcresult` y exporta 23 PNG adjuntos por XCTest a `<salida>/<dispositivo>/<apariencia>/<tamaño-texto>/`. La corrida falla si XCTest no produce ninguna imagen.

```bash
ci/capture-screenshots.sh                 # iPhone, claro + oscuro (~8 min)
ci/capture-screenshots.sh --full          # + Pro Max y texto XXL (~30 min)
ci/capture-screenshots.sh --out ~/Desktop/capturas
ci/capture-screenshots.sh --os 26.0       # verificar el piso declarado
# Diagnóstico opcional, fuera del gate de release: contenido full-length con ImageRenderer
ci/capture-full-screenshots.sh
```

Cubre el menú general de listas (vacío, con una y con varias), el sheet de personalización con paleta e iconos, el detalle en sus estados de categoría, el cierre con boleta, plantillas, importador, catálogo, historial y ajustes.

Dos detalles a tener en cuenta si se toca este arnés:

- **Las variables de entorno necesitan el prefijo `TEST_RUNNER_`.** `xcodebuild` reenvía `TEST_RUNNER_SCREENSHOT_APPEARANCE` y `TEST_RUNNER_SCREENSHOT_TEXT_SIZE` al runner quitando ese prefijo. Las imágenes se guardan como adjuntos del `.xcresult`, no en una ruta del host desde el runner.
- **La apariencia se fuerza por partida doble.** La app respeta `-ui-testing-light` / `-ui-testing-dark`, pero las hojas modales se presentan fuera de esa jerarquía y siguen al sistema, así que el script además fija la apariencia del simulador con `simctl ui`.
- El diagnóstico `ci/capture-full-screenshots.sh` pertenece al target de tests y no se ejecuta en CI; sus fixtures declaran explícitamente su alcance y verifican que claro/oscuro produzcan PNGs distintos.

---

## 🧩 Modelo de datos

### `ShoppingItem` (SwiftData `@Model`)

| Propiedad | Tipo | Descripción |
|---|---|---|
| `id` | `UUID` | Identificador único |
| `name` | `String` | Nombre del producto |
| `quantity` | `String` | Cantidad libre (ej: "2", "1 kg", "500 g") |
| `category` | `Category` | Computada. Persiste doble: relación `categoryRelation` + sombra `categoryRawValue` |
| `store` | `Store` | Supermercado preferido (.jumbo / .lider) |
| `note` | `String` | Nota opcional |
| `status` | `ShoppingItemStatus` | Computada sobre `statusRawValue`, con fallback al viejo `isPurchased` |
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
CasiListoApp  (@main — monta el ModelContainer)
        │
        ▼
   MainTabView  ← raíz real: 4 pestañas
        │
 ┌──────┴───────┬───────────┬──────────┐
 ▼              ▼           ▼          ▼
Compra       Catálogo   Historial   Ajustes
 │            │           │
 ▼            ▼           ▼
ContentView  CatalogView  ShoppingHistoryView
 │  (bootstrap de datos en su .task)      │
 ▼                                        ▼
ListsOverviewView            ShoppingHistoryDetailView
 │  navigationDestination(for: UUID.self)
 ▼
ShoppingListDetailView
 │
 ▼
ShoppingListView ──► CategorySectionView ──► ItemRowView
        └──► SummaryBarView / BottomAddBarView

Sheets modales: AddEditItemSheet · AddEditListSheet · AddEditCategorySheet
                ReceiptCaptureSheet · TemplatesSheet · TextImporterSheet
```

---

## 📐 Normas del Repositorio / Código

Para mantener la base de código limpia, modular y fácil de mantener:

- **Límite de tamaño de archivo (aspiracional)**: la intención es que los `.swift` no superen las **100 líneas** y que al crecer se extraigan componentes o extensiones.

  > ⚠️ **Hoy no se cumple y el límite de tamaño sigue siendo aspiracional.** El workflow `.github/workflows/ios.yml` ejecuta SwiftLint 0.65.1 con versión fijada; sus errores bloquean CI y sus advertencias se publican sin convertir el límite de 100 líneas en un gate. No se ejecuta SwiftFormat. Tómalo como «extrae componentes cuando toques una vista».
  >
  > Consecuencia práctica: **un tipo no vive necesariamente en el archivo con su nombre**. `DuplicatePolicy` está en `ProductNameNormalizer.swift`, `WidgetItemSnapshot` en `WidgetDataBridge.swift` y `ReceiptServices.swift` contiene 14 tipos de nivel superior.

---

## 📄 Licencia

Este proyecto es de uso personal / educativo. Agrega una licencia según tus necesidades.
