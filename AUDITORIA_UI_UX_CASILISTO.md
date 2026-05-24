# Auditoria UI/UX, producto y SwiftUI - CasiListo

Fecha original: 2026-05-24  
Última actualización: 2026-05-24 (Sesión 5)  
Scope revisado: vistas SwiftUI, modelos SwiftData, view models, servicios de ciclo de lista, accesibilidad, modo compra, historial, componentes y tema visual.  
Validación técnica: `BUILD SUCCEEDED` en cada sesión de cambios.

---

## Registro de cambios implementados

### Sesión 1 — 2026-05-24

#### Correcciones de comportamiento

- `groupedItems`: eliminado `status.sortPriority` del criterio de orden — los ítems ya no se mueven al fondo al marcarse comprados; conservan orden alfabético. (`ShoppingListViewModel.swift`)

#### Doble escalado accesible (7 archivos)

- Eliminadas todas las multiplicaciones `* CGFloat(accessibilityTextSizeScale)` sobre propiedades `@ScaledMetric` en: `ItemRowView`, `CategorySectionView`, `ShoppingModeActiveView`, `AddEditCategorySheet`, `CompletionCelebrationView`, `CategoryManagementView`, `ShoppingModeItemRow`, `SummaryBarView`.
- Las fuentes (`Theme.bodyFont(scale:)`) siguen combinando Dynamic Type + slider correctamente ya que leen el tamaño del sistema antes de multiplicar.

#### Refactor de persistencia

- `addQuickItem()` movido de `ShoppingListView` al `ShoppingListViewModel` — la vista solo delega. (`ShoppingListViewModel.swift`, `ShoppingListView.swift`)
- Eliminados dos overloads de `clearPurchased()` del ViewModel (código muerto — el archivado real pasa por `ShoppingListLifecycleService`).

#### Layout de fila de producto

- `ItemRowView` rediseñado con dos niveles: nombre en línea propia, chips (tienda, cantidad, estado) en segunda línea. Reduce saturación horizontal y mejora escaneabilidad.
- Opacidad del badge de tienda: 0.85 → 0.68 (pendiente), 0.4 → 0.35 (comprado).

#### Copy e inconsistencias

- `"Limpiar Comprados"` → `"Archivar comprados"` (`CompletionCelebrationView`)
- Tildes faltantes corregidas: `"ubicacion"` → `"ubicación"`, `"despues"` → `"después"`, `"mas"` → `"más"` (`LocationPermissionOnboardingView`)
- `"Mas acciones para…"` → `"Más acciones para…"` (`ShoppingModeItemRow`)
- `"catalogo"` → `"catálogo"` (`ProductCatalogItem`)

### Sesión 2 — 2026-05-24

#### Modo compra — correcciones críticas

- `stopSession()` ahora se llama en `ShoppingModeView` al pulsar "Atrás" (`onBack`) y al salir con `onExit`. Cancela el `autoAdvanceTask` correctamente. (`ShoppingModeView.swift`)
- Confirmado: `checkCompletion()` ya usaba `actionableCount == 0` — la sesión termina correctamente cuando no quedan items accionables (aunque haya pospuestos/no encontrados). (`ShoppingModeViewModel.swift`)
- Confirmado: VoiceOver ya tenía acciones directas "Posponer" y "No encontrado" en `ShoppingModeItemRow`. (`ShoppingModeItemRow.swift`)

#### CTA "Archivar comprados" visible

- `SummaryBarView` acepta `onArchivePurchased: (() -> Void)?`. Cuando hay comprados y se pasa el callback, muestra un chip amarillo "N comprados" que dispara el diálogo de confirmación.
- `ShoppingListView` recibe `onArchivePurchased` y lo propaga a `SummaryBarView`.
- `ContentView` pasa `{ showsClearPurchasedDialog = true }` — el CTA ahora es visible en la lista principal, no solo en el menú. (`SummaryBarView.swift`, `ShoppingListView.swift`, `ContentView.swift`)

#### Doble escalado — ronda 2

- `ShoppingModeItemRow`: corregidos `ellipsisSize`, `checkboxSize`, `checkmarkSize`. (`ShoppingModeItemRow.swift`)
- `SummaryBarView`: corregidos `eyeIconSize`, `eyeButtonSize`. (`SummaryBarView.swift`)
- `CompletionCelebrationView.statRow`: el frame del icono ahora usa `iconSize + 12` en vez del literal `32 * scale`. (`CompletionCelebrationView.swift`)

