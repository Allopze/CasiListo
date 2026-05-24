# Auditoría integral de la app

## Resumen ejecutivo

CasiListo tiene una base sólida: SwiftUI + SwiftData, categorías, supermercados, modo compra, historial, notas de voz, geofencing, entrada rápida, precios y tests iniciales. La app ya apunta a un caso de uso real de supermercado y tiene buena intención de producto.

Los riesgos más importantes están en consistencia de datos, persistencia explícita, duplicados, historial parcialmente incoherente, exceso de lógica en vistas y una experiencia inicial demasiado cargada por el seeding automático de productos como ítems pendientes.

Verificación técnica: `xcodebuild build -project CasiListo.xcodeproj -scheme CasiListo -destination 'generic/platform=iOS Simulator' -quiet` terminó correctamente. La ejecución de tests en simulador no completó: falló la fase de launch del simulador con `NSMachErrorDomain Code -308`, así que no pude validar la suite completa en runtime.

### Actualización de fixes aplicados

Fecha de actualización: 2026-05-24.

Se aplicó una primera tanda de correcciones priorizadas enfocada solo en pulir la app y cerrar bugs/riesgos; no se añadieron nuevas funcionalidades de producto. Cambios realizados:

- Se bajó el deployment target del proyecto y tests de iOS 26.5 a iOS 17.0 en `CasiListo.xcodeproj/project.pbxproj`, manteniendo los usos de Liquid Glass detrás de `#available(iOS 26, *)`.
- Se añadió guardado explícito con `context.safeSave()` al marcar/desmarcar productos, cambiar estado, eliminar productos, limpiar comprados y guardar productos desde el modal.
- Se añadió detección de duplicados normalizada por nombre y supermercado en `ShoppingListViewModel`.
- La barra rápida ahora evita crear duplicados; si el duplicado no tenía cantidad y la entrada rápida sí, actualiza esa cantidad en vez de insertar otro producto.
- El modal de añadir/editar ahora deshabilita guardado si hay duplicado o precio inválido y muestra feedback textual.
- El historial archivado ahora mantiene coherencia entre resumen y detalle: si solo se archivan comprados, los contadores de pendientes/pospuestos/no encontrados del registro histórico quedan en cero.
- Los contadores de la lista activa se recalculan desde SwiftData tras archivar, evitando errores cuando se archiva solo una tienda.
- El modo compra ahora registra estadísticas y resumen de celebración usando productos realmente comprados, no `totalCount`.
- El geofencing ahora cuenta solo productos pendientes de la lista activa, evitando notificaciones por ítems históricos.
- Las notas de voz temporales se limpian al cancelar el sheet; al editar, eliminar una nota persistida ya no borra el archivo antes de guardar.
- `VoiceNotePlayerButton` respeta Reduce Motion en la animación del waveform.
- `ItemRowView` suma acciones VoiceOver directas para editar, posponer y marcar como no encontrado.
- Se añadieron tests unitarios para duplicados normalizados y estadísticas de modo compra; se ajustó el test de historial al comportamiento corregido.

Verificación posterior:

- `xcodebuild build -project CasiListo.xcodeproj -scheme CasiListo -destination 'generic/platform=iOS Simulator' -quiet`: OK.
- `xcodebuild build-for-testing -project CasiListo.xcodeproj -scheme CasiListo -destination 'generic/platform=iOS Simulator' -quiet`: OK.
- `xcodebuild test ... -only-testing:CasiListoTests`: no llegó a ejecutar tests por fallo del launcher del simulador (`NSMachErrorDomain Code -308`, `IDELaunchiPhoneSimulatorLauncher`). Se interrumpió para no dejar `xcodebuild` vivo.

## Diagnóstico general

