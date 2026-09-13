# CasiListo — Production & App Store Audit

> **Fecha:** 2026-09-12 · **Rama:** `main` · **Commit base:** `caa669a`
> **Método:** auditoría sobre el código real, no sobre la documentación. Se compilaron los 4 targets,
> se ejecutó la suite completa, se lanzó la app en el simulador y se verificó en disco la ubicación
> de la base SwiftData y el contenido publicado al App Group.
>
> **Nota de alcance:** el encargo describía Swift 5.9, iOS 17+, Core Location y un «modo compra de
> pantalla completa». Nada de eso coincide con el código: el piso real es **iOS 26.0**, Swift 6.0 con
> `SWIFT_STRICT_CONCURRENCY = complete`, **cero CoreLocation** en el árbol y no existe un modo compra
> separado. Lo que sigue audita lo que hay.

---

## 1. Executive Summary

CasiListo **no es el prototipo que describe el brief**. Auditar lo que hay, no lo que se declaró,
cambia mucho el veredicto.

Lo que hay es un producto **sorprendentemente maduro**. Compila limpio los 4 targets. 142 tests, de
los cuales ~80 cubren el pipeline de OCR de boletas contra tres boletas chilenas reales que se
autovalidan contra su propio total impreso. Cero red, cero analytics, cero SDK externos — verificado
por grep exhaustivo, y la promesa de «app local» es literalmente cierta. Los manifiestos de
privacidad son correctos y hay un script de CI que los valida. Los purpose strings de cámara y
micrófono son específicos y honestos. El permiso de micrófono se pide en el punto de uso, no al
arranque. El icono es válido (1024², sin alfa, con variantes dark y tinted). El sistema de color
calcula contraste WCAG en tiempo real y hay tests que lo asertan.

La integridad de datos está tomada en serio: un coordinador transaccional único, barrido de archivos
huérfanos, banner visible cuando el store no abre, y comentarios en el código que citan el bug
concreto que motivó cada línea. Verificado en runtime un primer arranque limpio: 355 productos de
catálogo, 15 categorías, 0 listas, determinista.

**Pero no se puede publicar hoy, por dos razones de hecho.**

Primera: **el pipeline de release nunca se ha ejecutado, ni una vez**. `release-testflight.yml` es
`workflow_dispatch` y nunca corrió; `gh` no está instalado; la propia auditoría del proyecto marca
F-20 como abierto. No existe ni ha existido nunca un archive firmado, un `.ipa`, ni una subida.
Depende por completo de firma automática sin certificado importado.

Segunda: **la suite de tests del árbol de trabajo está roja**.
`TempUpgradeDupRefutationTests.testUpgradeFreezesExistingDuplicates` falla (exit 65). Es uno de dos
archivos de test temporales sin commitear marcados como «TEMPORAL — borrar». El gate de CI del PR
fallaría.

Además se confirmó en runtime un hallazgo que el código intenta explícitamente evitar: **el widget
nunca muestra su estado vacío**. La app publica un snapshot de ceros con `updatedAt = .now` en el
primer arranque, así que `isPlaceholder` es falso para siempre y el mensaje «Abre CasiListo para
empezar» es código muerto. Un usuario sin listas ve un rotundo «0 pendientes».

Y un riesgo latente verificado en disco: la base SwiftData vive en el contenedor del App Group **por
un default implícito**, no por configuración explícita. Si el entitlement no llega al perfil de
distribución, SwiftData abre un store nuevo y vacío sin error y sin banner.

Ninguno de los dos bloqueadores es un defecto de producto. Ambos son horas de trabajo, no semanas.

---

## 2. Final Verdict

# 🔴 NOT READY FOR APP STORE

No por calidad del producto, sino porque **no existe un binario de distribución** y el gate de
verificación está en rojo. El producto subyacente está en la banda de «lanzable tras corregir».

---

## 3. Final Score

**Technical Release Score: 78.7 / 100**

**Nota: 5,6 / 7,0**

---

## 4. App Review Approval Estimate

**80 %**

Estimación de riesgo, no garantía. Una vez que exista un build subible, el perfil de riesgo es bajo:
sin red, sin cuentas, sin compras, sin tracking, manifiestos coherentes, purpose strings específicos.
El 20 % restante se concentra en lo no verificable desde código: que la Privacy Policy URL y la
Support URL respondan en el momento de la revisión, que el App Group exista en el portal de
desarrollador, y que las capturas del App Store no muestren la lista sembrada de 363 productos de
test.

---

## 5. Release Blockers

| # | ID | Título | Severidad | Esfuerzo |
|---|----|--------|-----------|----------|
| B1 | CASI-001 | El pipeline de release nunca se ha ejecutado: no existe archive, firma ni `.ipa` | Critical | M |
| B2 | CASI-002 | La suite de tests está roja por dos archivos temporales sin commitear | High | XS |

Nada más bloquea. CASI-003 es un riesgo latente severo que debe verificarse **durante** la resolución
de B1, no de forma independiente.

---

## 6. Score Breakdown

| Área | Obtenido | Máximo | Hallazgos que descuentan |
|------|---------:|-------:|--------------------------|
| Funcionalidad y lógica | 15,0 | 18 | CASI-006, CASI-004, CASI-008, CASI-017 |
| UI/UX | 11,5 | 14 | CASI-007, CASI-013, CASI-015, descubribilidad de Posponer/No encontrado |
| SwiftData e integridad de datos | 8,5 | 12 | CASI-003, CASI-005, doble fuente de verdad en `status` y `category` |
| Estabilidad y manejo de errores | 8,5 | 10 | `rollback()` descarta todo el contexto, CASI-012 |
| Accesibilidad | 8,5 | 10 | Sin auditoría automatizada de accesibilidad; acciones secundarias solo en menú contextual |
| WidgetKit y App Groups | 6,0 | 8 | CASI-004, contrato triplicado a mano, decode silencioso, sin familias de pantalla bloqueada |
| Core Location y AVFoundation | 5,0 | 6 | CASI-015, handler de interrupción dispara también en `.ended`. **Core Location no existe** (eliminado a propósito) |
| Rendimiento y lifecycle | 4,0 | 6 | CASI-009, CASI-010, CASI-011, recomputación en `CatalogView` |
| Arquitectura y mantenibilidad | 4,0 | 5 | Archivos de 1000+ líneas, tipos duplicados app/widget |
| Tests | 2,5 | 4 | CASI-002; sin cobertura de widget, notas de voz ni migración real |
| Privacidad y seguridad | 3,7 | 4 | URLs de soporte no verificables desde el entorno de auditoría |
| Preparación App Store | 1,5 | 3 | CASI-001, versión y build sin tocar en el pbxproj |
| **TOTAL** | **78,7** | **100** | |

---

## 7. Functional Inventory

Reconstruido desde el código, no desde la documentación.

**Targets (4, un solo `.xcodeproj`):** `CasiListo`, `CasiListoWidget`, `CasiListoTests`,
`CasiListoUITests`. Todos con `PBXFileSystemSynchronizedRootGroup`. App y widget **no comparten un
solo archivo fuente**.

**Modelos (4 `@Model`):** `ShoppingItem`, `ShoppingList`, `Category`, `ProductCatalogItem`.
`ShoppingList`↔`ShoppingItem` **no es relación SwiftData**: es la clave blanda `listID`.

**Navegación real:** `CasiListoApp` → `MainTabView` (4 tabs) → Compra: `ContentView` →
`ListsOverviewView` → `ShoppingListDetailView` → `ShoppingListView` → `CategorySectionView` →
`ItemRowView`. Catálogo, Historial y Ajustes tienen su propio `NavigationStack`.

**Funciones que existen de verdad:**

| Existe | Función |
|---|---|
| ✅ | Multi-lista con icono, color y plantillas de arranque |
| ✅ | CRUD de productos con cantidad, precio, nota, tienda y categoría |
| ✅ | Añadido rápido con parser de cantidad («2kg arroz», «pan x3») |
| ✅ | Autocompletado desde catálogo local aprendido, ordenado por uso |
| ✅ | Categorización automática por nombre, con protección de la elección manual |
| ✅ | Estados: Pendiente / Comprado / Pospuesto / No encontrado |
| ✅ | Ventana de gracia de 2 s al marcar comprado |
| ✅ | Deshacer borrado (una ranura global, 4 s) |
| ✅ | Reordenamiento manual dentro de categoría |
| ✅ | Búsqueda incremental normalizada (tildes, mayúsculas, puntuación) |
| ✅ | Filtro por supermercado (Jumbo / Líder) |
| ✅ | Archivado a historial, una compra por tienda |
| ✅ | **OCR de boletas chilenas** con Vision, revisión humana y conciliación contra el TOTAL impreso |
| ✅ | Comparación de precios contra compras anteriores en la misma tienda |
| ✅ | Notas de voz (AVFoundation, borradores promovidos al guardar, tope 30 s) |
| ✅ | Widget WidgetKit small + medium vía App Group |
| ✅ | Deep link `casilisto://list` |
| ✅ | Exportación CSV del historial, protegida contra inyección de fórmulas |
| ✅ | Importación desde texto pegado (WhatsApp/Notas) |
| ✅ | Gestión de categorías propias con iconos |
| ✅ | Borrado total de datos desde Ajustes |
| ❌ | **Core Location / geofencing** — eliminado por completo |
| ❌ | **Modo compra de pantalla completa** — no existe |
| ❌ | Localización (cero `.xcstrings`, español inline) |
| ❌ | Interactividad en el widget (App Intents) |
| ❌ | Sincronización iCloud / respaldo |