#### Desacoplamiento de AddEditItemSheet

- Eliminada la dependencia del `ShoppingListViewModel` completo. Se reemplazó por parámetros concretos:
  - `preselectedStore: Store?`
  - `initialName: String` / `initialQuantity: String`
  - `onQuickAddConsumed: () -> Void`
  - `nextSortOrder: (Category) -> Int`
  - `checkDuplicate: (String, Store, UUID?) -> ShoppingItem?`
- `ContentView` computa el draft del quick-add antes de pasar al sheet. (`AddEditItemSheet.swift`, `ContentView.swift`, `PreviewSupport.swift`)
- Confirmado: `togglePurchased` y `markItem` ya llamaban `context?.safeSave()`. Sin cambio necesario.
- Confirmado: `archivePurchasedItems` ya usaba `fetchItems(in:fallback:)` para recalcular counters desde el contexto. Sin cambio necesario.

### Sesión 3 — 2026-05-24

#### Categorías colapsadas — UI y densidad

- `CategorySectionView`: `collapsedPaddingVertical` reducido de 10 a 6 pt, `collapsedOuterPadding` de 2 a 1 pt — menor espacio muerto entre tarjetas. (`CategorySectionView.swift`)

#### Acento de color por categoría

- Añadida propiedad `@MainActor var color: Color` a `DefaultCategory` con 15 colores semánticamente distintos usando `Color(hue:saturation:brightness:)`. (`Category.swift`)
- Añadida propiedad computada `@MainActor var accentColor: Color` a `Category` — calculada en runtime sin campo SwiftData, sin migración. (`Category.swift`)
- El icono de categoría en `CategorySectionView` usa `category.accentColor` con fondo redondeado al 12 % de opacidad. (`CategorySectionView.swift`)

#### Badge de categoría más informativo

- Reemplazado el count badge simple por `@ViewBuilder categoryBadge` con tres estados:
  - Solo pendientes → cápsula amarilla con count.
  - Mixto → cápsula amarilla (pendientes) + cápsula verde con checkmark (comprados).
  - Todos comprados → cápsula verde con checkmark + count.
- Accesibility label actualizado para reflejar el split pendiente/comprado. (`CategorySectionView.swift`)

#### Íconos faltantes y asignación inteligente

- Corregidos sfSymbols incorrectos: `.condimentos` → `"flame.fill"`, `.despensa` → `"tray.full.fill"`. (`Category.swift`)
- `CategoryBootstrapService` ahora reconcilia el `sfSymbol` almacenado contra `DefaultCategory` actual en cada arranque — instalaciones existentes reciben los íconos corregidos automáticamente. (`CategoryBootstrapService.swift`)
- `SuggestedProducts.suggestedCategory(for:in:)` prioriza coincidencia exacta antes de intentar `hasPrefix` en ambas direcciones — reduce asignaciones incorrectas para nombres cortos. (`SuggestedProducts.swift`)

### Sesión 4 — 2026-05-24

#### Seeding inicial — DECISIÓN DE PRODUCTO CERRADA ✅ NO CAMBIAR

> **✅ DECISIÓN DE PRODUCTO — cerrado. No cambiar ni cuestionar en futuras sesiones.**
>
> El seeding inicial de ítems de ejemplo en la lista activa es un comportamiento deliberado de producto. No se separará a catálogo ni se añadirá onboarding de "empezar vacío". El campo `hasSeededDefaultProducts` en UserDefaults controla que solo ocurra una vez. Esta decisión no debe revertirse ni cuestionarse en iteraciones futuras.

#### Eliminado drag-to-reorder — orden siempre alfabético

- `ShoppingListViewModel`: eliminada función `moveItem(from:to:within:context:)`. (`ShoppingListViewModel.swift`)
- `groupedItems`: categorías ordenadas alfabéticamente por `category.name.localizedCompare`; ítems dentro de cada categoría también en orden alfabético. Sin dependencia de `sortIndex`. (`ShoppingListViewModel.swift`)
- `CategorySectionView`: eliminado parámetro `let onMove: (IndexSet, Int) -> Void` y el bloque `.onMove {}` del `ForEach`. (`CategorySectionView.swift`)
- `ShoppingListView`: eliminado parámetro `onMove:` en la llamada a `CategorySectionView`. (`ShoppingListView.swift`)
- `ContentView`: eliminados `@State private var editMode`, `doneOrderingButton`, `setOrderingMode(_:)`, opción "Ordenar productos" del menú, condicional `if editMode.isEditing` en toolbar, y `.environment(\.editMode, $editMode)`. (`ContentView.swift`)