- Lógica de negocio: 7/10. Crear, editar, marcar y agrupar existe, pero faltan duplicados, validaciones y guardado explícito.
- Arquitectura: 6/10. Hay MVVM parcial, pero varias vistas persisten datos directamente y servicios estáticos/globales concentran lógica.
- UI/UX: 7/10. Buena dirección visual y modo compra útil, pero hay demasiadas acciones escondidas y filas sobrecargadas.
- Accesibilidad: 6/10. Hay labels y Dynamic Type, pero existe doble escalado y faltan acciones VoiceOver relevantes.
- Rendimiento: 7/10. Suficiente para cientos de ítems; puede degradar por recomputar agrupaciones/resúmenes en cada render.
- Persistencia: 6/10. SwiftData está bien integrado, pero se depende demasiado de autosave y de `listID` manual.
- Calidad del código: 6/10. Código legible, pero archivos muy grandes y responsabilidades mezcladas.
- Testabilidad: 5/10. Tests unitarios útiles, UI tests mínimos; faltan casos borde importantes.
- Escalabilidad del producto: 6/10. Buenas ideas, pero el modelo actual limita listas múltiples, colaboración e historial rico.

## Problemas críticos encontrados

### 1. Deployment target en iOS 26.5 contradice README y bloquea dispositivos

Estado: corregido en la primera tanda de fixes. El target quedó en iOS 17.0.

- Descripción: el README declara iOS 17+, pero el proyecto exige iOS 26.5.
- Impacto: la app no corre en dispositivos con iOS 26.4.2 o anteriores. `xcodebuild -showdestinations` marcó un iPhone físico como inelegible por no llegar a 26.5.
- Evidencia en la repo: `CasiListo.xcodeproj/project.pbxproj`, `README.md`.
- Archivos o componentes afectados: configuración del proyecto, distribución, QA.
- Severidad: crítica.
- Cómo reproducirlo: ejecutar `xcodebuild -project CasiListo.xcodeproj -scheme CasiListo -showdestinations` y revisar destinos inelegibles.
- Solución recomendada: bajar `IPHONEOS_DEPLOYMENT_TARGET` al mínimo real soportado, probablemente 17.0, y mantener los `#available(iOS 26, *)` como fallback visual.
- Esfuerzo estimado: bajo.

### 2. Primer inicio llena la lista activa con productos sugeridos

- Descripción: en el primer `.task`, si no hay ítems o no existe `hasSeededDefaultProducts`, se insertan productos sugeridos como `ShoppingItem` reales.
- Impacto: el usuario abre una app de lista de compra y encuentra una compra gigante ya pendiente. Eso mezcla catálogo, plantilla y lista real.
- Evidencia en la repo: `ContentView.swift`, `SuggestedProducts.swift`.
- Archivos o componentes afectados: `ContentView`, `SuggestedProducts`, lista activa, onboarding.
- Severidad: alta.
- Cómo reproducirlo: instalar limpio, abrir app, observar que `EmptyStateView` no aparece porque se crean ítems automáticamente.
- Solución recomendada: sembrar solo `ProductCatalogItem`; ofrecer “Empezar vacío”, “Usar plantilla” o “Añadir frecuentes”.
- Esfuerzo estimado: medio.

### 3. No hay prevención de productos duplicados

Estado: corregido parcialmente. Ya existe detección normalizada por nombre y supermercado en barra rápida y modal. Pendiente: decidir UX final para “fusionar” duplicados con cantidades/precios en vez de solo bloquear.

- Descripción: `AddEditItemSheet.isValid` solo valida que el nombre no esté vacío; `addQuickItem()` tampoco busca coincidencias normalizadas.
- Impacto: el usuario puede añadir “Leche”, “ leche ”, “LECHE” y “Leche” varias veces en la misma tienda/categoría.
- Evidencia en la repo: `AddEditItemSheet.swift`, `ShoppingListView.swift`.
- Archivos o componentes afectados: creación rápida, modal de añadir/editar, modelo de lista.
- Severidad: alta.
- Cómo reproducirlo: añadir dos veces el mismo producto desde la barra rápida o modal.
- Solución recomendada:

```swift
func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()
}

func existingDuplicate(for name: String, store: Store, in items: [ShoppingItem]) -> ShoppingItem? {
    let target = normalized(name)
    return items.first { normalized($0.name) == target && $0.store == store && $0.status == .pending }
}
```

- Esfuerzo estimado: bajo-medio.

### 4. Historial puede mostrar conteos que no coinciden con el detalle

Estado: corregido para el comportamiento actual. El historial solo cuenta los productos efectivamente archivados. Pendiente futuro: diseñar snapshot completo de sesión si se quiere guardar también pospuestos/no encontrados.

