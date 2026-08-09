# 🔍 Auditoría Completa del Proyecto CasiListo

> **Fecha:** 2026-07-30
> **Versión del proyecto:** iOS 17+ / SwiftUI / SwiftData
> **Objetivo:** Identificar bugs, errores, inconsistencias, oportunidades de mejora y nuevas funciones para una app de lista de compras estilo CasiListo.

---

## 📋 Resumen Ejecutivo

CasiListo es una app iOS nativa de lista de compras construida con **SwiftUI + SwiftData**. Tiene una base de producto sólida con funcionalidades como modo compra, notas de voz, geofencing, gamificación, widgets y un sistema de diseño (Liquid Glass) bien estructurado. Sin embargo, existen inconsistencias de código, bugs potenciales y áreas de mejora significativas.

---

## 🐛 BUGS Y ERRORES DETECTADOS

### BUG-01: Doble escalado de accesibilidad en SettingsSheet
- **Archivo:** `CasiListo/Views/SettingsSheet.swift` (vista principal y subvistas)
- **Problema:** Las subvistas `SettingsPreviewCard`, `SettingsGestureGuideSection` y `SettingsAchievementsView` usan multiplicación manual `CGFloat(accessibilityTextSizeScale)` en lugar de usar `Theme.*Font(scale:)` y `@ScaledMetric`. Esto genera escalado doble o inconsistente comparado con el resto de la app que usa los helpers de Theme.
- **Evidencia:**
  ```swift
  // SettingsPreviewCard — escalado manual inconsistente
  Text("VISTA PREVIA EN VIVO")
      .font(Theme.captionFont(scale: accessibilityTextSizeScale))  // ✅ correcto
  HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {      // ❌ manual
      Button {
          .frame(
              width: 26 * CGFloat(accessibilityTextSizeScale),     // ❌ manual
              height: 26 * CGFloat(accessibilityTextSizeScale)
          )
  ```
- **Severidad:** Alta — afecta legibilidad en tamaños de texto grandes.
- **Solución:** Reemplazar todas las multiplicaciones manuales por `@ScaledMetric` o helpers de `Theme.*Font(scale:)`.

### BUG-02: Doble escalado en AchievementsView
- **Archivo:** `CasiListo/Views/AchievementsView.swift`
- **Problema:** Las estadísticas de logros usan multiplicación manual `CGFloat(accessibilityTextSizeScale)` en `statsSummaryCard` y `achievementGridItem`:
  ```swift
  VStack(spacing: 20 * CGFloat(accessibilityTextSizeScale)) {  // ❌ manual
  Text("🔥")
      .font(.system(size: 48 * CGFloat(accessibilityTextSizeScale)))  // ❌ manual
  ```
- **Severidad:** Alta — la vista de logros no escala correctamente con Dynamic Type.

### BUG-03: Doble escalado en ShoppingHistoryDetailView
- **Archivo:** `CasiListo/Views/ShoppingHistoryDetailView.swift`
- **Problema:** El ícono de estado y el texto del supermercado usan escalado manual:
  ```swift
  Image(systemName: icon)
      .font(.system(size: statusIconSize * CGFloat(accessibilityTextSizeScale)))  // ❌ manual
  
  Text(item.store.displayName)
      .font(.system(size: storeTextSize * CGFloat(accessibilityTextSizeScale)))   // ❌ manual
  ```
- **Severidad:** Media — el historial no escala de forma consistente.

### BUG-04: ShoppingModeHeaderView usa escalado manual en chevron y tienda
- **Archivo:** `CasiListo/Views/Components/ShoppingModeHeaderView.swift`
- **Problema:** El botón "Atrás" y el badge de tienda aplican `CGFloat(accessibilityTextSizeScale)` manualmente en lugar de usar `@ScaledMetric`:
  ```swift
  Image(systemName: "chevron.left")
      .font(.system(size: chevronSize * CGFloat(accessibilityTextSizeScale), weight: .bold))
  ```