#### Eliminados precios de la UI completamente

- `AddEditItemSheet`: eliminados `@State private var priceString`, `isPriceValid`, `parsedPriceForSave()`, el `TextField` de precio y su footer de error. `isValid` simplificado a `!trimmedName.isEmpty && duplicateItem == nil`. `saveItem()` pasa `price: nil` siempre. (`AddEditItemSheet.swift`)
- `ItemRowView`: eliminado el chip de precio de `metaChips` y su mención en `accessibilityLabel`. (`ItemRowView.swift`)
- `SummaryBarView`: eliminados parámetros `pendingTotal: Double` y `purchasedTotal: Double` y cualquier texto de importes. (`SummaryBarView.swift`)
- `ShoppingListView`: actualizada la llamada a `SummaryBarView` sin los totales. (`ShoppingListView.swift`)
- `ShoppingListViewModel`: eliminados campos `pendingTotal` y `purchasedTotal` de `ListSummary`; eliminado su cálculo en `summary(from:)`; eliminadas las funciones standalone `pendingTotal(from:)`, `purchasedTotal(from:)` y `grandTotal(from:)`. (`ShoppingListViewModel.swift`)
- `ContentView`: eliminada referencia a `item.price` en `formattedShareText`. (`ContentView.swift`)
- `CompletionCelebrationView`: eliminado parámetro `let totalSpent: Double` y la fila "Gasto Estimado" con su `Divider`. Eliminada la línea de gasto en `shareSummaryText`. (`CompletionCelebrationView.swift`)
- `ShoppingModeView`: actualizada la llamada a `CompletionCelebrationView` sin `totalSpent`. (`ShoppingModeView.swift`)
- `ShoppingModeViewModel`: eliminada computed property `purchasedTotal`. (`ShoppingModeViewModel.swift`)
- **Nota**: el campo `price: Double?` en el modelo `ShoppingItem` se conserva en SwiftData sin usarse en la UI — evita una migración innecesaria.

#### Historial accesible desde EmptyStateView

- `EmptyStateView` añade parámetros `var hasHistory: Bool = false` y `var onShowHistory: (() -> Void)? = nil`. Cuando `hasHistory == true` muestra botón secundario "Ver última compra" debajo de "Añadir producto". (`EmptyStateView.swift`)
- `ContentView` pasa `hasHistory: !completedLists.isEmpty, onShowHistory: { viewModel.presentHistory() }`. El historial es accesible desde el estado vacío — el momento más natural para consultarlo. (`ContentView.swift`)

#### Contraste — eliminada opacidad global en filas compradas

- `ItemRowView`: eliminado `.opacity(item.isPurchased ? 0.72 : 1.0)` del contenedor de fila. El estado comprado se comunica mediante `Color.appTextPurchased`, tachado y badge al 35 %. (`ItemRowView.swift`)
- `ShoppingModeItemRow`: eliminado `.opacity(item.isPurchased ? 0.68 : 1.0)` del contenedor de fila. (`ShoppingModeItemRow.swift`)
- `Theme`: `shoppingModeSecondaryText` ajustado de `Color.white.opacity(0.72)` → `Color.white.opacity(0.80)`. (`Theme.swift`)
- `ShoppingModeActiveView`: flechas de navegación deshabilitadas: `.opacity(0.3)` → `.opacity(0.45)` (dos ocurrencias). (`ShoppingModeActiveView.swift`)

#### Touch targets — edit button en ItemRowView

- `ItemRowView`: edit button ahora aplica `max(Theme.minimumTouchTarget, scaledEditButtonSize)` en ambas dimensiones — garantiza ≥ 44 pt en cualquier tamaño de Dynamic Type. (`ItemRowView.swift`)

#### Reduce Motion

- `ItemRowView`: añadido `@Environment(\.accessibilityReduceMotion) private var reduceMotion`. Animación de fila: `.animation(reduceMotion ? nil : Theme.quickAnimation, value: item.isPurchased)`. (`ItemRowView.swift`)
- `ShoppingModeItemRow`: añadido `@Environment(\.accessibilityReduceMotion) private var reduceMotion`. Transición del checkmark: `.transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))`. (`ShoppingModeItemRow.swift`)