- Descripción: `archivePurchasedItems` crea una lista completada con `pendingCount`, `skippedCount` y `unavailableCount` calculados desde todos los ítems recibidos, pero solo reasigna al historial los ítems comprados.
- Impacto: el historial puede decir “3 pendientes” pero el detalle no muestra esos productos porque siguen en la lista activa.
- Evidencia en la repo: `ShoppingListLifecycleService.swift`, `ShoppingHistoryDetailView.swift`.
- Archivos o componentes afectados: historial, archivo de compras, detalle de historial.
- Severidad: alta.
- Cómo reproducirlo: tener comprados y pendientes, archivar comprados, abrir historial y comparar resumen con detalle.
- Solución recomendada: decidir si el historial es “solo comprados archivados” o “snapshot completo de la sesión”. Para una app de compra, recomiendo snapshot completo con estado final.
- Esfuerzo estimado: medio.

## Bugs o riesgos funcionales

- Bug corregido: target iOS 26.5 bloqueaba dispositivos y contradecía documentación.
- Bug corregido/parcial: se podían crear duplicados sin aviso; ahora se bloquean por nombre normalizado y supermercado.
- Bug corregido: historial guardaba conteos de estados no archivados.
- Bug corregido: notas de voz podían quedar huérfanas si el usuario grababa y cancelaba el modal.
- Bug corregido: cambios en lista normal no llamaban `context.safeSave()` al marcar, borrar o cambiar estado.
- Bug corregido: estadísticas de modo compra contaban `totalCount`, incluyendo pospuestos/no encontrados, como productos comprados.
- Riesgo técnico: `listID` manual puede dejar ítems huérfanos o mal asignados si hay futuras listas múltiples.
- Caso borde corregido: precio inválido se convertía silenciosamente en `nil`; ahora bloquea el guardado y muestra feedback.
- Caso borde corregido: geofencing contaba cualquier `ShoppingItem` pendiente de esa tienda; ahora filtra por lista activa.

## Malas prácticas detectadas

- Persistencia repartida en Views. `AddEditItemSheet`, `ShoppingListView` y `CategoryManagementView` insertan/modifican SwiftData directamente. Importa porque complica testear reglas de negocio. Alternativa: `ShoppingListRepository` o `ShoppingListService` inyectable.
- Uso de `Double` para dinero. Importa por precisión y formato. Alternativa: guardar centavos como `Int` o `Decimal`.
- Archivos demasiado grandes frente a la propia norma del README. `SettingsSheet.swift` tiene 475 líneas, `Theme.swift` 386, `ShoppingListViewModel.swift` 342. Alternativa: dividir por secciones/componentes.
- `try?` silencia errores críticos en varias rutas de persistencia. Alternativa: usar `safeSave()` con logging y feedback UI cuando aplique.
- Estado global en servicios singleton: `GeofenceService.shared`, `VoiceNoteService.shared`. Útil para una app pequeña, pero reduce testabilidad.

## Inconsistencias detectadas

- README dice 9 categorías y cerca de 90 productos; el código tiene 15 categorías y bastantes más productos.
- README dice iOS 17+; proyecto exige 26.5.
- “Líder” aparece con tilde en `Store`, pero algunos textos dicen “Lider” sin tilde en onboarding.
- “Limpiar Comprados” realmente archiva comprados; el texto puede sugerir borrado definitivo.
- `ShoppingModeViewModel.progress` usa comprados/total, pero la sesión termina cuando no quedan pendientes; si hay pospuestos/no encontrados, la compra puede completarse sin 100%.
- El historial puede mostrar pendientes/pospuestos/no encontrados en resumen, pero el detalle puede contener solo comprados.

## Revisión UI/UX

### Lo que funciona bien

- Entrada rápida abajo de la pantalla: buen patrón para uso de una mano.
- Modo compra separado y oscuro: ayuda a concentrarse en el supermercado.
- Agrupación por categorías con colapso: útil para listas largas.
- Filtro por supermercado: bien alineado con compras reales.
- Haptics y microinteracciones dan sensación de app cuidada.

### Problemas de UI