- **Severidad:** Media — afecta el header del modo compra.

### BUG-05: ShoppingModeItemRow usa escalado manual en ellipsis
- **Archivo:** `CasiListo/Views/Components/ShoppingModeItemRow.swift`
- **Problema:** El botón de "más acciones" en el modo compra usa escalado manual:
  ```swift
  Image(systemName: "ellipsis")
      .font(.system(size: ellipsisSize, weight: .bold))  // ellipsisSize es ScaledMetric pero el frame usa Theme.minimumTouchTarget directamente
  ```
- **Severidad:** Baja — el touch target se mantiene mínimo.

### BUG-06: `GeofenceService.fetchPendingCount` crea ModelContext desde container sin guardar
- **Archivo:** `CasiListo/Services/GeofenceService.swift`
- **Problema:** `fetchPendingCount(for:)` crea un `ModelContext(container)` nuevo cada vez que se ejecuta, sin garantizar que los cambios de la app principal estén visibles. El `ModelContext` podría no ver datos no guardados en el contexto principal.
- **Severidad:** Media — podría contar productos pendientes incorrectamente si hay cambios no persistidos.

### BUG-07: Archivado pone pendingCount/skippedCount/unavailableCount en cero
- **Archivo:** `CasiListo/Services/ShoppingListLifecycleService.swift`
- **Problema:** `archivePurchasedItems` crea el `ShoppingList` completado con `pendingCount: 0, skippedCount: 0, unavailableCount: 0` aunque existan productos con esos estados en la lista. Los conteos no reflejan el estado real de la sesión.
- **Evidencia:**
  ```swift
  let completedList = ShoppingList(
      ...
      pendingCount: 0,      // ← Siempre cero, aunque hayan quedado pendientes
      skippedCount: 0,      // ← Siempre cero
      unavailableCount: 0,  // ← Siempre cero
      ...
  )
  ```
- **Severidad:** Alta — el historial muestra información incorrecta sobre la sesión de compra.
- **Solución:** Contar los ítems realmente archivados vs los que quedaron en la lista activa.

### BUG-08: `Category.fallback` es un singleton `nonisolated(unsafe)` que puede causar problemas con SwiftData
- **Archivo:** `CasiListo/Models/Category.swift`
- **Problema:** `Category.fallback` es una instancia estática no gestionada. Si se asigna accidentalmente a una relación SwiftData, puede causar comportamientos inesperados. Aunque el código usa `resolvedFallback(in:)` para relaciones, el fallback estático se usa en varios puntos del código.
- **Severidad:** Media — riesgo de datos inconsistentes en edge cases.

### BUG-09: `addQuickItem` muta `allItems` como array de SwiftData pero puede tener items no persistidos
- **Archivo:** `CasiListo/ViewModels/ShoppingListViewModel.swift`
- **Problema:** `addQuickItem` recibe `allItems` como parámetro y luego hace `allItems + [newItem]` para llamar a `updateActiveListCounters`. El `allItems` es una referencia a los items del query, pero `newItem` puede no estar completamente persistido aún.
- **Severidad:** Baja — en la práctica funciona porque `context.safeSave()` se llama después.

### BUG-10: `ShoppingModeViewModel.progress` puede mostrar 100% aunque la sesión no esté completa
- **Archivo:** `CasiListo/ViewModels/ShoppingModeViewModel.swift`
- **Problema:** `progress` calcula `purchasedCount / totalCount`, pero la sesión termina cuando `actionableCount == 0`. Si hay items pospuestos o no encontrados, progress puede llegar a 100% sin que la sesión se haya completado formalmente.
- **Severidad:** Baja — el progreso se muestra antes de que la sesión se complete.

---

## 🔄 INCONSISTENCIAS DETECTADAS