### Sesión 5 — 2026-05-24

#### Snapshot derivado en ShoppingListViewModel

- Añadidas propiedades `private(set) var derivedGroups` y `private(set) var derivedSummary` como estado cacheado en `ShoppingListViewModel`. (`ShoppingListViewModel.swift`)
- Añadidos `func updateDerivedState(items:categories:)` y `func rederiveFilters()` — el primero actualiza las entradas y recomputa; el segundo recomputa con las entradas ya almacenadas.
- `latestItems` y `latestCategories` son `@ObservationIgnored` para no desencadenar re-renders innecesarios.
- `ShoppingListView` llama `updateDerivedState` en `.onAppear` y en `.onChange(of: allItems)` / `.onChange(of: categories)`, y `rederiveFilters()` en `.onChange(of: viewModel.selectedStore/showPurchased/searchText)`. Grupos y resumen se calculan una vez por cambio de datos, no en cada render. (`ShoppingListView.swift`)

#### Tests — suite corregida y ampliada (26 tests, todos ✅)

- Eliminados tests de precios (`testPriceTotals`, `testListSummaryCalculatesCountsAndTotalsInOnePass`) — testaban métodos eliminados en Sesión 4. Reemplazados por tests de conteos puros. (`CasiListoTests.swift`)
- Corregido `testShoppingModePurchasedStatsIgnoreSkippedAndUnavailableItems` — eliminada aserción sobre `purchasedTotal` (removido en Sesión 4).
- Añadidos tests nuevos:
  - `quickAddDraft`: 7 casos (palabra sola, coma decimal, sufijo compacto de unidad, X mayúscula, unidad compuesta, nombre multi-palabra sin cantidad).
  - `groupedItems`: orden alfabético, ocultado de comprados, filtro por tienda.
  - `duplicateItem`: exclusión por ID específico.
  - `CategoryBootstrapService`: reconciliación de sfSymbols en categorías existentes, creación desde BD vacía.
  - `ShoppingModeViewModel`: `actionableCount` ignora pospuesto/no encontrado, la sesión se completa al no quedar accionables, marcar pospuesto no completa la sesión, el progreso avanza al comprar.
  - `summary`: filtrado por tienda seleccionada.

#### Ruido visual — sombras aligeradas

- `CategorySectionView` header: sombra `radius: 6, opacity: 0.06` → `radius: 4, opacity: 0.04`. (`CategorySectionView.swift`)
- `CategorySectionView` fila: sombra `radius: 4, opacity: 0.03` → `radius: 3, opacity: 0.02`. (`CategorySectionView.swift`)

#### Botón lápiz en fila — DECISIÓN DE PRODUCTO CERRADA ✅

> **✅ DECISIÓN DE PRODUCTO — cerrado. El botón lápiz permanece en la fila.**  
> El botón de edición coexiste con swipe actions y context menu. No eliminar.

#### Widget — CasiListoWidget (extensión WidgetKit)

- Creado target `CasiListoWidget` en `CasiListo.xcodeproj`. Tipo: `com.apple.product-type.app-extension`, bundle ID: `com.allopze.CasiListo.widget`. Embebido en CasiListo.app vía fase "Embed App Extensions". (`project.pbxproj`)
- `CasiListoWidget/WidgetDataModel.swift`: `WidgetSnapshot` Codable — `pendingCount`, `purchasedCount`, `topItems: [String]`, `updatedAt`. Lee desde App Group UserDefaults (`group.com.allopze.CasiListo`).
- `CasiListoWidget/CasiListoWidget.swift`: `PendingItemsProvider` (TimelineProvider), vistas `SmallWidgetView` y `MediumWidgetView`, entry point `@main CasiListoWidgetBundle`. Soporta `.systemSmall` y `.systemMedium`. Refresco automático cada 30 min + reload inmediato cuando la app escribe datos.
- `CasiListo/Services/WidgetDataBridge.swift`: serializa ítems de la lista activa a App Group UserDefaults y llama `WidgetCenter.shared.reloadAllTimelines()`. (`WidgetDataBridge.swift`)
- `ContentView` llama `WidgetDataBridge.write(items:)` en `.task` inicial y en `.onChange(of: activeItems)`. (`ContentView.swift`)
- Entitlements: `CasiListo/CasiListo.entitlements` y `CasiListoWidget/CasiListoWidget.entitlements` con `com.apple.security.application-groups = ["group.com.allopze.CasiListo"]`. Referenciados en `CODE_SIGN_ENTITLEMENTS` de ambos targets.
- **Requisito post-instalación**: activar el App Group `group.com.allopze.CasiListo` en Apple Developer Portal para ambos bundle IDs antes de distribuir en dispositivo real.