---

## 8. Functional Audit

| Flujo | Estado | Evidencia |
|---|---|---|
| Crear lista | Pass | Verificado en runtime; empty state con 3 arranques rápidos |
| Renombrar / personalizar lista | Pass | `AddEditListSheet` modo `.edit` |
| Duplicar lista | Pass | Copia solo pendientes; también copia `price`, lo que es discutible |
| Eliminar lista | Pass | Confirmación explícita, borra ítems y barre archivos |
| Añadir producto (rápido) | Pass | Expande su categoría y hace scroll hasta él |
| Añadir producto (sheet) | Pass | Detección de duplicado bloquea el botón Guardar |
| Añadir desde catálogo | Pass | Crea la lista destino si no existe; banner indica a cuál |
| Editar producto | Pass | `PriceField` cubre el round-trip de precio, con test |
| Eliminar producto | Pass | Undo de 4 s; nota de voz se borra solo al finalizar |
| Marcar comprado / desmarcar | Pass | Revierte el estado si el save falla |
| Posponer / No encontrado | **Partial** | Solo descubribles por menú contextual (pulsación larga) |
| Reordenar | Pass | Deshabilitado con filtros activos, correctamente |
| Buscar | Pass | Fuerza expansión de categorías durante la búsqueda |
| Archivar comprados | Pass | Una lista histórica por tienda |
| Registrar boleta | Pass | 80 tests, 3 boletas reales autovalidadas |
| Ver historial | Pass | — |
| Borrar compra del historial | Pass | Borra ítems, precios y JPEG |
| Exportar CSV | **Partial** | Correcto, pero se recomputa en cada render (CASI-011) |
| Notas de voz | Pass | Permiso en punto de uso, interrupciones y cambio de ruta manejados |
| Widget | **Partial** | Funciona, pero estado vacío roto (CASI-004) |
| Deep link | Pass | Rechaza query y fragment; test lo cubre |
| Borrar todos los datos | Pass | Orden de operaciones deliberado y documentado |

---

## 9. UI Audit

Basado en capturas reales del simulador, no solo en código.

**Mis Listas (vacía).** Acción principal evidente: botón amarillo «Crear mi primera lista», relleno
de marca con tinta oscura (10,7:1). Tres arranques sugeridos debajo. Nada sobra. Se siente iOS.
**Pass.**

**Mis Listas (con contenido).** Tarjeta de resumen + tarjeta por lista con vista previa de productos
y contador «+360». Jerarquía clara. El botón «Nueva» duplica el «+» de la toolbar, pero solo aparece
cuando ya hay listas, lo cual está razonado en un comentario. **Pass.**

**Detalle de lista.** Título en `ToolbarItem(.principal)` con icono de la lista — deliberadamente sin
`.navigationTitle` para no duplicarlo. Barra de filtro de tienda + resumen con progreso. Barra
inferior de añadido rápido con Liquid Glass. Menú `…` con 6 acciones. **Pass**, con la salvedad de
CASI-007.

**Catálogo.** Banner de destino permanente («Añadiendo a X» / «Se creará una lista nueva») — resuelve
una ambigüedad real. Iconos distintos para «añadir» (`plus.circle`), «ya en tu compra»
(`cart.circle.fill`) y «comprado» (`checkmark.circle.fill`), con un comentario explicando por qué no
se reusó el check. **Pass.**

**Historial / Ajustes.** Correctos, sobrios. Ajustes cierra con una dedicatoria personal — decisión
de producto, no defecto.

**Detalles finos:**

- Los colores literales fuera de `Theme` (12 sitios) son todos pares claro/oscuro deliberados para
  semáforos de estado y diferencias de precio. Aceptable, pero deberían ser tokens.
- `Theme.minimumTouchTarget = 44` se aplica consistentemente en los botones de icono.
- El badge de categoría oscurece el color hasta 4,5:1 conservando el tono, con test
  (`testCategoryIconsMeetContrastOverTheirBadge`). Esto es trabajo de diseño serio.

---

## 10. UX Audit

**Recorrido real: crear lista → preparar → supermercado → comprar → cerrar → historial.**

Funciona de punta a punta y es rápido. La barra inferior de añadido rápido con parser de cantidad es
el acierto central: «2kg arroz» en un gesto.

**Fricciones reales:**

1. **Primera población de una lista aterriza toda colapsada** (CASI-007). Si el usuario importa desde
   WhatsApp o aplica una plantilla, llega a una pantalla de cabeceras de categoría cerradas. El
   añadido individual sí expande y hace scroll; los caminos masivos no, y eso está probado como
   intencional (`testBulkUpdatesDoNotAutoExpandCategories`). Defendible para 355 productos,
   cuestionable para 6.
2. **«Posponer» y «No encontrado» solo viven en el menú contextual.** Son dos de los cuatro estados
   del modelo y no hay ninguna pista visual de que existan. Un usuario nuevo nunca los descubrirá.
3. **«Varios» se presenta como no editable pero se puede abrir y renombrar** (CASI-008). La fila
   oculta el chevron y dice «Categoría predeterminada del sistema», pero el `Button` no está
   deshabilitado.
4. La alerta de micrófono ofrece «Ir a Ajustes» incluso cuando el error es falta de espacio en disco
   (CASI-015).

**Tiempo estimado para que un usuario nuevo entienda la app: 2–3 minutos.** El empty state hace buen
trabajo.

---

## 11. SwiftUI Audit

Uso moderno y en general correcto: `@Observable` sin un solo `ObservableObject` en el repo,
`@Bindable`, `@Query` en las Views, `.task(id:)` con debounce en el autocompletado, `@ScaledMetric`
por todas partes.

**Lo bueno:**

- El ViewModel cachea un snapshot derivado (`derivedGroups`/`derivedSummary`) en vez de recalcular en
  cada render, con invalidación explícita.
- `ShoppingListView` invalida por 7 `onChange` distintos, uno por cada entrada del cálculo. Es frágil
  pero está documentado.
- `ContentView` maneja el caso de lista borrada mientras está abierta con un `else` explícito que
  resetea el `navigationPath` — sin él queda una pantalla en blanco irrecuperable.
- `ShoppingListSheetDestination` garantiza una sola presentación activa.

**Lo que descuenta:**

- Varias propiedades computadas caras se recalculan en cada evaluación de `body`: `priceIndex` y
  `vocabulary` en `ReceiptCaptureSheet` (CASI-010, y el comentario del código afirma lo contrario),
  `exportCSVText()` en `ShoppingHistoryView` (CASI-011), `groupedCatalog` y `activeStatusByName` en
  `CatalogView`.
- `ShoppingHistoryDetailView.onAppear` decodifica un JPEG de hasta 24 MP en el hilo principal
  (CASI-009).

---

## 12. SwiftData & Data Integrity Audit

**Lo que está bien y es poco común:**

- Todas las mutaciones pasan por `ShoppingPersistenceCoordinator.commit()`, construido ad hoc en el
  call site. El snapshot del widget se publica solo después de que SwiftData confirma.
- Barrido de archivos huérfanos al arranque, con `.skipsHiddenFiles` como única cosa que salva la
  carpeta `.temporary` de notas de voz.
- El orden de `resetAllData()` es deliberado: los archivos se borran al final, porque dejar la base
  vacía y sin categorías es peor que dejar blobs sueltos.
- Existe una baseline versionada (`CasiListoSchemaV1`) con test que la verifica. **La documentación
  del proyecto afirma que el plan de migración está vacío; eso ya no es exacto** — el baseline
  existe, lo que falta son las etapas.
- Verificado en runtime: primer arranque limpio produce 355 filas de catálogo, 15 categorías, 0
  listas. Determinista.

**Lo que se encontró:**

1. **La ubicación del store depende de un default implícito** (CASI-003). Confirmado en disco:
   `default.store` vive en `group.com.allopze.CasiListo/Library/Application Support/`, no en el
   sandbox. Nadie lo configuró: `ModelConfiguration` usa `groupContainer: .automatic`, que elige el
   App Group porque la app tiene exactamente uno. Si el entitlement no llega al perfil de
   distribución, SwiftData abre un store nuevo y vacío **sin lanzar**, así que
   `isUsingInMemoryFallback` no se activa y el banner no aparece.
2. **`ShoppingItem` guarda la categoría dos veces**: `categoryRelation` y la sombra
   `categoryRawValue`. Solo el setter de la computada mantiene ambas en sync.
   `CategoryBootstrapService` las reconcilia en cada arranque: funciona, pero es una curita
   permanente.
3. **`status` tiene dos fuentes de verdad**: `statusRawValue: String?` y `storedIsPurchased: Bool`
   (originalName `isPurchased`). El getter cae a la segunda cuando la primera es `nil`.
4. **`commitWithoutWidget()` hace `context.rollback()` ante cualquier fallo**, descartando todo lo
   pendiente del contexto, no solo el cambio del llamador. Lo mismo en `ReceiptPurchaseService.register`.