### INC-01: README desactualizado
- **Problema:** El README dice "9 categorías" y "~90 productos", pero el código tiene **15 categorías DefaultCategory** y **~290 productos** en `SuggestedProducts.byCategory`.
- **Severidad:** Baja — documentación desactualizada.

### INC-02: Campo `price: Double?` persistido en SwiftData sin usarse en UI
- **Archivo:** `CasiListo/Models/ShoppingItem.swift`
- **Problema:** El campo existe en el modelo pero fue eliminado de todas las vistas. El archivo `Double.formattedPrice` y sus extensiones de formato también existen sin uso en UI principal. Esto consume espacio y confunde.
- **Solución:** Decidir si se reactiva (con migración a `Decimal`) o se mantiene oculto.

### INC-03: `isPurchased` y `status` duplican estado
- **Archivo:** `CasiListo/Models/ShoppingItem.swift`
- **Problema:** `isPurchased` es una computed property derivada de `status`, pero `storedIsPurchased` es un campo SwiftData persistido por separado. El get/set sync ambos, pero si hay un bug de concurrencia o crash, podrían quedar desincronizados.
- **Solución:** Considerar eliminar `storedIsPurchased` y usar solo `statusRawValue` + `isPurchased` como computed.

### INC-04: Nomenclatura inconsistente de "Líder" vs "Lider"
- **Archivos:** `Store.swift` vs textos de onboarding
- **Problema:** `Store.lider` tiene rawValue `"Líder"` con tilde, pero algunos textos podrían escribir "Lider" sin tilde (detectado en sesiones anteriores de auditoría).

### INC-05: `try?` silencia errores críticos
- **Archivos:** Múltiples archivos (`AddEditCategorySheet.swift`, `CategoryManagementView.swift`, `GeofenceService.swift`)
- **Problema:** `try? modelContext.save()` se usa en varios puntos sin feedback al usuario. Un fallo de guardado queda silenciado.
- **Solución:** Usar `context.safeSave()` de forma consistente o mostrar error UI cuando aplique.

### INC-06: Servicios singleton no son testeables
- **Archivos:** `GeofenceService.shared`, `VoiceNoteService.shared`
- **Problema:** Ambos servicios usan patrón singleton, lo que dificulta tests unitarios con mocks.
- **Solución:** Inyectar servicios via `@Environment` (ya se hace parcialmente) o protocolos.

### INC-07: `SettingsSheet.swift` excede el límite de 100 líneas del README
- **Archivo:** `CasiListo/Views/SettingsSheet.swift` (~475 líneas)
- **Problema:** Aunque está dividido en subvistas, el archivo principal sigue siendo largo. La norma del README dice "no superar 100 líneas".
- **Solución:** Mover subvistas a archivos separados.

### INC-08: Inconsistencia en el manejo de `@AppStorage` vs `AppSettings`
- **Archivos:** Diferentes views
- **Problema:** Algunas vistas usan `@AppStorage("accessibilityTextSizeScale")` directamente, otras usan `@Environment(AppSettings.self)`. Ambos leen la misma key de UserDefaults pero de forma independiente.
- **Solución:** Estandarizar en `@Environment(AppSettings.self)` para evitar desincronización.

---

## 📐 MALAS PRÁCTICAS DETECTADAS

### MALA-01: Persistencia repartida en Views
- **Archivos:** `AddEditItemSheet.swift`, `ShoppingListView.swift`, `CategoryManagementView.swift`
- **Problema:** Varias vistas hacen `context.insert()`, `context.delete()` y `context.save()` directamente. La lógica de negocio debería estar en el ViewModel o un servicio/repository.
- **Impacto:** Dificulta testing, reutilización y mantenimiento.

### MALA-02: `ShoppingListViewModel` mezcla responsabilidades
- **Archivo:** `CasiListo/ViewModels/ShoppingListViewModel.swift`
- **Problema:** El ViewModel mezcla estado UI (filtros, navegación modal), lógica de negocio (duplicados, quick add) y parsing de texto. Debería dividirse en un ViewModel de UI y un servicio de reglas de negocio.