- `ItemRowView` mete nombre, tienda, cantidad, precio y estado en un solo `HStack`, con alto riesgo de truncamiento en Dynamic Type.
- Las acciones principales están repartidas entre toolbar, menú, swipe y context menu.
- El botón “Comprar” usa estilo prominente, pero los estilos glass mezclan botones circulares y cápsulas de forma no siempre consistente.
- Mucha sombra/card en listas largas puede bajar densidad y escaneabilidad.

### Problemas de UX

- El primer inicio no se siente como “crear mi lista”, sino como administrar una lista enorme.
- Archivar comprados está escondido en el menú.
- Posponer/no encontrado existen, pero son poco descubiertos fuera del modo compra.
- No hay undo tras eliminar.
- No hay flujo claro para “terminé la compra pero mantén pendientes/no encontrados”.

### Mejoras recomendadas

- Primera apertura: lista vacía + chips de frecuentes + CTA “usar plantilla”.
- Fila en dos niveles: línea principal con nombre; segunda línea con chips de tienda/cantidad/precio/estado.
- CTA visible “Archivar comprados” cuando haya comprados.
- Undo para eliminar.
- Pantalla final de compra con resumen por estados: comprados, pendientes, pospuestos, no encontrados.

### Cambios rápidos de alto impacto

- Bajar deployment target.
- Añadir detección de duplicados.
- Guardar explícitamente tras marcar/borrar/editar.
- Cambiar “Limpiar Comprados” a “Archivar comprados”.
- Añadir custom VoiceOver action “Editar” en la fila.

## Revisión de accesibilidad

Problemas detectados:

- Doble escalado: se usa `@ScaledMetric` y además `accessibilityTextSizeScale`.
- Falta acción VoiceOver “Editar” en la fila principal.
- `VoiceNotePlayerButton` anima waveform sin revisar Reduce Motion.
- Algunos estados se comunican visualmente como chips, pero no siempre como acciones accesibles principales.
- Iconos de filtros dependen de color + texto; conviene reforzar valores seleccionados en todos los pickers.

Solución ejemplo:

```swift
.accessibilityAction(named: "Editar") {
    onEdit()
}
.accessibilityAction(named: "Posponer") {
    onMarkStatus(.skipped)
}
.accessibilityAction(named: "Marcar no encontrado") {
    onMarkStatus(.unavailable)
}
```

## Revisión técnica

- Arquitectura: MVVM parcial; la lógica de guardado debería salir de las Views.
- Estado: `ShoppingListViewModel` mezcla estado UI, filtros, navegación modal y reglas.
- Modelos: `ShoppingItem` es claro, pero `isPurchased` + `statusRawValue` duplican estado y pueden divergir.
- ViewModels: buena base con `@Observable`, pero faltan comandos con persistencia explícita.
- Views: varias son demasiado grandes y hacen demasiado.
- Servicios: útiles, pero `GeofenceService` y `VoiceNoteService` son difíciles de testear por singleton.
- Persistencia: SwiftData correcta, pero `listID` manual necesita más invariantes y tests.
- Dependencias: sin dependencias externas, positivo.
- Tests: cubren cálculos y algo de UI, pero no los flujos más riesgosos.
- Rendimiento: agrupaciones, conteos y filtros se recalculan con frecuencia; aceptable ahora, mejorable con snapshots.

## Recomendaciones de refactor

### 1. Cambiar persistencia a un servicio/repositorio de lista

- Qué cambiar: mover `insert`, `delete`, `archive`, `toggle`, `duplicate check`.
- Por qué: hoy la lógica está repartida en Views y ViewModels.
- Beneficio: reglas testeables.
- Riesgo: medio.
- Esfuerzo: medio.
- Archivos afectados: `ShoppingListView.swift`, `AddEditItemSheet.swift`, `ShoppingListViewModel.swift`.

### 2. Separar catálogo de lista activa

- Qué cambiar: dejar `SuggestedProducts.seedCatalogItems` y eliminar `seedDefaultItems` automático.
- Por qué: catálogo y lista real son conceptos distintos.
- Beneficio: UX limpia y datos coherentes.
- Riesgo: medio por cambio de onboarding.
- Esfuerzo: medio.
- Archivos afectados: `ContentView.swift`, `SuggestedProducts.swift`.