---

## Resumen ejecutivo

CasiListo tiene una base de producto sólida: SwiftData, lista activa e historial, entrada rápida, búsqueda, categorías con acento de color, supermercado, modo compra, notas de voz, geofencing, y uso moderno de `@Observable`, `@Bindable`, `sheet(item:)` y wrappers Liquid Glass.

Tras cuatro sesiones de mejoras, la app compila sin errores con Swift 6 / iOS 26, los flujos principales funcionan con cohesión visual, y los problemas de accesibilidad críticos (doble escalado, contraste, touch targets, Reduce Motion) están resueltos.

---

## Problemas críticos — estado actual

### 1. El primer inicio — DECISIÓN DE PRODUCTO CERRADA ✅

> Seeding inicial de ítems de ejemplo es comportamiento deliberado. Ver nota en Sesión 4. No reabrir.

### 2. Completar compra con estados reales ✅ RESUELTO

`checkCompletion()` usa `actionableCount == 0`. `stopSession()` se llama al salir. Resuelto en Sesión 2.

### 3. Organizar productos — drag eliminado, orden alfabético ✅ RESUELTO

Drag-to-reorder eliminado en Sesión 4. Categorías e ítems siempre en orden alfabético. Sin affordances ambiguos.

### 4. Fila de producto ✅ RESUELTO (sesión 1)

Layout de dos niveles. Nombre en línea propia, chips en segunda fila.

### 5. Historial accesible ✅ RESUELTO (sesión 4)

Botón "Ver última compra" en `EmptyStateView` cuando hay historial. Sigue disponible en el menú.

### 6. Doble escalado accesible ✅ RESUELTO

Eliminado en todas las vistas afectadas (sesiones 1 y 2).

### 7. Counters de lista activa tras archivar ✅ RESUELTO

`archivePurchasedItems` usa `fetchItems(in:fallback:)`. Resuelto en Sesión 2.

### 8. Precios en UI ✅ RESUELTO (sesión 4)

Todos los campos de precio eliminados de la UI. El campo `price: Double?` persiste en SwiftData sin usarse — sin migración.

---

## Mejoras de UI — estado

- **Reducir ruido de tarjetas y sombras** ⚠️ pendiente
- **Rehacer la fila principal como componente escaneable** ✅ resuelto (dos niveles)
- **Botón lápiz vs Menu en la fila** ⚠️ pendiente — en lista de compra, la acción más frecuente es marcar, no editar
- **Acento de color por categoría** ✅ resuelto (sesión 3)
- **Badge de categoría informativo** ✅ resuelto (sesión 3 — estados pendiente/mixto/todos-comprados)
- **Íconos de categoría completos** ✅ resuelto (sesión 3)

---

## Mejoras de accesibilidad — estado

- **VoiceOver: acciones en ShoppingModeItemRow** ✅ ya existían
- **VoiceOver: acción "Editar" en ItemRowView** ✅ ya existía
- **Dynamic Type / doble escalado** ✅ resuelto
- **Touch targets: edit button ItemRowView** ✅ resuelto (sesión 4)
- **Contraste: opacidades globales en filas compradas** ✅ resuelto (sesión 4)
- **Reduce Motion: fila de item y checkmark modo compra** ✅ resuelto (sesión 4)
- **Reduce Motion: confetti y waveform** ✅ ya protegidos antes de sesión 4
- **Textos localizados y acentos** ✅ corregidos en vistas principales

---

## Observaciones técnicas — estado