### MALA-03: Archivos que exceden 100 líneas
- `SettingsSheet.swift`: ~475 líneas
- `Theme.swift`: ~386 líneas
- `ShoppingListViewModel.swift`: ~342 líneas
- `ContentView.swift`: ~180 líneas
- `AddEditItemSheet.swift`: ~200 líneas
- `CategorySectionView.swift`: ~200 líneas

### MALA-04: `CategoryBootstrapService` es una clase con solo métodos estáticos
- **Archivo:** `CasiListo/Services/CategoryBootstrapService.swift`
- **Problema:** Es una `final class` con solo `static` methods. Debería ser un `enum` o tener una interfaz inyectable.

---

## 🚀 OPORTUNIDADES DE MEJORA

### MEJORA-01: Undo al eliminar productos
- **Problema:** Al eliminar un producto con swipe o context menu, no hay forma de deshacer la acción.
- **Solución:** Implementar un snackbar temporal con opción "Deshacer" (similar a Gmail) o aprovechar `UndoManager` de SwiftData (`isUndoEnabled: true` ya está habilitado en `CasiListoApp`).
- **Impacto:** Alto — previene pérdida accidental de datos.

### MEJORA-02: Skeleton loading states
- **Problema:** No hay indicadores de carga durante el bootstrap inicial o cuando se cargan datos pesados.
- **Solución:** Agregar skeleton views o shimmer effects mientras se carga la lista.
- **Impacto:** Medio — mejora la percepción de rendimiento.

### MEJORA-03: Pull-to-refresh manual
- **Problema:** Aunque SwiftData es reactivo, no hay forma de forzar una recarga manual si los datos se desincronizan.
- **Solución:** Agregar `.refreshable` a `ShoppingListView`.
- **Impacto:** Bajo — SwiftData maneja la reactividad.

### MEJORA-04: Feedback visual al marcar productos
- **Problema:** Al marcar un producto como comprado, la animación es sutil. Podría beneficiarse de una animación más satisfactoria.
- **Solución:** Animación de "check" con haptic más pronunciado y feedback visual (ej: confetti sutil o animación de "completado").
- **Impacto:** Medio — gamificación sutil.

### MEJORA-05: Búsqueda por categoría en la barra de búsqueda
- **Problema:** La búsqueda filtra por nombre, nota y categoría, pero no muestra resultados agrupados por categoría ni resalta las coincidencias.
- **Solución:** Agregar highlighting de texto en resultados y conteo de coincidencias por categoría.
- **Impacto:** Medio — mejora la búsqueda.

### MEJORA-06: Badges en el tab bar o indicadores de progreso
- **Problema:** No hay indicador visible del progreso de la lista en la vista principal.
- **Solución:** Agregar un mini badge o barra de progreso en el header de la lista.
- **Impacto:** Medio — gamificación sutil.

### MEJORA-07: Confirmación antes de eliminar categoría con productos
- **Problema:** Al eliminar una categoría, los productos se reasignan a "Varios" sin confirmación explícita.
- **Solución:** Mostrar alerta con conteo de productos afectados antes de eliminar.
- **Impacto:** Medio — previene pérdida de organización.

---

## 🆕 NUEVAS FUNCIONES RECOMENDADAS

### FUNC-01: Importar lista desde texto (Clipboard / WhatsApp)
- **Descripción:** Permitir pegar una lista de texto multilinea (copiada desde WhatsApp, notas, etc.) y parsearla en productos individuales.
- **Flujo:**
  1. Usuario toca "Importar desde texto"
  2. Pega el texto en un campo
  3. La app parsea línea por línea, sugiere cantidades y categorías
  4. Usuario confirma o ajusta
  5. Se añaden todos los productos a la lista
- **Dificultad:** Media-Baja
- **Impacto:** Alto — muy útil para listas recibidas por mensaje.