5. **Simulación 1.0 → 1.1 → 1.2**: hoy `stages` está vacío. Un cambio de `@Model` sin
   `VersionedSchema` + `MigrationStage` puede impedir abrir el store — y ese fallo cae en el fallback
   en memoria, que sí muestra banner.
6. **`Category.name` es `@Attribute(.unique)` y a la vez identidad.** La restricción única de
   SwiftData hace *upsert* en conflicto en vez de lanzar. El sheet valida contra duplicados
   (ignorando mayúsculas y tildes) antes de permitir Guardar, así que está mitigado en la UI, no en
   el modelo.
7. **Undo restaura un registro distinto**: `ShoppingItem.init` siempre asigna `id` y `createdAt`
   nuevos. Es una ranura global, no una cola.

**Respuesta directa a la pregunta obligada:**

> ¿Una actualización futura de CasiListo podría hacer que el usuario pierda sus listas?

**Sí, por dos caminos, y solo uno está cubierto.** Un cambio de esquema sin etapa cae en el fallback
en memoria y **el usuario ve un banner** — eso está resuelto. Pero un cambio o pérdida del
entitlement de App Group abre un store vacío **en silencio, sin banner y sin error**. Ese camino no
tiene ninguna defensa.

---

## 13. Architecture & MVVM Audit

Un solo ViewModel (`ShoppingListViewModel`, `@Observable`, 696 líneas). Servicios como `enum` sin
estado con funciones estáticas; los que tocan datos reciben el `ModelContext`. Un único servicio con
estado (`VoiceNoteService`, singleton + inyectado por `.environment`). No hay capa de repositorio:
las Views poseen los `@Query` y pasan arrays planos.

**No se penaliza la ausencia de repositorio** — con `@Query` y SwiftData es una decisión legítima, y
la consecuencia real (testabilidad) está cubierta: los tests construyen contenedores en memoria y
ejercitan los servicios directamente.

**Lo que sí tiene consecuencias:**

- 46 de 75 archivos exceden las 100 líneas que el README declara como regla; `ReceiptCaptureSheet.swift`
  tiene 1052. No hay SwiftLint ni check de CI. Consecuencia práctica real: **un tipo no vive
  necesariamente en el archivo con su nombre** (`DuplicatePolicy` está en `ProductNameNormalizer.swift`,
  `ReceiptServices.swift` contiene 14 tipos de nivel superior).
- El contrato app↔widget son **tres constantes duplicadas a mano** en cinco sitios. Un typo es un
  no-op silencioso.

---

## 14. Accessibility Audit

**Esta es de las áreas más fuertes del proyecto**, y no es habitual.

**VoiceOver.** `ItemRowView` combina los hijos, construye un label con nombre, tienda, cantidad,
estado y nota, y expone **cinco acciones personalizadas** (marcar, editar, posponer, no encontrado,
eliminar) que replican swipe actions y menú contextual. Las cabeceras de categoría exponen
`accessibilityValue` («Colapsada»/«Expandida») y `accessibilityHint`. Los contadores del historial
llevan label explícito porque si no VoiceOver dictaba números sueltos.

**Dynamic Type.** `@ScaledMetric(relativeTo:)` en prácticamente cada medida de cada vista. Las fuentes
son `.system(.body, design: .rounded)`, no tamaños fijos. El arnés de capturas prueba texto XXL.

**Contraste.** El sistema calcula luminancia relativa WCAG y hay tests que asertan `accentInteractive`
≥ 4,5:1 sobre crema y blanco, y que los iconos de categoría alcanzan 4,5:1 sobre su propio badge al
14 %. `AccentProminentButtonStyle` existe específicamente porque `.borderedProminent` pintaba blanco
sobre amarillo (1,63:1).

**Reduce Motion.** Honrado pasando `nil` como animación, tanto en `ItemRowView` como en el pulso de
grabación.

**Differentiate Without Color.** El estado comprado usa tachado + checkbox relleno + glifo de check,
no solo color. Pospuesto y No encontrado usan `Label` con icono y texto.

**Touch targets.** `Theme.minimumTouchTarget = 44` aplicado consistentemente.

**Lo que falta:** no hay ninguna prueba automatizada de accesibilidad
(`XCUIApplication.performAccessibilityAudit()`), y solo 14 identificadores declarados.

**Accessibility Nutrition Labels declarables legítimamente:**

| Label | ¿Declarable? |
|---|---|
| VoiceOver | ✅ Sí |
| Larger Text | ✅ Sí |
| Sufficient Contrast | ✅ Sí, con evidencia en tests |
| Differentiate Without Color | ✅ Sí |
| Reduced Motion | ✅ Sí |
| Dark Interface | ✅ Sí |
| Voice Control | ⚠️ Probable, pero no verificado en dispositivo |
| Captions / Audio Descriptions | ❌ No aplica |

---

## 15. Core Location Audit

**No aplica: CasiListo no usa Core Location.**

`grep -riE "CLLocation|CoreLocation"` sobre `CasiListo/` y `CasiListoWidget/` devuelve **cero
coincidencias**. El entitlement no existe, no hay `NSLocationWhenInUseUsageDescription` en las build
settings, y `resetAllData()` solo hace `removeObject(forKey: "geofencing_enabled")` como limpieza de
una preferencia heredada.

Esto es **correcto y una buena decisión de producto**: no se pide un permiso que no se usa, que es
exactamente el criterio de mínimo privilegio. El brief describía geofencing como una función
existente; no lo es.

Consecuencia directa: la pregunta «¿negar ubicación inutiliza la app?» no tiene sentido aquí, porque
la app nunca la pide.

---

## 16. AVFoundation Audit

**Bien construido.**

- Permiso solicitado **en el punto de uso** (`AVAudioApplication.requestRecordPermission()` al tocar
  el botón de grabar), no al arranque.
- Categoría `.playAndRecord` con `.defaultToSpeaker` para grabar; `.playback` con **`.duckOthers`**
  para reproducir, con el comentario de por qué: sin eso, tres segundos de nota mataban la música del
  usuario en el supermercado.
- Sesión desactivada con `.notifyOthersOnDeactivation` al terminar.
- Observadores de `interruptionNotification` y `routeChangeNotification` (solo `oldDeviceUnavailable`).
- **Modelo de borradores**: se graba `draft-*.m4a` en `Documents/VoiceNotes/.temporary` y se promueve
  a `voice-*.m4a` solo tras el commit de SwiftData. Si el guardado falla, el promovido se borra.
  Cancelar el sheet limpia los borradores y restaura el nombre original.
- Tope de 30 s, 12 kHz mono AAC calidad media — archivos pequeños, crecimiento acotado.
- Errores tipados con mensajes en español comprensibles, incluido `NSFileWriteOutOfSpaceError` → «No
  queda espacio suficiente».
- Barrido de `.temporary` con `keeping: []` en cada arranque.

**Defectos:** el handler de interrupción no distingue `.began` de `.ended`, así que fija
`lastError = .sessionInterrupted` en ambos casos; y la alerta de error ofrece «Ir a Ajustes» incluso
para errores de disco (CASI-015).

**Sin archivos huérfanos detectables, sin referencias rotas, sin crecimiento ilimitado.**

---

## 17. WidgetKit Audit

`StaticConfiguration`, `TimelineProvider`, familias `.systemSmall` y `.systemMedium`,
`containerBackground`, `widgetAccentable()`, `widgetURL("casilisto://list")`, política
`.after(+30 min)` como fallback más recarga coalescida (500 ms) desde la app tras cada commit.

**El widget no abre la base de datos** — lee JSON desde `UserDefaults` del App Group con tipos
duplicados. Decisión correcta para el presupuesto de memoria de WidgetKit.

> ¿El widget entrega información útil en menos de dos segundos de mirada?

**Sí en el caso normal. No en el caso vacío.** El small muestra un número grande de pendientes; el
medium añade los primeros 5 productos ordenados de forma determinista (`sortOrder`, `createdAt`).
Pero se confirmó en runtime que el estado vacío intencionado nunca se muestra (CASI-004).

**Otros huecos:** sin familias de pantalla bloqueada (`.accessoryRectangular`/`.accessoryCircular`),
que para una lista de compras serían las más útiles; sin interactividad (App Intents) para marcar
comprado desde el widget; `updatedAt` nunca se muestra, así que un snapshot viejo es indistinguible
de uno fresco.

---

## 18. App Groups Audit

Entitlement `group.com.allopze.CasiListo` presente y **idéntico** en ambos targets. Verificado en el
simulador que el contenedor compartido existe y contiene tanto el `default.store` de SwiftData como
`Library/Preferences/group.com.allopze.CasiListo.plist` con la clave `widgetSnapshot`.

**El contrato son tres constantes duplicadas a mano:**

| Constante | Sitios donde se declara |
|---|---|
| ID del grupo | 2 `.entitlements` + `WidgetDataBridge.appGroupID` + `WidgetSnapshot.groupID` |
| `kind` `"CasiListoWidget"` | `WidgetDataBridge.widgetKind` + `CasiListoWidget.kind` |
| Clave `"widgetSnapshot"` | `WidgetDataBridge.snapshotKey` + `WidgetSnapshot.key` |

Deben coincidir o el reload es un no-op silencioso, y un fallo de decode en el widget es invisible
(`try?` → ceros con `updatedAt: .distantPast`). Renombrar un campo deja un widget plausible «0
pendientes» en vez de fallar visiblemente.

