# Auditoria UI/UX, producto y SwiftUI - CasiListo

Fecha original: 2026-05-24  
Última actualización: 2026-05-24  
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

- `ItemRowView` rediseñado con dos niveles: nombre en línea propia, chips (tienda, cantidad, precio, estado) en segunda línea. Reduce saturación horizontal y mejora escaneabilidad.
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

---

## Resumen ejecutivo

CasiListo ya tiene una base de producto fuerte para una app de lista de compra: SwiftData, lista activa e historial, entrada rápida, búsqueda, categorías, supermercado, modo compra, notas de voz, geofencing, resumen de gasto y uso moderno de `@Observable`, `@Bindable`, `sheet(item:)` y wrappers Liquid Glass.

El mayor riesgo no es técnico de compilación, sino de experiencia: la app contiene muchas capacidades, pero varias quedan ocultas o se sienten poco cerradas en el flujo principal. Crear/añadir/marcar funciona, pero completar una compra, organizar productos, manejar pendientes/no encontrados y consultar historial tienen fricciones o inconsistencias de modelo visual.

---

## Problemas críticos — estado actual

### 1. El primer inicio crea cientos de productos pendientes ⚠️ PENDIENTE (decisión de producto)

- Descripción: `ContentView.task` inserta productos por defecto cuando no hay ítems o no existe `hasSeededDefaultProducts`. `SuggestedProducts.seedDefaultItems` crea `ShoppingItem` reales en la lista activa.
- Impacto: el primer uso parece una compra gigante ya cargada, dificultando entender qué es pendiente real y qué es sugerencia.
- Recomendación: separar catálogo de sugerencias de ítems activos. Ofrecer onboarding con "Empezar vacío", "Usar plantilla", "Añadir frecuentes".
- Severidad: alta. **Decisión de producto requerida.**

### 2. Completar compra con estados reales ✅ RESUELTO

`checkCompletion()` usa `actionableCount == 0`: la sesión termina cuando no quedan ítems accionables, incluso si hay pospuestos o no encontrados. `stopSession()` ya se llama correctamente al salir.

### 3. Organizar productos oculto y sin indicador de alcance ⚠️ PENDIENTE

- El modo ordenar está en el menú y no tiene affordance visual (handles, estado explícito, texto de alcance por categoría).
- El reordenamiento solo funciona dentro de una categoría — no está comunicado.
- Recomendación: modo ordenar explícito con handles visibles, estado `"Ordenando"` y texto de cabecera de alcance.
- Severidad: media-alta.

### 4. Fila de producto ✅ RESUELTO (sesión 1)

Layout de dos niveles implementado. Nombre en línea propia, chips en segunda fila.

### 5. Acciones importantes repartidas entre toolbar, menú, swipe y context menu ⚠️ PARCIALMENTE RESUELTO

- CTA "Archivar comprados" ahora es visible en `SummaryBarView`. ✅
- Historial sigue enterrado en el menú. Pendiente hacerlo accesible.
- Severidad: media.

### 6. Doble escalado accesible ✅ RESUELTO

Eliminado en todas las vistas afectadas (sesiones 1 y 2).

### 7. Counters de lista activa tras archivar ✅ RESUELTO

`archivePurchasedItems` usa `fetchItems(in:fallback:)` para recalcular counters desde el contexto real tras mutar `listID`.

---

## Mejoras de UI — estado

- **Reducir ruido de tarjetas y sombras** ⚠️ pendiente
- **Rehacer la fila principal como componente escaneable** ✅ resuelto (dos niveles)
- **Botón lápiz vs Menu en la fila** ⚠️ pendiente — en lista de compra, la acción más frecuente es marcar, no editar; el lápiz ocupa espacio
- **Resumen más útil (SummaryBarView)** ⚠️ parcialmente resuelto — CTA visible, pero podría mostrar estimado de gasto más prominente
- **Color por estado más allá de texto** ⚠️ pendiente
- **shoppingModeButton ya usa cápsula** ✅ confirmado — usa `adaptiveGlassProminentButtonStyle`

---

## Mejoras de accesibilidad — estado

- **VoiceOver: acciones "Posponer" y "No encontrado" en ShoppingModeItemRow** ✅ ya existían (líneas 74-82)
- **VoiceOver: acción "Editar" como custom action en ItemRowView** ✅ ya existía
- **Dynamic Type / doble escalado** ✅ resuelto
- **Touch targets** ⚠️ pendiente — consolidar helper `minimumHitArea`
- **Contraste: opacidades adicionales sobre textos pequeños** ⚠️ pendiente
- **Reduce Motion en confetti y waveform** ⚠️ pendiente — revisar que todas las animaciones respeten `accessibilityReduceMotion`
- **Textos localizados y acentos** ✅ corregidos en vistas principales; puede quedar alguno en historial

---

## Observaciones técnicas — estado