### FUNC-02: Añadir productos por voz (Dictado)
- **Descripción:** Usar el framework Speech para dictar múltiples productos en una sesión continua.
- **Flujo:**
  1. Usuario mantiene presionado el botón de micrófono
  2. Dicta: "Leche, pan, mantequilla, 2 kilos de tomates"
  3. La app parsea y crea los productos
- **Dificultad:** Media
- **Impacto:** Alto — manos libres en el supermercado.

### FUNC-03: Plantillas de listas predefinidas
- **Descripción:** Listas reutilizables como "Compra semanal", "Asado", "Limpieza del hogar", "Desayuno de la semana".
- **Flujo:**
  1. Desde el menú, usuario selecciona "Usar plantilla"
  2. Elige una plantilla predefinida o crea una personalizada
  3. Se añaden los productos de la plantilla a la lista activa
- **Dificultad:** Media
- **Impacto:** Alto — ahorra tiempo en compras recurrentes.

### FUNC-04: Múltiples listas de compra
- **Descripción:** Permitir crear y gestionar múltiples listas activas (ej: "Compras del mes", "Asado del sábado").
- **Flujo:**
  1. Tab bar o menú con opción "Nueva lista"
  2. Cada lista tiene su propio nombre, fecha y estado
  3. Se puede alternar entre listas
- **Dificultad:** Media-Alta
- **Impacto:** Alto — flexibilidad para familias o compras múltiples.

### FUNC-05: Presupuesto estimado por producto y total
- **Descripción:** Reactivar el campo `price` (o migrar a `Decimal`) y permitir al usuario asignar precios. Mostrar total estimado vs gasto real.
- **Flujo:**
  1. Al editar un producto, campo opcional de precio
  2. Barra de resumen muestra total estimado
  3. En modo compra, se puede registrar el precio real pagado
  4. Historial muestra desglose de gasto
- **Dificultad:** Media
- **Impacto:** Alto — control de gasto familiar.

### FUNC-06: Compartir lista por iCloud / CloudKit
- **Descripción:** Sincronizar listas entre dispositivos y permitir listas compartidas en familia.
- **Dificultad:** Alta
- **Impacto:** Alto — multi-dispositivo y colaboración.

### FUNC-07: App Intents / Siri
- **Descripción:** Añadir productos sin abrir la app usando Siri: "Hey Siri, añade leche a CasiListo".
- **Dificultad:** Media-Alta
- **Impacto:** Alto — conveniencia extrema.

### FUNC-08: Widget con deep links interactivos
- **Descripción:** El widget mediano permite marcar productos directamente desde la pantalla de inicio.
- **Flujo:**
  1. Widget muestra los 5 productos pendientes
  2. Toque en un producto lo marca como comprado (con confirmación)
  3. Widget se actualiza automáticamente
- **Dificultad:** Media
- **Impacto:** Medio-Alto — acceso rápido sin abrir la app.

### FUNC-09: Escaneo de código de barras
- **Descripción:** Usar la cámara para escanear códigos de barras y buscar productos en la base de datos local o una API.
- **Dificultad:** Alta
- **Impacto:** Medio — entrada precisa de productos.

### FUNC-10: Orden por pasillos/secciones del supermercado
- **Descripción:** Permitir al usuario definir el orden de las categorías según la distribución del supermercado.
- **Flujo:**
  1. Cada supermercado tiene un orden de categorías configurado
  2. En modo compra, las categorías se muestran en ese orden
  3. Se puede configurar por tienda en Ajustes
- **Dificultad:** Media
- **Impacto:** Alto — optimiza la ruta de compra.

### FUNC-11: Sugerencias por frecuencia de uso
- **Descripción:** Ordenar las sugerencias de productos por frecuencia de uso histórico (cuántas veces se ha añadido cada producto).
- **Flujo:**
  1. `ProductCatalogItem.timesAdded` ya existe
  2. `SuggestedProducts.suggestions()` ordena por `timesAdded` descendente
  3. Los productos más usados aparecen primero en las sugerencias