**Escenario donde app y widget divergen:** la escritura del snapshot ocurre después de cada commit,
pero la recarga está coalescida 500 ms y WidgetKit tiene presupuesto propio. Divergencias de segundos
a minutos son esperables y aceptables. La divergencia *permanente* solo ocurre si se rompe una de las
seis constantes.

---

## 19. Privacy & Security Audit

**La promesa de «app 100 % local» es verificablemente cierta.** Este es el resultado más limpio de
toda la auditoría.

`grep -riE "URLSession|http://|https://|Analytics|Firebase|WKWebView|Socket|UNUserNotification"` sobre
los targets de app y widget devuelve **exactamente dos coincidencias**, ambas en
`AppSupportLinks.swift`: las URLs de política de privacidad y soporte, que se abren en Safari vía
`Link`. No hay ninguna otra comunicación externa. Cero dependencias externas (sin SPM, sin
CocoaPods, sin lockfile).

**Privacy Manifests.** Ambos targets los tienen, sintácticamente válidos (`plutil` pasa en CI).
Declaran `NSPrivacyTracking = false`, dominios vacíos, datos recolectados vacíos, y la única
categoría de Required Reason API: `UserDefaults` con razón `CA92.1` (app) y `1C8F.1` (ambos).
Verificado por grep que **no se usa ninguna otra Required Reason API**: sin timestamps de archivo,
sin espacio en disco, sin boot time, sin teclados activos.

**Coherencia Código → PrivacyInfo.xcprivacy → App Store Privacy:** sin contradicciones. La
declaración de App Privacy debería ser «Data Not Collected».

**Permisos:**

| Permiso | Motivo | Cuándo se solicita | ¿Necesario? | Purpose string | ¿Correcto? |
|---|---|---|---|---|---|
| Cámara | Fotografiar boletas para OCR | Al tocar «Registrar boleta» → cámara | Sí, para OCR | «CasiListo usa la cámara para fotografiar boletas y registrar productos y precios.» | ✅ |
| Micrófono | Grabar notas de voz en productos | Al tocar el botón de grabar | Sí, opcional | «CasiListo usa el micrófono para guardar notas de voz en productos de tu lista.» | ✅ |
| Fototeca | — | **Nunca** | No: usa `PHPickerViewController` | No declarado | ✅ Correcto |
| Ubicación | — | **Nunca** | No se usa | No declarado | ✅ Correcto |

**Mínimo privilegio: cumplido.** Dos permisos, ambos justificados, ambos pedidos en el punto de uso,
ambos con la app plenamente funcional si se deniegan.

**Seguridad.** Sin secretos, tokens ni API keys en el árbol. Los `Logger` usan `privacy: .public` solo
sobre valores no personales (raw values desconocidos, descripciones de error del sistema) — no se
filtran nombres de productos ni precios. `CSVSerializer` protege contra **inyección de fórmulas**
prefijando `'` a campos que empiezan con `=`, `+`, `-` o `@`, con test RFC 4180. Las escrituras de
boletas usan `.atomic`. Los blobs viven en el sandbox privado, no en el App Group.

**Único punto no verificable desde el entorno de auditoría:** las URLs
`https://casilisto-privacy.pages.dev/privacy/` y `/support/` no resuelven (DNS bloqueado por el
sandbox, no evidencia de que el sitio esté caído). El sitio está versionado en `privacy-site/` con su
script de build y su workflow de despliegue a Cloudflare Pages. **Debe verificarse manualmente antes
de enviar.**

---

## 20. Performance & Lifecycle Audit

**Medido, no supuesto:** existe `testListFilteringPerformanceAtReleaseDataVolumes` y
`PerformanceSignpost` instrumenta las tres operaciones caras (recalcular lista, aplicar filtros,
exportar CSV).

| Volumen | Comportamiento |
|---|---|
| 10 productos | Instantáneo |
| 100 productos | Sin problema |
| 363 productos (fixture real) | Verificado en runtime; UI fluida. El snapshot derivado evita recalcular por render |
| Meses de historial | **Degrada** — CASI-011 y CASI-010 |
| Muchas notas de voz | Acotado: 30 s, 12 kHz mono |
| Boleta de 5 páginas | **Riesgo real** — CASI-009 |

**Aciertos:** snapshot derivado cacheado con invalidación explícita; `LazyVStack` en las listas de
tarjetas; `.task(id:)` con 150 ms de debounce en el autocompletado; el lienzo de boletas multipágina
está acotado a 24 MP con un comentario explicando que cinco páginas a resolución completa armaban
>100 MB y el sistema cerraba la app.

**Lifecycle.** `launch → active → background` guarda y detiene la reproducción. El `.task` de
`ContentView` se reejecuta cada vez que la pestaña Compra reaparece, protegido para los UI tests por
`didResetForUITests`, pero el bootstrap completo (varios `fetch` sobre todas las tablas) **corre en
cada reaparición de la pestaña**. Con datos grandes eso es trabajo repetido en el hilo principal al
cambiar de pestaña.

**Memoria.** Sin ciclos de retención detectables: los `Task` del ViewModel usan `[weak self]`, los
observadores de `NotificationCenter` también. `VoiceNoteService` es singleton por diseño y libera
recorder/player al detener.

---

## 21. Error Handling Audit

25 `try?` en producción, ninguno peligroso tras revisión individual: la mayoría son lecturas de URL
de archivo que ya tienen un camino de fallo explícito.

`try!` aparece dos veces: la compilación de regex con patrón literal en `ReceiptLineParser` (falla en
el primer test, no en producción) y en `PreviewSupport.swift`, que está **completo dentro de
`#if DEBUG`** — verificado, no llega al binario de release.

Un solo `fatalError`, en el segundo nivel del fallback del container: si ni siquiera se puede crear
un contenedor en memoria. Defendible.

**Los errores importantes sí se traducen en UX comprensible.** Cada vista con mutaciones tiene el
patrón `@State var xErrorMessage: String?` + `.alert` con un único botón «Entendido», y los mensajes
están en español y son accionables. Los estados se revierten cuando el save falla: `togglePurchased`
restaura el estado anterior.

**El descuento real** es `context.rollback()` en los caminos de fallo: descarta **todo** lo pendiente
en el contexto, no solo el cambio del llamador.

---

## 22. Testing Audit

**142 tests**, todos XCTest, cero swift-testing.

| Área | Cobertura |
|---|---|
| Parser de boletas | **Excelente** — ~60 tests, 3 boletas chilenas reales que se autovalidan contra su total impreso |
| Ensamblado de filas OCR | **Buena** — union-find, solapes, orden estable |
| Matcher de nombres | **Buena** — abreviaturas, errores de un carácter, falsos positivos |
| Persistencia / archivado | **Buena** — una compra por tienda, contadores, sin huérfanos |
| Precio / formato | **Buena** — round-trip de edición cubierto |
| Catálogo | **Buena** — idempotencia, respeto a borrados, orden por uso |
| ViewModel | **Buena** — quick add, agrupación, gracia, undo |
| Contraste / SF Symbols | **Buena** — asertan ratios y existencia de símbolos |
| UI tests | **Mínima pero útil** — 4 flujos + arnés de 23 capturas |
| **Widget / App Group** | ❌ **Ninguna** |
| **VoiceNoteService** | ❌ **Ninguna** |
| **Migración real** | ⚠️ Solo baseline; ninguna etapa probada |
| **Borrado de lista** | ❌ Ninguna |
| **Renombrado de categoría en cascada** | ❌ Ninguna |

**Y la suite está roja** (CASI-002).

---

## 23. App Store Compliance Audit

| Guideline | Situación | Probabilidad | Clasificación |
|---|---|---|---|
| 2.1 App Completeness | La app está completa y funcional; **pero nunca se construyó un build de distribución** | Alta si se envía sin probar el archive | **Compliance concern** |
| 2.3 Accurate Metadata | Capturas deben reflejar la app real, no el fixture de 363 productos de test | Media | **Possible rejection** |
| 2.5.1 Private APIs | Ninguna | — | No issue detected |
| 4.2 Minimum Functionality | App rica: OCR, widget, historial, notas de voz | Muy baja | No issue detected |
| 5.1.1 Data Collection | No recolecta nada; manifiestos coherentes | Muy baja | No issue detected |
| 5.1.1(v) Account Sign-In | No hay cuentas | — | No issue detected |
| 5.1.2 Data Use | Purpose strings específicos y honestos | Muy baja | No issue detected |
| 3.1.1 In-App Purchase | Sin compras | — | No issue detected |
| 1.2 User-Generated Content | Sin contenido compartido | — | No issue detected |
| Privacy Policy URL | Sitio versionado y desplegable, **no verificado en vivo** | Media si está caído | **Compliance concern** |

**Configuración de producción:**