- **Build**: compila correctamente con Swift 6, iOS Simulator 26.5. ✅
- **Concurrencia**: `stopSession()` ya se llama al salir del modo compra. ✅
- **Performance**: `groups` y `summary` se recalculan en cada render en `ShoppingListView`. Para listas grandes conviene un snapshot derivado. ⚠️ pendiente
- **Fan-out de observación**: `ShoppingListView` recibe `ShoppingListViewModel` como `@Bindable`. Pasar solo valores derivados reduciría invalidaciones. ⚠️ pendiente
- **Persistencia**: `togglePurchased` y `markItem` llaman `context?.safeSave()`. ✅
- **Precio como Double**: debería ser `Decimal` o entero de centavos para evitar imprecisión flotante. ⚠️ pendiente
- **`AddEditItemSheet` desacoplado** del ViewModel completo. ✅
- **Sheets**: `sheet(item:)` usado correctamente en `ContentView`. ✅
- **Tests**: siguen sin suite ejecutable — ver sección de siguientes pasos.

---

## Siguientes pasos naturales

### Alta prioridad

1. **Modo ordenar explícito** — handles visibles, estado `"Ordenando"`, texto de alcance por categoría. Hoy el usuario no sabe que el drag solo funciona dentro de su categoría.
2. **Historial más accesible** — moverlo de menú a tab, o mostrar tarjeta "Última compra" en el estado vacío. Hoy está enterrado.
3. **Decisión de producto: seeding inicial** — definir si mantener sugerencias como ítems activos o moverlas a catálogo separado. Bloquea el flujo de primer uso.

### Prioridad media

1. **Snapshot derivado** — calcular `groups` y `summary` una vez por cambio de datos en vez de en cada render. Relevant para listas grandes.
2. **Precio como Decimal** — migración de `Double` a `Decimal` o entero de centavos en `ShoppingItem` para evitar errores de redondeo al mostrar totales.
3. **Resumen de compra al finalizar** — `CompletionCelebrationView` muestra comprados y gasto; añadir pospuestos y no encontrados al resumen.
4. **Touch targets consolidados** — helper `minimumHitArea(44)` aplicado consistentemente; auditar controles pequeños en modo compra.
5. **Contraste y opacidades** — revisar textos secundarios con opacidad adicional sobre chips pequeños; puede quedar bajo 4.5:1.
6. **Reduce Motion completo** — asegurarse que confetti, waveform del reproductor de voz y animaciones de completado respetan `accessibilityReduceMotion`.

### Prioridad baja / futuro

1. **Tests unitarios e integración** — parseo de entrada rápida, archivado, historial, estados pospuesto/no encontrado, modo compra.
2. **Sugerencias por frecuencia/prefijo** — hoy usa `contains`; ordenar por prefijo exacto y frecuencia histórica.
3. **iCloud sync / CloudKit** — base para listas compartidas.
4. **App Intents / Siri** — añadir productos sin abrir la app.
5. **Widget** — ver pendientes desde pantalla de inicio.
6. **Presupuesto estimado vs real** — comparar suma de precios estimados con total final.

---

## Lista priorizada de acciones (original, estado actualizado)

### 1. Cambios rápidos de alto impacto

1. ~~Desactivar seeding automático~~ ⚠️ decisión de producto pendiente
2. ~~Corregir cierre de modo compra~~ ✅ resuelto
3. ~~Agregar acciones VoiceOver en ShoppingModeItemRow~~ ✅ ya existían
4. ~~Cambiar shoppingModeButton a cápsula~~ ✅ ya era cápsula
5. ~~Agregar CTA visible "Archivar comprados"~~ ✅ resuelto
6. ~~Evitar doble escalado~~ ✅ resuelto (sesiones 1 y 2)
7. ~~Llamar stopSession() al salir~~ ✅ resuelto
8. ~~Pulir copy y acentos~~ ✅ resuelto

### 2. Mejoras importantes de mediano esfuerzo

1. ~~Rediseñar fila de producto con dos niveles~~ ✅ resuelto
2. Crear snapshot derivado para grupos y resumen ⚠️ pendiente
3. Hacer modo ordenar explícito con handles y alcance ⚠️ pendiente
4. Rediseñar cierre de compra con resumen completo (pospuestos, no encontrados) ⚠️ pendiente
5. Ordenar sugerencias por frecuencia y prefijo ⚠️ pendiente
6. Mejorar historial con acceso más visible y filtros ⚠️ pendiente
7. Tests de flujos principales ⚠️ pendiente

### 3. Mejoras avanzadas o de mayor alcance

1. Listas compartidas con iCloud/CloudKit
2. Motor de pasillos/secciones configurable por supermercado
3. Presupuesto estimado persistente
4. Widgets y App Intents
5. Escaneo de códigos de barra
6. Recetas/planificación de comidas conectadas con lista