- **Dificultad:** Baja
- **Impacto:** Alto — personalización automática.

### FUNC-12: Historial de búsquedas recientes
- **Descripción:** Recordar las últimas búsquedas del usuario y mostrarlas como sugerencias al abrir el campo de búsqueda.
- **Flujo:**
  1. Al buscar, se guarda la query (últimas 10)
  2. Al tocar el campo de búsqueda, se muestran las búsquedas recientes
  3. Se puede limpiar el historial
- **Dificultad:** Baja
- **Impacto:** Medio — conveniencia.

### FUNC-13: Productos frecuentes en la pantalla principal
- **Descripción:** Mostrar los 5 productos más añadidos recientemente en la pantalla principal (cuando la lista está vacía o como sección rápida).
- **Flujo:**
  1. Consultar `ProductCatalogItem` ordenado por `lastAddedAt`
  2. Mostrar chips clickeables en la vista vacía o en la parte superior
  3. Toque agrega el producto a la lista
- **Dificultad:** Baja
- **Impacto:** Alto — reduce fricción de entrada.

### FUNC-14: Notas de voz en modo compra
- **Descripción:** Permitir grabar notas de voz directamente desde el modo compra (no solo desde el modal de edición).
- **Flujo:**
  1. En `ShoppingModeItemRow`, agregar botón de grabar nota de voz
  2. Grabación rápida de 30 segundos
  3. Se guarda y asocia al producto
- **Dificultad:** Media
- **Impacto:** Medio — útil en el supermercado.

### FUNC-15: Exportar historial como CSV/JSON
- **Descripción:** Permitir exportar el historial de compras en formato CSV o JSON para análisis externo.
- **Flujo:**
  1. Desde el historial, botón "Exportar"
  2. Seleccionar rango de fechas
  3. Generar archivo y compartirlo
- **Dificultad:** Media
- **Impacto:** Medio — para usuarios que quieren analizar gastos.

---

## 🎨 MEJORAS DE UI/UX

### UIUX-01: Empty state más enriquecido
- **Problema:** El empty state actual es funcional pero podría ser más atractivo.
- **Solución:**
  - Agregar animación Lottie o_SF Symbol_ animado
  - Mostrar los 3-5 productos más frecuentes como chips clickeables
  - Tip contextual: "¿Primera vez? Toca aquí para ver cómo funciona"

### UIUX-02: Mejor feedback al marcar productos
- **Problema:** La animación actual es sutil.
- **Solución:**
  - Animación de "bounce" en el checkbox al marcar
  - Haptic más pronunciado (`.medium` en lugar de `.light`)
  - Mini confetti al completar una categoría en modo compra

### UIUX-03: Pull-to-refresh con animación
- **Problema:** No hay feedback visual al actualizar.
- **Solución:** Agregar `.refreshable` con skeleton shimmer.

### UIUX-04: Búsqueda mejorada con highlights
- **Problema:** Los resultados de búsqueda no resaltan las coincidencias.
- **Solución:** Agregar `.highlight` o `AttributedString` con color de acento en las partes del nombre que coinciden con la búsqueda.

### UIUX-05: Swipe actions más descubribles
- **Problema:** Los swipe actions existen pero no son obvios para usuarios nuevos.
- **Solución:** Agregar un tooltip o coach mark en el primer uso que muestre "Desliza para editar o eliminar".

### UIUX-06: Mejor onboarding de primera vez
- **Problema:** El usuario abre la app y ve ~290 productos. No se siente como "mi lista".
- **Solución:**
  - Ofrecer "Empezar vacío" vs "Usar productos de ejemplo"
  - Tour guiado de 3-4 pasos con coach marks
  - Primera vez: mostrar empty state + chips de frecuentes