- **Build**: compila correctamente con Swift 6, iOS Simulator 26. ✅
- **Concurrencia**: `stopSession()` se llama al salir del modo compra. ✅
- **Performance**: `groups` y `summary` se recalculan en cada render en `ShoppingListView`. Para listas grandes conviene un snapshot derivado. ⚠️ pendiente
- **Fan-out de observación**: `ShoppingListView` recibe `ShoppingListViewModel` como `@Bindable`. Pasar solo valores derivados reduciría invalidaciones. ⚠️ pendiente
- **Persistencia**: `togglePurchased` y `markItem` llaman `context?.safeSave()`. ✅
- **Precio como Double**: el campo existe en SwiftData sin usarse en UI. Si se reactiva, debería migrar a `Decimal` o entero de centavos. ⚠️ nota técnica
- **`AddEditItemSheet` desacoplado** del ViewModel completo. ✅
- **Sheets**: `sheet(item:)` usado correctamente en `ContentView`. ✅
- **Tests**: siguen sin suite ejecutable.

---

## Siguientes pasos naturales

### Prioridad media

1. **Sugerencias por frecuencia** — ordenar candidatos de `SuggestedProducts` por prefijo exacto primero y frecuencia histórica de uso.
2. **Widget — App Group en Developer Portal** — para distribución en dispositivo real, activar `group.com.allopze.CasiListo` en Apple Developer Portal y regenerar perfiles de aprovisionamiento.
3. **Widget mediano — deep link** — al tocar un ítem en el widget mediano, abrir la app directo en ese producto.

### Prioridad baja / futuro

1. **iCloud sync / CloudKit** — base para listas compartidas entre dispositivos.
2. **App Intents / Siri** — añadir productos sin abrir la app ("Añade leche a CasiListo").
3. **Campo precio reactivo** — si se retoma, migrar de `Double` a `Decimal`/centavos y mostrar presupuesto estimado vs real.
4. **Motor de pasillos** — orden de categorías configurable por supermercado en modo compra.
5. **Recetas / planificación** — conectar ingredientes de receta con la lista de compra.

---

## Lista priorizada de acciones (original, estado actualizado)

### 1. Cambios rápidos de alto impacto

1. ~~Desactivar seeding automático~~ ✅ DECISIÓN DE PRODUCTO CERRADA — no cambiar
2. ~~Corregir cierre de modo compra~~ ✅ resuelto (sesión 2)
3. ~~Agregar acciones VoiceOver en ShoppingModeItemRow~~ ✅ ya existían
4. ~~Cambiar shoppingModeButton a cápsula~~ ✅ ya era cápsula
5. ~~Agregar CTA visible "Archivar comprados"~~ ✅ resuelto (sesión 2)
6. ~~Evitar doble escalado~~ ✅ resuelto (sesiones 1 y 2)
7. ~~Llamar stopSession() al salir~~ ✅ resuelto (sesión 2)
8. ~~Pulir copy y acentos~~ ✅ resuelto (sesión 1)

### 2. Mejoras importantes de mediano esfuerzo

1. ~~Rediseñar fila de producto con dos niveles~~ ✅ resuelto (sesión 1)
2. ~~Acento de color por categoría~~ ✅ resuelto (sesión 3)
3. ~~Badge de categoría informativo~~ ✅ resuelto (sesión 3)
4. ~~Íconos de categoría completos~~ ✅ resuelto (sesión 3)
5. ~~Contraste en filas compradas~~ ✅ resuelto (sesión 4)
6. ~~Touch targets edit button~~ ✅ resuelto (sesión 4)
7. ~~Reduce Motion en fila e ítem modo compra~~ ✅ resuelto (sesión 4)
8. ~~Eliminar precios de UI~~ ✅ resuelto (sesión 4)
9. ~~Historial accesible desde estado vacío~~ ✅ resuelto (sesión 4)
10. ~~Eliminar drag-to-reorder~~ ✅ resuelto (sesión 4)
11. ~~Snapshot derivado para grupos y resumen~~ ✅ resuelto (sesión 5)
12. ~~Tests de flujos principales~~ ✅ resuelto (sesión 5 — 26 tests)
13. ~~Ruido visual (sombras y fondos)~~ ✅ resuelto (sesión 5)
14. ~~Botón lápiz en fila~~ ✅ DECISIÓN DE PRODUCTO CERRADA — permanece
15. ~~Widget de pantalla de inicio~~ ✅ resuelto (sesión 5)

### 3. Mejoras avanzadas o de mayor alcance

1. Listas compartidas con iCloud/CloudKit
2. Motor de pasillos/secciones configurable por supermercado
3. Presupuesto estimado persistente (requiere decisión sobre precio)
4. App Intents / Siri
5. Escaneo de códigos de barra
6. Recetas/planificación de comidas conectadas con lista
7. Sugerencias por frecuencia histórica de uso