| Elemento | Valor | Estado |
|---|---|---|
| Bundle ID | `com.allopze.CasiListo` | ✅ |
| Bundle ID widget | `com.allopze.CasiListo.widget` | ✅ |
| `MARKETING_VERSION` | 1.0 | ✅ |
| `CURRENT_PROJECT_VERSION` | 1 | ⚠️ Sobrescrito por el workflow con `github.run_number` |
| Deployment target | **iOS 26.0** | ⚠️ Decisión de negocio (CASI-020) |
| `TARGETED_DEVICE_FAMILY` | 1 (solo iPhone) | ✅ |
| Swift | 6.0, strict concurrency `complete` | ✅ |
| App Icon | 1024², sin alfa, con dark y tinted | ✅ |
| `ITSAppUsesNonExemptEncryption` | `false` | ✅ |
| `CFBundleURLTypes` | `casilisto` en el Info.plist parcial | ✅ Correcto: los `INFOPLIST_KEY_*` no aceptan arrays de diccionarios |
| Orientaciones | **Las 4** | ⚠️ CASI-013 |
| Entitlements | App Group en ambos targets | ✅ |
| Code signing | Automático, sin certificado importado | ⚠️ Nunca validado |
| Privacy manifests | Ambos, validados en CI | ✅ |

---

## 24. Critical Findings

---

**ID:** CASI-001
**Severity:** Critical
**Confidence:** Confirmed
**Category:** Release engineering
**Title:** El pipeline de release nunca se ha ejecutado: no existe ningún build de distribución, firmado ni subido
**File:** `.github/workflows/release-testflight.yml`, `ci/ExportOptions-AppStore.plist`
**Lines:** archivo completo
**Affected flow:** Publicación en App Store / TestFlight
**Evidence:** El workflow es `workflow_dispatch` y no hay evidencia de ninguna ejecución. `gh` no está instalado en esta máquina. La propia auditoría del proyecto (`AUDITORIA_LANZAMIENTO_APP_STORE_2026-08-12.md`) deja **F-20 explícitamente abierto**: «el archive/upload de release nunca se validó». El workflow depende por completo de `-allowProvisioningUpdates` con firma automática; no importa ningún certificado a un keychain. `CURRENT_PROJECT_VERSION = 1` en el pbxproj.
**How to reproduce:** Intentar publicar. No existe ningún `.ipa`, ni `artifacts/export/`, ni registro de subida con `iTMSTransporter`.
**Expected behavior:** Antes de enviar a revisión debe existir al menos un archive firmado, exportado y subido a TestFlight, instalado y probado en un dispositivo físico.
**Actual behavior:** Cero ejecuciones. No hay evidencia de que la app pueda construirse para distribución.
**User impact:** Ninguno todavía — no hay usuarios.
**Technical impact:** Todos los fallos de firma, entitlements, perfiles y capabilities siguen sin descubrir. El App Group (del que depende **la ubicación de toda la base de datos**, ver CASI-003) nunca se ha ejercitado en un perfil de distribución.
**App Store impact:** No se puede enviar nada. Si el App Group no está registrado en el portal, el primer build de TestFlight arranca con la base vacía.
**Root cause:** El pipeline se escribió pero nunca se disparó.
**Recommended fix:** Registrar el App Group en el Developer Portal. Disparar `release-testflight.yml` desde la pestaña Actions (o `brew install gh` y `gh workflow run release-testflight.yml --ref main`). Verificar los secretos `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`. Instalar el build de TestFlight en un iPhone físico y ejecutar el recorrido completo.
**Regression risk:** Low
**Effort:** M
**How to validate the fix:** Un build visible en App Store Connect, instalable desde TestFlight, que al abrirse cree y persista una lista que sobreviva a cerrar y reabrir la app, y cuyo widget muestre el conteo correcto.

---

## 25. High Findings

---

**ID:** CASI-002
**Severity:** High *(bloqueador de proceso)*
**Confidence:** Confirmed
**Category:** Testing / CI
**Title:** La suite de tests está roja por dos archivos de test temporales sin commitear
**File:** `CasiListoTests/TempUpgradeDupRefutationTests.swift`, `CasiListoTests/TempRefutationTests.swift`
**Lines:** `TempUpgradeDupRefutationTests.swift:74`
**Affected flow:** Gate de CI de cualquier PR
**Evidence:** `xcodebuild test -only-testing:CasiListoTests` → **exit 65**. `Failing tests: TempUpgradeDupRefutationTests.testUpgradeFreezesExistingDuplicates()`. Ambos archivos aparecen como sin seguimiento en `git status` y el segundo está marcado en su propio comentario como «TEMPORAL — verificación de refutación. Borrar.»
**How to reproduce:** `export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer && xcodebuild test -project CasiListo.xcodeproj -scheme CasiListo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CasiListoTests`
**Expected behavior:** Suite verde.
**Actual behavior:** 1 test falla; `** TEST FAILED **`.
**User impact:** Ninguno directo.
**Technical impact:** El gate de `ios.yml` fallaría en el PR. Peor: **la suite roja enmascara regresiones reales** — un fallo nuevo se confundiría con este.
**App Store impact:** Indirecto: sin gate verde no hay confianza para disparar el release.
**Root cause:** Andamiaje de investigación dejado en el árbol. El test asserta `finalDups.isEmpty` con el mensaje «Si no quedan duplicados el hallazgo sería falso» — está *diseñado* para fallar y así confirmar CASI-014.
**Recommended fix:** Borrar ambos archivos. El comportamiento genuino que documentan (CASI-014 y el desacuerdo de `unitCount` de CASI-006) debe convertirse en tests de regresión *afirmativos* dentro de `CasiListoTests.swift` y `PurchaseHistoryTests.swift`.
**Regression risk:** Low
**Effort:** XS
**How to validate the fix:** `xcodebuild test` con exit 0 y sin «Failing tests».

---

**ID:** CASI-003
**Severity:** High
**Confidence:** Confirmed *(ubicación)* / Highly Likely *(modo de fallo)*
**Category:** Integridad de datos / Configuración
**Title:** Toda la base de datos vive en el App Group por un default implícito, y su pérdida sería silenciosa
**File:** `CasiListo/Models/CasiListoSchemaMigration.swift`
**Lines:** 25–33
**Affected flow:** Arranque, persistencia completa
**Evidence:** `ModelContainer(for:migrationPlan:)` se construye **sin `ModelConfiguration` explícita**, así que `groupContainer` queda en `.automatic`, que elige el App Group porque la app declara exactamente uno. Confirmado en disco tras un arranque real: `.../Containers/Shared/AppGroup/<uuid>/Library/Application Support/default.store` (más `-wal` y `-shm`). **No hay ningún `.store` en el sandbox de la app.**
**How to reproduce:** Quitar `com.apple.security.application-groups` de `CasiListo.entitlements`, o instalar un build cuyo perfil de distribución no incluya el grupo. SwiftData resuelve entonces al sandbox y abre un store nuevo.
**Expected behavior:** La ubicación del store debe ser una decisión explícita y verificable, y una discrepancia debe ser detectable.
**Actual behavior:** La ubicación es un efecto secundario del entitlement. Si cambia, SwiftData **abre un store vacío sin lanzar**, por lo que `isUsingInMemoryFallback` queda en `false` y el banner de `MainTabView` no aparece.
**User impact:** El usuario abre la app tras una actualización y todas sus listas, historial y catálogo han desaparecido, sin ningún mensaje. Los datos siguen en disco pero son inalcanzables.
**Technical impact:** Pérdida total de datos percibida, sin telemetría (y sin backend, el dispositivo es la única copia).
**App Store impact:** Avalancha de reseñas de 1 estrella. No causa rechazo en revisión.
**Root cause:** Dependencia de un default implícito de SwiftData para algo crítico, sin aserción.
**Recommended fix:** Declarar la configuración explícitamente:

```swift
let config = ModelConfiguration(groupContainer: .identifier(WidgetDataBridge.appGroupID))
```

y añadir una comprobación al arranque: si el store esperado no existe **pero la app ya se había ejecutado antes** (por ejemplo, `hasSeededCatalogV1` está en `true` y el catálogo está vacío), mostrar el banner de persistencia en vez de fingir un primer arranque.
**Regression risk:** Medium — cambiar la configuración en un build que ya tiene usuarios debe apuntar exactamente a la misma ruta actual.
**Effort:** S
**How to validate the fix:** Test que asserta que la URL del store contiene el identificador del App Group; y en TestFlight, confirmar que los datos sobreviven a una actualización sobre la versión anterior.

---

## 26. Medium Findings

---

**ID:** CASI-004
**Severity:** Medium
**Confidence:** Confirmed *(verificado en runtime)*
**Category:** WidgetKit / UX
**Title:** El estado vacío del widget es código muerto: siempre muestra «0 pendientes»
**File:** `CasiListo/Views/ContentView.swift:102`, `CasiListoWidget/WidgetDataModel.swift:26`, `CasiListoWidget/CasiListoWidget.swift:60-68`
**Affected flow:** Widget en pantalla de inicio
**Evidence:** `isPlaceholder` se define como `updatedAt == .distantPast`. Pero `ContentView.task` llama a `persistence.refreshWidgetSnapshot()` en **todo** arranque, incluido el primero. Plist del App Group decodificado tras una instalación limpia sin listas:

```json
{"updatedAt": 810950656.19, "topItems": [], "pendingCount": 0, "purchasedCount": 0}
```