### UIUX-07: Consistencia en estilos de botón
- **Problema:** Mezcla de cápsulas, círculos y botones redondeados con diferentes radios.
- **Solución:** Definir en Theme.swift estilos canónicos: `primary` (cápsula amarilla), `secondary` (cápsula glass), `icon` (círculo glass), `ghost` (solo texto).

### UIUX-08: Animación de transición entre categorías en modo compra
- **Problema:** La transición entre categorías es un simple slide.
- **Solución:** Animación de "push" con efecto parallax o crossfade.

### UIUX-09: Haptic patterns personalizados
- **Problema:** Todos los haptics son `.light` o `.medium`.
- **Solución:** Definir patterns específicos:
  - Marcar producto: `.selection` (ligero)
  - Completar categoría: `.success` (celebración)
  - Eliminar: `.warning` (confirmación)

### UIUX-10: Dark mode mejorado para modo compra
- **Problema:** El modo compra ya es oscuro, pero podría tener más contraste.
- **Solución:** Ajustar opacidades de texto y superficies para mayor legibilidad.

---

## 🧪 TESTS RECOMENDADOS

### Unit Tests
1. `testQuickAddDraftParsesSpanishDecimalSeparators` — parseo de "2,5 leche"
2. `testDuplicateItemIgnoresCaseAndDiacritics` — "CAFÉ" = "café"
3. `testArchivePurchasedItemsCorrectsCounts` — conteos correctos en historial
4. `testShoppingModeAutoAdvanceSkipsEmptyCategories` — auto-avance en categorías vacías
5. `testCategoryBootstrapReconcilesSymbolsOnUpdate` — reconciliación de sfSymbols
6. `testWidgetDataBridgeWritesCorrectSnapshot` — serialización para widget

### Integration Tests
1. `testFullShoppingFlow` — crear → marcar → archivar → verificar historial
2. `testQuickAddThenEditThenDelete` — flujo CRUD completo
3. `testShoppingModeWithMixedStatuses` — modo compra con pospuestos/no encontrados
4. `testGeofenceNotificationWithPendingItems` — notificación con productos pendientes

### UI Tests
1. `testAddProductViaQuickBar` — añadir producto desde barra rápida
2. `testSearchAndFilterResults` — buscar y filtrar por tienda
3. `testCollapseAndExpandCategory` — colapsar/expandir categoría
4. `testShoppingModeCategoryNavigation` — navegar entre categorías

---

## 📏 CHECKLIST DE VALIDACIÓN

### Antes de cada release
- [ ] Build exitoso en iOS 17.0+ (deployment target correcto)
- [ ] Todos los tests unitarios pasan (26+ tests)
- [ ] No hay `try?` silenciando errores críticos sin logging
- [ ] Dynamic Type funciona en tamaños XXXL sin truncamiento
- [ ] VoiceOver funciona correctamente en todas las vistas
- [ ] Reduce Motion respeta la configuración del sistema
- [ ] Touch targets ≥ 44pt en todos los botones interactivos
- [ ] Contraste de texto ≥ 4.5:1 en todos los fondos
- [ ] Liquid Glass funciona en iOS 26+ y degrada gracefully en iOS 17-25
- [ ] Widget actualiza datos correctamente vía App Group
- [ ] Geofencing funciona con permisos de ubicación
- [ ] Notas de voz se guardan, reproducen y limpian correctamente

### Arquitectura
- [ ] Ningún archivo supera 100 líneas sin justificación
- [ ] Lógica de negocio está en ViewModels o Servicios, no en Views
- [ ] Servicios son testeables (no singleton puro)
- [ ] Modelos SwiftData tienen relaciones correctas

---

## 🗺️ ROADMAP SUGERIDO

### v1.1 — Calidad y correcciones
- Corregir doble escalado de accesibilidad (BUG-01 a BUG-05)
- Corregir conteos de historial (BUG-07)
- Desacoplar persistencia de Views
- Añadir undo al eliminar
- Tests de flujos principales