### 3. Rediseñar historial como snapshot

- Qué cambiar: archivar todos los ítems de una sesión con estado final o guardar un modelo `ShoppingHistoryItem`.
- Por qué: el historial debe representar lo que pasó en una compra, no solo productos comprados sueltos.
- Beneficio: historial confiable.
- Riesgo: alto si ya hay datos instalados.
- Esfuerzo: medio-alto.
- Archivos afectados: `ShoppingListLifecycleService.swift`, `ShoppingHistoryDetailView.swift`.

### 4. Dividir `SettingsSheet`

- Qué cambiar: componentes `AccessibilitySettingsSection`, `LocationSettingsSection`, `CategorySettingsSection`.
- Por qué: el archivo concentra demasiadas responsabilidades.
- Beneficio: mantenibilidad.
- Riesgo: bajo.
- Esfuerzo: bajo-medio.
- Archivos afectados: `SettingsSheet.swift`.

### 5. Normalizar precios

- Qué cambiar: `priceInCents: Int?` o `Decimal`.
- Por qué: `Double` no es ideal para dinero.
- Beneficio: precisión.
- Riesgo: migración de datos.
- Esfuerzo: medio.
- Archivos afectados: `ShoppingItem.swift`, `AddEditItemSheet.swift`, vistas de resumen/historial.

## Tests recomendados

- `testAddQuickRejectsDuplicatePendingItem`: unitario; valida duplicados normalizados.
- `testAddEditInvalidPriceDoesNotEraseExistingPrice`: unitario; evita pérdida silenciosa de precio.
- `testTogglePurchasedPersistsImmediately`: integración SwiftData; valida guardado explícito.
- `testArchivePurchasedHistoryCountsMatchDetailItems`: integración; cubre la incoherencia actual.
- `testArchiveStoreOnlyDoesNotMoveOtherStoreItems`: integración; valida compras por supermercado.
- `testVoiceNoteDeletedWhenAddSheetIsCancelled`: integración/manual; evita archivos huérfanos.
- `testShoppingModeCompletionWithSkippedItems`: unitario; valida fin de sesión con pospuestos/no encontrados.
- `testGeofenceCountsOnlyActivePendingItems`: unitario/integración; evita notificaciones por datos históricos.
- `testDynamicTypeAccessibilityXXXLDoesNotClipRows`: UI snapshot/regresión.
- `testCreateEditDeleteProductFlow`: UI; cubre flujo básico.
- `testHistoryDetailMatchesArchivedSummary`: UI; evita regresión de historial.

## Mejoras de producto

### Productos frecuentes

- Problema que resuelve: añadir repetidos.
- Cómo funcionaría: ordenar sugerencias por uso y última compra.
- Valor para el usuario: alto.
- Dificultad técnica: media.
- Dependencias técnicas: `ProductCatalogItem.timesAdded`, historial.
- Riesgos: sugerencias irrelevantes si no se normalizan nombres.
- Prioridad recomendada: P0.

### Categorías automáticas aprendidas

- Problema que resuelve: reduce categorización manual.
- Cómo funcionaría: al escribir, la app sugiere categoría y aprende correcciones.
- Valor para el usuario: alto.
- Dificultad técnica: media.
- Dependencias técnicas: catálogo persistente, normalización.
- Riesgos: asignaciones erróneas si se aprende demasiado agresivamente.
- Prioridad recomendada: P0.

### Orden por pasillos o secciones del supermercado

- Problema que resuelve: evita caminar de más.
- Cómo funcionaría: cada tienda define orden de categorías.
- Valor para el usuario: alto.
- Dificultad técnica: media.
- Dependencias técnicas: modelo de tienda/secciones.
- Riesgos: cada supermercado puede tener distribución distinta.
- Prioridad recomendada: P0.

### Importar lista desde texto

- Problema que resuelve: copiar listas desde WhatsApp, notas o mensajes.
- Cómo funcionaría: pegar texto multilinea y parsear producto/cantidad.
- Valor para el usuario: alto.
- Dificultad técnica: baja-media.
- Dependencias técnicas: parser simple, UI de confirmación.
- Riesgos: parsing ambiguo.
- Prioridad recomendada: P1.