`updatedAt` es real, no `.distantPast` → `isPlaceholder == false`.
**How to reproduce:** Instalar limpio, abrir la app una vez sin crear nada, cerrarla, añadir el widget.
**Expected behavior:** «Abre CasiListo para empezar» / «Tus productos pendientes aparecerán aquí.»
**Actual behavior:** Un «0» grande sobre «pendientes».
**User impact:** El widget afirma con seguridad que no queda nada por comprar a alguien que ni siquiera ha creado una lista. Es exactamente lo que el comentario del código dice evitar.
**Technical impact:** La rama `isPlaceholder` de ambos tamaños es inalcanzable tras el primer arranque.
**Root cause:** La condición de placeholder es «la app nunca escribió», cuando la condición de producto es «no hay nada que mostrar».
**Recommended fix:** Sustituir la condición por una de contenido: `topItems.isEmpty && pendingCount == 0 && purchasedCount == 0`; o publicar un snapshot con `updatedAt: .distantPast` mientras no exista ninguna lista.
**Regression risk:** Low
**Effort:** XS
**How to validate the fix:** Test unitario de `WidgetSnapshot.isPlaceholder`, más verificación visual con la app instalada y sin listas.

---

**ID:** CASI-005
**Severity:** Medium
**Confidence:** Confirmed
**Category:** SwiftData / Migración
**Title:** El plan de migración tiene baseline pero ninguna etapa: la primera 1.1 con cambio de esquema deja al usuario sin poder guardar
**File:** `CasiListo/Models/CasiListoSchemaMigration.swift:14-17`
**Evidence:** `CasiListoSchemaV1` existe y está cubierto por `testPublicSchemaBaselineContainsCurrentPersistentModels` — **esto es mejor de lo que afirma la documentación del proyecto**. Pero `stages` es `[]`.
**Expected behavior:** Cualquier cambio de `@Model` en 1.1 debe llegar con su `VersionedSchema` y su `MigrationStage`.
**Actual behavior:** Sin etapa, un cambio incompatible impide abrir el store.
**User impact:** Cae en el fallback en memoria y **el banner sí aparece** («CasiListo no puede guardar en este dispositivo»). El usuario no pierde datos, pero queda sin poder guardar hasta que se publique un arreglo.
**Technical impact:** El sistema de defensa funciona; lo que falta es no necesitarlo.
**Root cause:** 1.0 no necesita etapas; el riesgo es de proceso.
**Recommended fix:** Antes del primer cambio de modelo posterior a 1.0, añadir `CasiListoSchemaV2` + `MigrationStage`, y un test que abra un fixture V1 y verifique que los datos sobreviven.
**Regression risk:** Low
**Effort:** M *(cuando llegue 1.1)*
**How to validate the fix:** Test de migración con store V1 real.

---

**ID:** CASI-006
**Severity:** Medium
**Confidence:** Confirmed *(por el propio test del proyecto)*
**Category:** Corrección / Dinero
**Title:** «3 unidades» se archiva como 1 unidad: el gasto del historial queda subestimado
**File:** `CasiListo/ViewModels/ShoppingListViewModel.swift:687-689`, `CasiListo/Services/ReceiptServices.swift:913-918`
**Evidence:** El parser de añadido rápido acepta como unidad `["kg","g","l","lt","ml","u","un","uds","unidad","unidades"]`, así que «3 unidades coca cola» produce `quantity = "3 unidades"`. Pero `ReceiptPurchaseService.unitCount` solo multiplica con un **entero desnudo**:

```swift
guard let units = Int(quantity.trimmingCharacters(in: .whitespaces)), units > 0 else { return 1 }
```

`TempRefutationTests` lo confirma y **pasa**: `("3 unidades", 1_500)` frente a `("3", 4_500)`.
**How to reproduce:** Añadir «3 unidades coca cola», ponerle precio $1.500, marcarlo comprado, archivar. El historial registra $1.500 en vez de $4.500.
**Expected behavior:** Ambos lados deben coincidir en qué cuenta como multiplicador.
**Actual behavior:** El añadido rápido fabrica cantidades que el archivado no sabe multiplicar.
**User impact:** El gasto total de una compra sale mal, en silencio y sin pantalla desde donde corregirlo.
**Technical impact:** Dos definiciones de «cantidad» en el mismo producto.
**Root cause:** `unitCount` se endureció (correctamente, para que «500 g» no valga 500) sin ajustar el parser que produce las cantidades.
**Recommended fix:** Extraer una única `QuantitySemantics` que decida si una cantidad es recuento o magnitud, y usarla en ambos sitios. «3 unidades», «3 u», «3 un» son recuentos; «500 g», «1,5 kg», «2 lt» son magnitudes.
**Regression risk:** Medium — cambia totales del historial ya guardados.
**Effort:** S
**How to validate the fix:** Convertir `TempRefutationTests.testMergedItemWithUnitWordQuantity` en un test afirmativo con las expectativas corregidas.

---

**ID:** CASI-007
**Severity:** Medium
**Confidence:** Confirmed
**Category:** UX
**Title:** La primera vez que una lista recibe productos, todas sus categorías quedan colapsadas
**File:** `CasiListo/ViewModels/ShoppingListViewModel.swift:111-120`
**Evidence:** En `updateDerivedState`, si no hay estado guardado y la lista acaba de dejar de estar vacía: `collapsedCategories = Set(categories.map(\.name))` y se persiste. Los caminos masivos (plantillas, importador de texto, boleta) **no llaman a `revealCategory`**, lo cual está probado como intencional.
**How to reproduce:** Crear una lista nueva → menú `…` → «Importar desde texto» → pegar 6 productos → confirmar.
**Expected behavior:** Ver los productos recién añadidos.
**Actual behavior:** Se ven 3-4 cabeceras de categoría cerradas con un número al lado.
**User impact:** «¿Se guardaron mis productos?» El primer contacto con una lista poblada es una pantalla que parece vacía.
**Technical impact:** Ninguno.
**Root cause:** La heurística de colapso inicial se diseñó para la plantilla de 355 productos y se aplica por igual a una importación de 6.
**Recommended fix:** Colapsar por defecto solo por encima de un umbral (p. ej. > 40 productos o > 6 categorías). Por debajo, dejar todo expandido.
**Regression risk:** Low — `ScreenshotCaptureTests` y `testCategoryCardsCollapseAndExpand` asumen «Colapsada» con el fixture de 363, que seguiría por encima del umbral.
**Effort:** XS
**How to validate the fix:** Test de ViewModel con 6 y con 363 productos.

---

**ID:** CASI-008
**Severity:** Medium
**Confidence:** Confirmed
**Category:** Integridad de datos / UX
**Title:** «Varios» se presenta como no editable pero se puede abrir y renombrar, y eso genera un «Varios» duplicado
**File:** `CasiListo/Views/CategoryManagementView.swift:78`, `CasiListo/Models/Category.swift:110-119`
**Evidence:** `categoryRow` envuelve toda la fila en `Button { sheetMode = .edit(category) }` **sin condición ni `.disabled`**, aunque oculta el chevron y muestra «Categoría predeterminada del sistema». El `deleteCategory` sí tiene `guard category.name != "Varios"`, pero se compara **por nombre**.
**How to reproduce:** Ajustes → Categorías → tocar «Varios» → renombrar a «Otros» → Guardar. Reiniciar la app.
**Expected behavior:** «Varios» no debería ser editable, o el renombrado debería mantener su rol de fallback.
**Actual behavior:** Al reiniciar, `CategoryBootstrapService` ve que `categoryMap["Varios"] == nil` e **inserta un «Varios» nuevo y vacío**. El usuario queda con «Otros» (con todos los productos) y un «Varios» fantasma. Además «Otros» pasa a ser eliminable, porque el guard solo protege el literal.
**User impact:** Aparece una categoría que el usuario no creó; su categoría renombrada pierde la protección de borrado.
**Technical impact:** El rol de fallback está atado a un literal en vez de a la bandera `isSystem`.
**Root cause:** La identidad de la categoría fallback es un string, no un atributo del modelo.
**Recommended fix:** Deshabilitar la fila para la categoría fallback (`.disabled(category.name == "Varios")`), y cambiar los guards de comparación por nombre a comparación por rol (`isSystem && sortIndex == 999`, o mejor, una bandera `isFallback` explícita).
**Regression risk:** Low
**Effort:** S
**How to validate the fix:** Test que renombra la fallback y verifica que no aparece una segunda categoría al rearrancar el bootstrap.

---

**ID:** CASI-009
**Severity:** Medium
**Confidence:** Highly Likely
**Category:** Rendimiento / Memoria
**Title:** La foto de boleta (hasta 24 MP) se decodifica en el hilo principal al abrir una compra del historial
**File:** `CasiListo/Views/ShoppingHistoryDetailView.swift:83-86`, `CasiListo/Services/ReceiptServices.swift:139-142`
**Evidence:** `onAppear { receiptImage = ReceiptImageStore.image(named: filename) }` → `UIImage(contentsOfFile:)`, sin downsampling. `ReceiptImageComposer.maximumPixels = 24_000_000`, así que una boleta de varias páginas puede ser un bitmap de ~96 MB descomprimido.
**How to reproduce:** Registrar una boleta de 4-5 páginas escaneadas y abrir esa compra en Historial.
**Expected behavior:** Apertura fluida con una miniatura.
**Actual behavior:** Hitch visible al abrir y un pico de memoria proporcional al tamaño del lienzo.
**User impact:** La pantalla se traba al abrir compras con boleta larga; en dispositivos con poca memoria, riesgo de cierre por el sistema.
**Technical impact:** El propio código ya reconoce este riesgo para la composición («el sistema termina cerrando la app») pero no para la lectura.
**Root cause:** Se acotó el lienzo al escribir, no al leer.
**Recommended fix:** Usar `CGImageSourceCreateThumbnailAtIndex` con `kCGImageSourceThumbnailMaxPixelSize` dimensionado a la pantalla, fuera del hilo principal (`.task` en vez de `onAppear`), y cargar la imagen completa solo si se abre a pantalla completa.
**Regression risk:** Low
**Effort:** S
**How to validate the fix:** Instruments (Allocations + Time Profiler) abriendo una compra con boleta de 5 páginas.