### v1.2 — Experiencia de usuario
- Importar lista desde texto (FUNC-01)
- Sugerencias por frecuencia (FUNC-11)
- Empty state enriquecido (UIUX-01)
- Búsqueda con highlights (UIUX-04)
- Onboarding mejorado (UIUX-06)

### v1.3 — Funciones inteligentes
- Añadir por voz (FUNC-02)
- Plantillas de listas (FUNC-03)
- Presupuesto estimado (FUNC-05)
- Orden por pasillos (FUNC-10)

### v2.0 — Evolución avanzada
- Múltiples listas (FUNC-04)
- iCloud/CloudKit (FUNC-06)
- App Intents/Siri (FUNC-07)
- Widget interactivo (FUNC-08)
- Escaneo de código de barras (FUNC-09)

---

## 📁 ARCHIVOS DEL PROYECTO (Referencia)

### Models
- `ShoppingItem.swift` — Modelo principal con SwiftData
- `Category.swift` — Enum de categorías + modelo SwiftData
- `ShoppingList.swift` — Lista de compra (activa/completada)
- `Store.swift` — Supermercados con geolocalización
- `ProductCatalogItem.swift` — Catálogo de productos frecuentes
- `SuggestedProducts.swift` — Base de datos de ~290 productos sugeridos
- `UserStats.swift` — Gamificación y logros

### ViewModels
- `ShoppingListViewModel.swift` — Lógica de filtrado, agrupación y acciones
- `ShoppingModeViewModel.swift` — Estado y lógica de sesión de compra

### Views
- `ContentView.swift` — Punto de entrada principal
- `ShoppingListView.swift` — Lista con filtros y barra de entrada
- `AddEditItemSheet.swift` — Modal crear/editar producto
- `ShoppingModeView.swift` — Modo compra pantalla completa
- `ShoppingModeActiveView.swift` — Sesión activa de compra
- `CompletionCelebrationView.swift` — Pantalla de celebración
- `SettingsSheet.swift` — Ajustes de accesibilidad y configuración
- `ShoppingHistoryView.swift` — Historial de compras
- `ShoppingHistoryDetailView.swift` — Detalle de compra archivada
- `CategorySectionView.swift` — Sección agrupada por categoría
- `ItemRowView.swift` — Fila individual de producto
- `EmptyStateView.swift` — Estado vacío
- `AchievementsView.swift` — Logros y estadísticas
- `CategoryManagementView.swift` — Admin de categorías

### Components
- `BottomAddBarView.swift` — Barra de entrada rápida
- `StoreFilterBar.swift` — Filtro por supermercado
- `SummaryBarView.swift` — Resumen de conteos
- `ShoppingModeItemRow.swift` — Fila en modo compra
- `ShoppingModeHeaderView.swift` — Header del modo compra
- `VoiceNotePlayerButton.swift` — Botón de reproducción de audio
- `SuggestionsListView.swift` — Chips de sugerencias
- `NoResultsView.swift` — Sin resultados de búsqueda
- `CategoryPickerView.swift` — Selector visual de categorías
- `AddEditVoiceNoteSection.swift` — Sección de notas de voz

### Services
- `AppSettings.swift` — Configuraciones observables
- `VoiceNoteService.swift` — Grabación y reproducción de audio
- `GeofenceService.swift` — Alertas geolocalizadas
- `ShoppingListLifecycleService.swift` — Ciclo de vida de listas
- `CategoryIconMapper.swift` — Mapeo inteligente de iconos
- `WidgetDataBridge.swift` — Puente con widget
- `CategoryBootstrapService.swift` — Inicialización de categorías

### Theme
- `Theme.swift` — Sistema de diseño, colores, fuentes, animaciones, Liquid Glass, haptics

---

*Este documento sirve como prompt de auditoría para que un agente de IA pueda revisar el proyecto de forma sistemática y generar un reporte detallado de hallazgos.*