### Añadir por voz

- Problema que resuelve: uso con manos ocupadas.
- Cómo funcionaría: dictado para crear varios productos.
- Valor para el usuario: alto.
- Dificultad técnica: media.
- Dependencias técnicas: Speech framework o dictado nativo.
- Riesgos: permisos y reconocimiento incorrecto.
- Prioridad recomendada: P1.

### Presupuesto estimado

- Problema que resuelve: control de gasto.
- Cómo funcionaría: suma precios y alerta umbral.
- Valor para el usuario: medio-alto.
- Dificultad técnica: baja.
- Dependencias técnicas: normalización de dinero.
- Riesgos: precios desactualizados.
- Prioridad recomendada: P1.

### Plantillas de listas

- Problema que resuelve: compras repetidas.
- Cómo funcionaría: “semanal”, “asado”, “limpieza”.
- Valor para el usuario: alto.
- Dificultad técnica: media.
- Dependencias técnicas: separación catálogo/lista.
- Riesgos: plantillas demasiado rígidas.
- Prioridad recomendada: P1.

### Widgets/App Intents

- Problema que resuelve: acceso rápido.
- Cómo funcionaría: ver pendientes y añadir producto desde iOS.
- Valor para el usuario: medio-alto.
- Dificultad técnica: media-alta.
- Dependencias técnicas: AppIntents, WidgetKit.
- Riesgos: sincronización de datos con SwiftData.
- Prioridad recomendada: P2.

### iCloud/listas compartidas

- Problema que resuelve: compras familiares.
- Cómo funcionaría: sincronización CloudKit y colaboración.
- Valor para el usuario: alto.
- Dificultad técnica: alta.
- Dependencias técnicas: CloudKit, conflictos, identidad.
- Riesgos: sincronización y resolución de conflictos.
- Prioridad recomendada: P2.

### Escaneo de códigos de barra

- Problema que resuelve: entrada precisa.
- Cómo funcionaría: cámara detecta código y busca producto.
- Valor para el usuario: medio.
- Dificultad técnica: alta.
- Dependencias técnicas: AVFoundation, base de productos/API.
- Riesgos: catálogo incompleto.
- Prioridad recomendada: P3.

## Roadmap recomendado

### Versión 1.1 — Calidad y correcciones

- Bajar deployment target.
- Guardado explícito en marcar/borrar/editar.
- Detección de duplicados.
- Corregir historial y conteos.
- Eliminar huérfanos de notas de voz al cancelar.
- Pulir textos y acentos.

### Versión 1.2 — Mejoras de experiencia

- Rediseñar fila de producto.
- CTA visible para archivar.
- Undo al eliminar.
- Mejor entrada rápida con parsing visible.
- Modo ordenar más descubrible.
- Accesibilidad VoiceOver completa.

### Versión 1.3 — Funciones inteligentes

- Sugerencias por frecuencia.
- Categorías aprendidas.
- Plantillas.
- Importar desde texto.
- Orden por pasillos.

### Versión 2.0 — Evolución avanzada

- iCloud/CloudKit.
- Listas compartidas.
- Widgets/App Intents.
- Siri/voz.
- Escaneo de códigos.
- Recordatorios por ubicación más configurables.

## Checklist final de acciones

### Hacer ahora

- Revisar manualmente en simulador/dispositivo los flujos corregidos: duplicados, archivo, notas de voz, geofencing y modo compra.
- Resolver el fallo del launcher del simulador para poder ejecutar `xcodebuild test` completo.
- Añadir tests específicos para notas de voz temporales y precio inválido.
- Decidir si el primer inicio seguirá sembrando productos como lista activa o se separará en onboarding/catalogo.
- Seguir reduciendo doble escalado en las filas principales.

### Hacer después

- Separar catálogo de lista activa.
- Refactorizar persistencia fuera de Views.
- Rediseñar fila de producto.
- Mejorar modo compra y cierre de sesión.
- Dividir `SettingsSheet`.

### Considerar más adelante

- iCloud y listas compartidas.
- Widgets/App Intents.
- Orden por pasillos avanzado.
- Escaneo de código de barras.
- Voz e importación inteligente desde texto.