---

**ID:** CASI-010
**Severity:** Medium
**Confidence:** Confirmed
**Category:** Rendimiento
**Title:** El índice de precios y el vocabulario del corrector se reconstruyen en cada render del sheet de boleta
**File:** `CasiListo/Views/ReceiptCaptureSheet.swift:70-79`
**Evidence:** Ambas son propiedades **computadas** de la View, no `@State`:

```swift
private var priceIndex: ReceiptPriceIndex { ReceiptPriceIndex(allItems: allItems, completedLists: completedLists) }
private var vocabulary: [String] { /* Set de todos los nombres + 355 sugeridos */ }
```

El comentario afirma «se arma una vez por pantalla en lugar de recorrer todo el historial en cada redibujo de cada fila» — **eso no es lo que hace el código**. Cada cambio de `entries`, `expandedEntryID` o cualquier `@State` del sheet las recalcula.
**How to reproduce:** Con varios meses de historial, editar el precio de una línea en la revisión de boleta.
**Expected behavior:** Edición fluida.
**Actual behavior:** Cada pulsación de tecla reconstruye un índice sobre todo el historial y un `Set` de todos los nombres de productos.
**User impact:** Latencia creciente al corregir una boleta, justo en el momento de mayor precisión requerida.
**Technical impact:** Coste O(historial) por keystroke.
**Root cause:** Propiedad computada donde se necesitaba estado derivado con invalidación explícita.
**Recommended fix:** Mover ambas a `@State` y poblarlas en `.task`, invalidando con `onChange(of: allItems)`.
**Regression risk:** Low
**Effort:** S
**How to validate the fix:** Signpost «Revisar boleta» y medición con historial sintético grande.

---

**ID:** CASI-011
**Severity:** Medium
**Confidence:** Confirmed
**Category:** Rendimiento
**Title:** El CSV completo del historial se serializa en cada render de la pestaña Historial
**File:** `CasiListo/Views/ShoppingHistoryView.swift:82`
**Evidence:** `ShareLink(item: exportCSVText(), ...)` está dentro del `.toolbar`, así que `exportCSVText()` —que agrupa todos los ítems, recorre todas las compras y serializa cada fila— se ejecuta en cada evaluación de `body`, se toque o no el botón compartir.
**How to reproduce:** Con meses de historial, abrir la pestaña Historial y desplazarse.
**Expected behavior:** El CSV se genera al tocar Exportar.
**Actual behavior:** Se genera siempre, en el hilo principal.
**User impact:** Historial lento al crecer los datos.
**Technical impact:** Ya hay un `PerformanceSignpost.measure("Exportar CSV")` alrededor, así que el coste es visible en Instruments.
**Root cause:** `ShareLink(item:)` es ansioso por diseño.
**Recommended fix:** Usar `ShareLink` con un `FileRepresentation`/`Transferable` perezoso, o generar el CSV en `@State` bajo demanda tras un botón intermedio.
**Regression risk:** Low
**Effort:** S
**How to validate the fix:** Signposts al desplazar Historial con 500+ ítems archivados.

---

## 27. Low Findings

**CASI-012 — `try? modelContext.save()` al pasar a segundo plano no guarda el contexto que usan las vistas.**
*Confidence: Highly Likely.* `CasiListoApp.swift:9,18`. `@Environment(\.modelContext)` se lee en el scope de la `App`, pero `.modelContainer(...)` se aplica a la `WindowGroup`, así que el contexto del `App` no es el que inyecta la escena. Verificado en el simulador que **no produce crash** al pasar a segundo plano. Impacto real bajo, porque toda mutación ya hace commit síncrono por el coordinador — pero es una red de seguridad que no atrapa nada. `voiceNoteService.stopPlaying()` sí funciona. *Fix:* mover el guardado a `MainTabView`, que sí está dentro del contenedor. *Effort: XS.*

**CASI-013 — Se declaran las 4 orientaciones en una app diseñada solo en vertical.**
*Confidence: Confirmed.* `project.pbxproj:523,560`. `INFOPLIST_KEY_UISupportedInterfaceOrientations` incluye landscape y portrait-upside-down. Ningún test ni captura del arnés cubre landscape. No causa rechazo, pero expone layouts nunca probados. *Fix:* restringir a `UIInterfaceOrientationPortrait`. *Effort: XS.*

**CASI-014 — Al actualizar desde un build anterior quedan 8 filas duplicadas de catálogo, congeladas para siempre.**
*Confidence: Confirmed.* `byCategory` tiene **363 entradas con repetición y 355 nombres únicos**; 7 nombres aparecen en más de una categoría (`guisantes` en 3; `albahaca`, `calamares`, `camarones apanados`, `pescado`, `postre`, `pulpo` en 2). El sembrado nuevo deduplica, pero `hasSeededCatalogV1` se fija en `true` en el primer arranque del build nuevo sin limpiar lo que dejó el anterior. **Para un 1.0 público esto afecta a cero usuarios** — solo a quien haya corrido un build previo. *Fix:* una limpieza única por nombre normalizado junto a la fijación de la clave. *Effort: S.*

**CASI-015 — La alerta de micrófono ofrece «Ir a Ajustes» para errores que no son de permisos.**
*Confidence: Confirmed.* `AddEditVoiceNoteSection.swift:110-119`. La misma alerta de tres botones se usa para `.noSpace`, `.recordingFailed` y `.playbackFailed`. Enviar a Ajustes a alguien sin espacio en disco no ayuda. *Fix:* construir los botones según el caso del error. *Effort: XS.*

**CASI-016 — Los productos sugeridos que se añadan en versiones futuras nunca llegarán a usuarios existentes.**
*Confidence: Confirmed.* `SuggestedProducts.swift:191,197`. `hasSeededCatalogV1` apaga el sembrado para siempre. Correcto hoy (evita resucitar lo que el usuario borró), pero sin versionado el catálogo queda congelado en 1.0. *Fix:* clave versionada por lote (`hasSeededCatalogV2`) que siembre solo los nombres nuevos. *Effort: S.*

**CASI-017 — Registrar una boleta pisa la cantidad escrita a mano.**
*Confidence: Confirmed.* `ReceiptServices.swift:806`. `existingItem.quantity = entry.quantity > 1 ? "\(entry.quantity)" : ""` borra «1 kg» y lo deja vacío. El comentario lo justifica, pero es pérdida de un dato que el usuario escribió. *Fix:* conservar la cantidad original cuando la boleta reporta una sola unidad. *Effort: XS.*

---

## 28. Improvement Opportunities

**Informational:**

- **CASI-018** — Renombrar una categoría deja huérfano su estado de colapso
  (`collapsedCategoryNames-<uuid>` guarda nombres). Cosmético: la categoría reaparece expandida.
- **CASI-019** — `hasSeededDefaultProducts` es una **clave muerta**: solo se hace
  `removeObject`/`set(false)`, nadie la lee. Las claves de `UserDefaults` son literales repetidos sin
  enum central.
- **CASI-020** — **El piso es iOS 26.0 y solo iPhone**, no «iOS 17+». Es una decisión de negocio
  legítima (permite Liquid Glass sin ramas de compatibilidad y cero `#available` en el árbol), pero
  reduce el mercado alcanzable. Igualmente, Swift es 6.0 y no 5.9, y **Core Location no existe**.
  Conviene alinear la documentación y las expectativas antes de definir la estrategia de App Store.

**Mejoras concretas que valen la pena:**

- Un enum central para las claves de `UserDefaults`.
- Reemplazar las seis constantes duplicadas del contrato App Group por un archivo compartido entre
  targets.
- `XCUIApplication.performAccessibilityAudit()` en al menos una pantalla por pestaña.

---

## 29. Functions Worth Adding

### P1 — Debería existir antes de 1.0

1. **Exportación/respaldo de datos del usuario.** Sin backend, el dispositivo es la única copia. Ya
   existe la infraestructura (`CSVSerializer`, `ShareLink`) pero solo exporta el historial. Un export
   completo de listas activas sería una red de seguridad barata frente a CASI-003. *Necesidad real:
   los datos son irremplazables.*
2. **Descubribilidad de «Posponer» y «No encontrado».** Son dos de los cuatro estados del modelo y
   solo viven en un menú contextual. Una swipe action adicional o un botón en la fila. *Necesidad
   real: funcionalidad construida que nadie encontrará.*

### P2 — Muy recomendable

3. **Familias de widget de pantalla bloqueada** (`.accessoryRectangular`, `.accessoryInline`). Para
   una lista de compras, mirar la muñeca o la pantalla bloqueada en el pasillo es el caso de uso
   central. La infraestructura de snapshot ya existe.
4. **Widget interactivo con App Intents**: marcar comprado sin abrir la app.

### P3 — Nice to have

5. **Compartir una lista entre dos personas** (vía CloudKit o export/import de un archivo). Es la
   petición más común en apps de compras.
6. **Mostrar `updatedAt` en el widget** cuando el snapshot sea viejo.

---

## 30. Functions Worth Simplifying or Removing

1. **La plantilla «Catálogo completo» (355 productos).** Añadir 355 productos pendientes a una lista
   de compra no es un caso de uso real; es el origen de la heurística de colapso que causa CASI-007 y
   del literal «355 pendientes» que ata los tests de captura. El Catálogo ya cumple esa función
   mejor. **Quitarla simplificaría tres cosas a la vez.**
2. **Cuatro estados de producto.** `skipped` y `unavailable` añaden ramas en `summary`,
   `ListCardView`, el historial y el CSV, a cambio de una función escondida en un menú contextual. O
   se hacen descubribles (P1.2) o se recortan a comprado/pendiente.
3. **El botón «Nueva» de la tarjeta de resumen** duplica el «+» de la toolbar en la misma pantalla.

---

## 31. Technical Debt

| Deuda | Impacto | Coste de saldarla |
|---|---|---|
| Contrato App Group triplicado a mano en 6 sitios | Un typo = widget silenciosamente roto | S |
| Doble fuente de verdad en `status` y `category` | Cada lectura pasa por un getter con fallback | M |
| `ReceiptCaptureSheet.swift` con 1052 líneas y 14 tipos en `ReceiptServices.swift` | Navegabilidad; un tipo no vive en su archivo | M |
| Claves de `UserDefaults` como literales repetidos + una clave muerta | Riesgo de typo silencioso | XS |
| Sin SwiftLint/SwiftFormat ni check de estilo en CI | La regla de 100 líneas del README se incumple en 46 de 75 archivos | S |
| `context.rollback()` en los caminos de error descarta todo el contexto | Efectos colaterales fuera del alcance del llamador | M |
| `AUDITORIA_LANZAMIENTO_APP_STORE_2026-08-12.md` cita archivos que no existen | Confunde a quien navegue el repo | XS |
| `docs/VALIDACION_LANZAMIENTO.md` modificado sin commitear | La referencia real de secretos de CI no está en la rama | XS |

---

## 32. Manual Release Checklist

No penalizado en el puntaje: no es inspeccionable desde el código.

- [ ] **Registrar el App Group `group.com.allopze.CasiListo`** en el Developer Portal y confirmar que
      aparece en el perfil de distribución de **ambos** targets. *(Crítico — ver CASI-003.)*
- [ ] Verificar que `https://casilisto-privacy.pages.dev/privacy/` y `/support/` responden 200 **desde
      una red pública**.
- [ ] Confirmar los secretos en Actions: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`,
      `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`; y las variables `PUBLIC_SUPPORT_EMAIL`,
      `PUBLIC_POLICY_EFFECTIVE_DATE`.
- [ ] Disparar `release-testflight.yml` y verificar el archive, el export y la subida.
- [ ] Instalar desde TestFlight **en un iPhone físico** y ejecutar: crear lista → añadir → comprar →
      boleta con cámara real → archivar → historial → widget.
- [ ] Probar la **actualización**: instalar el build anterior, crear datos, actualizar, confirmar que
      los datos siguen ahí.
- [ ] Grabar una nota de voz en dispositivo real y probar una interrupción por llamada.
- [ ] Añadir ambos tamaños de widget en un dispositivo real; verificar claro, oscuro y **tinted**.
- [ ] App Store Connect: categoría (Estilo de vida o Productividad), clasificación por edad (4+),
      territorios (Chile), descripción y palabras clave en español.
- [ ] **App Privacy: «Data Not Collected»** — coherente con el código verificado.
- [ ] **Accessibility Nutrition Labels**: VoiceOver, Larger Text, Sufficient Contrast, Differentiate
      Without Color, Reduced Motion, Dark Interface.
- [ ] **Capturas**: generarlas con datos realistas, **no con el fixture de 363 productos de test**
      (riesgo de guideline 2.3).
- [ ] Notas para el revisor: aclarar que la app es 100 % local, sin cuenta, y que cámara y micrófono
      son opcionales.
- [ ] Probar con VoiceOver y con texto en tamaño de accesibilidad en dispositivo real.

---

## 33. Prioritized Fix Plan

### P0 — Release blockers

| ID | Componente | Esfuerzo | Riesgo | Dependencia | Criterio de aceptación |
|---|---|---|---|---|---|
| CASI-002 | `CasiListoTests/Temp*.swift` | XS | Low | — | `xcodebuild test` con exit 0; el comportamiento documentado convertido en tests afirmativos |
| CASI-001 | Pipeline de release | M | Low | App Group registrado en el portal | Build en TestFlight instalado en iPhone físico, con el recorrido completo verificado |

### P1 — Antes de 1.0

| ID | Componente | Esfuerzo | Riesgo | Dependencia | Criterio de aceptación |
|---|---|---|---|---|---|
| CASI-003 | `CasiListoSchemaMigration.swift` | S | Medium | CASI-001 | `ModelConfiguration` explícita + test que asserta la ruta del store |
| CASI-004 | Widget | XS | Low | — | Instalación limpia sin listas muestra «Abre CasiListo para empezar» |
| CASI-006 | `unitCount` / quick add | S | Medium | — | `QuantitySemantics` única, con test de ambos lados |
| CASI-007 | `ShoppingListViewModel` | XS | Low | — | Importar 6 productos los deja visibles; 363 siguen colapsados |
| CASI-008 | `CategoryManagementView` | S | Low | — | La fallback no es editable; el bootstrap no crea un «Varios» duplicado |
| CASI-013 | `project.pbxproj` | XS | Low | — | Solo `UIInterfaceOrientationPortrait` |
| P1.2 | Descubribilidad de Posponer/No encontrado | S | Low | — | Alcanzable sin menú contextual |

### P2 — 1.1 / primeras actualizaciones

| ID | Componente | Esfuerzo | Riesgo | Criterio de aceptación |
|---|---|---|---|---|
| CASI-009 | `ShoppingHistoryDetailView` | S | Low | Miniatura downsampled fuera del hilo principal |
| CASI-010 | `ReceiptCaptureSheet` | S | Low | `priceIndex`/`vocabulary` como estado derivado |
| CASI-011 | `ShoppingHistoryView` | S | Low | CSV generado bajo demanda |
| CASI-005 | Migración | M | Medium | `SchemaV2` + `MigrationStage` + test con fixture V1 |
| CASI-014 / CASI-016 | Sembrado de catálogo | S | Low | Limpieza de duplicados + clave versionada por lote |
| CASI-012 / CASI-015 / CASI-017 | Varios | XS c/u | Low | Ver cada hallazgo |
| P1.1 | Export/backup completo | M | Low | El usuario puede sacar sus datos del dispositivo |

### P3 — Futuro

Widget de pantalla bloqueada, widget interactivo con App Intents, listas compartidas, enum central de
`UserDefaults`, deduplicación del contrato App Group, SwiftLint en CI.

---

## 34. Final Recommendation

**No publicaría CasiListo hoy, y la razón no es la calidad del producto.**

El producto está en mejor forma que la mayoría de las apps que sí se publican: sin red, sin
analytics, sin dependencias externas, con integridad de datos tomada en serio, accesibilidad real y
medida, y un pipeline de OCR de boletas chilenas respaldado por 80 tests contra boletas de verdad. La
promesa de «app local y privada» se verificó y es literalmente cierta. El sistema de diseño calcula
contraste WCAG y lo asserta en tests. Los comentarios del código citan el bug concreto que motivó
cada línea — eso es señal de un proyecto que aprendió de sus propios errores.

Pero **no se puede publicar lo que nunca se ha construido para distribución**. No existe un archive
firmado, ni un `.ipa`, ni una subida. El proyecto depende por completo de firma automática que nunca
se ejercitó, y la base de datos entera vive en el App Group por un default implícito que ese mismo
pipeline no verificado tiene que respetar. Y el gate de verificación está en rojo por dos archivos
que sobraron.

Los dos bloqueadores son horas, no semanas. Uno se resuelve con `rm` de dos archivos. El otro con una
ejecución del workflow y una tarde con un iPhone en la mano.

**Aprobaría el lanzamiento en cuanto haya un build de TestFlight instalado en un dispositivo físico
donde los datos sobrevivan a una actualización.** Ese es el único experimento que falta, y es
exactamente el que nunca se ha hecho.

---

# CASILISTO RELEASE REPORT

**Technical Score:** 78,7 / 100

**Nota:** 5,6 / 7,0

**Release Status:** 🔴

**App Review First-Pass Estimate:** 80 %

**Critical:** 1
**High:** 2
**Medium:** 8
**Low:** 6
**Informational:** 3

**Release Blockers:** 2

**Product maturity:**
**Release Candidate**

**Recommendation:**
**FIX BEFORE LAUNCH**

**Would you personally approve this release?**
**NO**

**Main reason:**
El producto está listo; el lanzamiento no. Nunca se ha construido, firmado ni subido un build de
distribución, y la suite de verificación está en rojo por dos archivos temporales. Además, toda la
base de datos vive en el App Group por un default implícito que ese pipeline no probado debe
respetar, y si falla el usuario ve una app vacía sin ningún aviso. Son horas de trabajo, no semanas.
