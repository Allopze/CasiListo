# Auditoria UI/UX y producto iOS - CasiListo

## Resumen ejecutivo

CasiListo ya tiene una base util: una lista persistente con SwiftData, entrada rapida, autocompletado, agrupacion por categorias, filtro por supermercado, modo compra, notas de voz, presupuesto estimado y algunos detalles modernos como `sheet(item:)`, `@Observable` y Liquid Glass.

El principal problema es de modelo de producto: la app se presenta como "lista de la compra", pero tecnicamente solo existe una coleccion global de `ShoppingItem`, sin entidad `ShoppingList`, sin historial real de listas y sin flujo claro de cierre de compra. A nivel UI, el riesgo mas serio es que el modo compra usa muchos textos y controles blancos sobre superficies claras, lo que puede dejar acciones casi invisibles en modo claro. En accesibilidad, hay buenas intenciones, pero se sustituyo Dynamic Type por un slider propio y hay controles tactiles por debajo del tamano recomendado para iOS.

Nota de tooling: en esta sesion no hay recurso MCP/Context7 expuesto; `list_mcp_resources` no devolvio recursos. Para contrastar criterios actuales use las skills SwiftUI indicadas, el codigo del repo y documentacion primaria de Apple sobre accesibilidad, botones y Liquid Glass.

## Problemas criticos

### 1. No existe el concepto de lista ni historial de compras

- Descripcion: el modelo persistido es solo `ShoppingItem`; no hay `ShoppingList`, estado de lista, fecha de cierre, archivo de compra o relacion item-lista. `ContentView` consulta todos los items con `@Query` y decide si la app esta vacia por `allItems.isEmpty`.
- Impacto en el usuario: no puede "crear una lista" de forma real, separar una compra actual de otra anterior, consultar listas pasadas ni reiniciar una compra sin borrar productos.
- Pantallas o archivos relacionados: `CasiListo/Models/ShoppingItem.swift:6`, `CasiListo/Views/ContentView.swift:7`, `CasiListo/Views/ContentView.swift:36`, `CasiListo/Models/UserStats.swift:4`.
- Severidad: alta.
- Recomendacion concreta: introducir una entidad SwiftData `ShoppingList` con `title`, `createdAt`, `completedAt`, `status`, `storeScope` y relacion a items. El flujo principal deberia abrir la lista activa y mover las completadas a historial.

```swift
@Model
final class ShoppingList {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var completedAt: Date?
    var isArchived = false
    @Relationship(deleteRule: .cascade) var items: [ShoppingItem] = []

    init(title: String) {
        self.title = title
    }
}
```

### 2. El primer inicio no muestra estado vacio porque se siembran cientos de productos

- Descripcion: `ContentView.task` ejecuta `SuggestedProducts.seedDefaultItems(in:)` una vez y marca `hasSeededDefaultProducts`. Eso hace que `EmptyStateView` casi nunca exista para usuarios nuevos.
- Impacto en el usuario: la app arranca como una lista enorme prefabricada, no como una lista creada por el usuario. Para una app personal puede ser intencional, pero para un producto general rompe onboarding, ownership y claridad.
- Pantallas o archivos relacionados: `CasiListo/Views/ContentView.swift:86`, `CasiListo/Views/ContentView.swift:88`, `CasiListo/Models/SuggestedProducts.swift:154`, `PLAN.md:9`.
- Severidad: alta si la app apunta a usuarios generales; media si es una app familiar/personal.
- Recomendacion concreta: convertir el seeding en una pantalla de onboarding: "Usar plantilla familiar", "Empezar vacio", "Importar productos frecuentes". Guardar sugerencias en un catalogo separado, no como items pendientes.

### 3. Modo compra no es legible en modo claro

- Descripcion: varias vistas del modo compra usan `.foregroundStyle(.white)` y fondos `Color.white.opacity(...)` sobre `Color.appBackground` o `Color.appCardBackground`, que en modo claro son superficies blancas/crema. Ejemplos: botones "Atras"/cerrar, titulo de categoria y controles inferiores.
- Impacto en el usuario: acciones criticas pueden quedar invisibles durante una compra real, justo cuando la app debe ser mas rapida y confiable.
- Pantallas o archivos relacionados: `CasiListo/Views/Components/ShoppingModeHeaderView.swift:25`, `CasiListo/Views/Components/ShoppingModeHeaderView.swift:28`, `CasiListo/Views/Components/ShoppingModeHeaderView.swift:56`, `CasiListo/Views/Components/ShoppingModeHeaderView.swift:58`, `CasiListo/Views/ShoppingModeActiveView.swift:77`, `CasiListo/Views/ShoppingModeActiveView.swift:79`, `CasiListo/Views/ShoppingModeActiveView.swift:118`, `CasiListo/Views/ShoppingModeActiveView.swift:157`.
- Severidad: alta.
- Recomendacion concreta: crear tokens especificos para modo compra (`shoppingModeSurface`, `shoppingModeText`, `shoppingModeControlBackground`) o forzar una paleta oscura completa dentro de `ShoppingModeView`. La solucion mas simple: usar `Color.appTextPrimary` para textos y `Color.appSeparator`/material para superficies; reservar blanco solo sobre fondos oscuros garantizados.

### 4. Completar compra no cierra ni limpia la lista de forma comprensible

- Descripcion: al completar una tienda, `ShoppingModeView` muestra celebracion y registra estadisticas, pero no archiva la compra, no crea historial, no ofrece "guardar y limpiar", ni explica que los productos quedan marcados como comprados hasta que el usuario use "Borrar comprados" en el menu.
- Impacto en el usuario: despues de "Compra Completada", la lista principal puede quedar llena de items comprados; la accion final no se siente final.
- Pantallas o archivos relacionados: `CasiListo/Views/ShoppingModeView.swift:20`, `CasiListo/Views/ShoppingModeView.swift:25`, `CasiListo/Views/ShoppingModeView.swift:63`, `CasiListo/Views/ContentView.swift:165`.
- Severidad: alta.
- Recomendacion concreta: en `CompletionCelebrationView`, despues de "Volver a la Lista", ofrecer acciones: "Archivar compra y limpiar comprados", "Mantener lista", "Crear nueva lista desde frecuentes". Si se introduce `ShoppingList`, completar deberia asignar `completedAt`.

### 5. Reordenar productos existe en codigo, pero no es descubrible

- Descripcion: `CategorySectionView` implementa `.onMove`, pero no hay `EditButton`, modo edicion visible, drag handle propio, ni onboarding contextual. En iOS, para muchos usuarios el reordenamiento de `List` no se descubre sin modo edicion.
- Impacto en el usuario: "Organizar productos" parece no existir, aunque hay logica tecnica.
- Pantallas o archivos relacionados: `CasiListo/Views/CategorySectionView.swift:78`, `CasiListo/Views/ContentView.swift:55`.
- Severidad: media-alta.
- Recomendacion concreta: anadir un boton "Ordenar" en el menu que active `EditMode`, o crear un modo de organizacion con handles visibles por categoria. Persistir y validar `sortOrder` con tests.

### 6. Modo compra obliga a tocar un checkbox pequeno en vez de la fila completa

- Descripcion: en la lista normal, `ItemRowView` hace tappable casi toda la tarjeta. En modo compra, `ShoppingModeItemRow` solo hace `Button` al circulo de 42 pt.
- Impacto en el usuario: durante una compra, con una mano o caminando, el target pequeno aumenta errores y friccion.
- Pantallas o archivos relacionados: `CasiListo/Views/ItemRowView.swift:20`, `CasiListo/Views/Components/ShoppingModeItemRow.swift:11`, `CasiListo/Views/Components/ShoppingModeItemRow.swift:28`.
- Severidad: alta.
- Recomendacion concreta: convertir toda la fila de `ShoppingModeItemRow` en `Button`, con `contentShape(Rectangle())`, minimo 56 pt de alto y acciones accesibles.

```swift
Button(action: onToggle) {
    rowContent
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.accessibilityLabel("\(item.name), \(item.quantity), \(item.isPurchased ? "comprado" : "pendiente")")
.accessibilityHint("Toca para marcar o desmarcar")
```

### 7. Faltan descripciones de privacidad para permisos sensibles

- Descripcion: la app pide microfono (`AVAudioApplication.requestRecordPermission`) y localizacion Always (`requestAlwaysAuthorization`), pero no aparecen claves `NSMicrophoneUsageDescription`, `NSLocationWhenInUseUsageDescription` o `NSLocationAlwaysAndWhenInUseUsageDescription` en el proyecto generado.
- Impacto en el usuario: en dispositivo real puede fallar al solicitar permisos o mostrar una experiencia poco confiable; en revision App Store seria un riesgo claro.
- Pantallas o archivos relacionados: `CasiListo/Views/Components/AddEditVoiceNoteSection.swift:93`, `CasiListo/Services/GeofenceService.swift:39`, `CasiListo.xcodeproj/project.pbxproj:402`.
- Severidad: alta.
- Recomendacion concreta: agregar las claves de privacidad al target. Textos sugeridos:
  - `NSMicrophoneUsageDescription`: "CasiListo usa el microfono para guardar notas de voz en productos de tu lista."
  - `NSLocationWhenInUseUsageDescription`: "CasiListo usa tu ubicacion para recordarte compras pendientes cerca del supermercado."
  - `NSLocationAlwaysAndWhenInUseUsageDescription`: "CasiListo puede avisarte cuando pasas cerca de un supermercado con productos pendientes."

## Mejoras de UI

- Corregir contraste del amarillo principal. `Theme.accentYellow` es `#F5C518`; se usa con texto blanco en varios lugares, por ejemplo el CTA "Comenzar Compra" y contadores de categoria. Blanco sobre ese amarillo no alcanza contraste suficiente para texto pequeno. Usar negro o `Color.appTextPrimary` sobre amarillo: `foregroundStyle(.black)` en `StoreSelectorView.swift:58` y `CategorySectionView.swift:111`.
- Reducir dependencia de tarjetas con sombras. La lista usa card dentro de `List`, headers con sombra y filas con sombra (`CategorySectionView.swift:128`, `CategorySectionView.swift:146`). Para una app de uso repetido conviene una jerarquia mas serena: headers planos, filas con separador suave o material, menos elevacion.
- Hacer el resumen mas escaneable. `SummaryBarView` mezcla conteos, totales y boton de visibilidad en una sola fila. En pantallas pequenas o con texto grande puede comprimirse. Recomiendo dos columnas: "Pendiente" y "Carro", con total debajo si existe.
- Diferenciar mejor estado comprado. La app usa opacidad, tachado y gris muy claro (`ItemRowView.swift:81`, `Theme.swift:273`). El gris comprado en modo claro es demasiado bajo. Usar un chip "Comprado" o mover items comprados a una seccion plegable "Comprados".
- Unificar iconografia de acciones. La lista normal tiene editar como boton circular, swipe, context menu y toolbar de add. Mantener: fila toca para marcar, swipe trailing para editar/eliminar, boton de detalles solo si hay muchas acciones. El lapiz permanente compite visualmente con el checkbox.
- Replantear `BottomAddBarView`. La barra inferior es una buena idea, pero los botones de `plus.circle.fill` y `ellipsis.circle.fill` son de 28 pt sin frame tactil minimo (`BottomAddBarView.swift:60`). Darles `frame(width: 44, height: 44)` y etiquetas visibles en VoiceOver.
- Ajustar la UI de categorias en `AddEditItemSheet`. `CategoryPickerView` usa grid adaptativo de 140 pt y chips con `lineLimit(1)`. Nombres como "Panaderia y dulces" o "Bebidas alcoholicas" pueden truncarse. Usar `GridItem(.adaptive(minimum: 160))` o permitir 2 lineas.
- Modo compra deberia tener una superficie visual propia. Hoy hereda `Color.appBackground` y algunas decisiones oscuras. Crear un wrapper:

```swift
struct ShoppingModeTheme {
    static let background = Color(light: Color(hex: "101412"), dark: Color(hex: "101412"))
    static let surface = Color.white.opacity(0.08)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
}
```

## Mejoras de UX

- Separar "catalogo frecuente" de "lista actual". Las sugerencias de `SuggestedProducts` deben ayudar a anadir rapido, no aparecer todas como compra pendiente. La pantalla inicial ideal: lista activa vacia + chips de frecuentes + boton "usar plantilla".
- Hacer la entrada rapida mas potente: permitir "2 leche", "pan x3", "tomates 1 kg" y parsear cantidad automaticamente. Esto reduce pasos en la accion mas frecuente.
- Agregar "deshacer" tras borrar o marcar muchos productos. Actualmente `clearPurchased` elimina directamente tras confirmacion (`ShoppingListViewModel.swift:136`). Mostrar snackbar/overlay "Comprados borrados - Deshacer" durante 5 segundos.
- En modo compra, mostrar todas las categorias en una barra inferior o sheet rapido. El salto secuencial por categoria es util, pero si el usuario cambia de pasillo necesita saltar a "Bebidas" sin pulsar varias veces.
- Evitar auto-avance de categoria sin control. `ShoppingModeViewModel` avanza tras 0.6 s cuando no quedan pendientes (`ShoppingModeViewModel.swift:105`). Puede sorprender si el usuario se equivoco marcando. Mejor mostrar "Categoria completada" con boton "Siguiente" y auto-avance opcional en ajustes.
- Permitir "no encontrado" o "posponer". En una compra real, no todos los productos se compran. Agregar estado `skipped`/`unavailable` evita que el progreso fuerce comprar todo.
- Hacer el cierre de compra explicito: "Finalizar compra" siempre disponible, aunque queden pendientes, con resumen de comprados, pendientes y gasto.
- Mejorar busqueda: actualmente `searchable` filtra por nombre, nota y categoria (`ShoppingListViewModel.swift:52`). Agregar busqueda por tienda y sinonimos frecuentes; mostrar CTA "Anadir '\(searchText)'" en `NoResultsView`.
- Ajustar geofencing a UX de permisos. No pedir Always de golpe. Primero explicar valor, pedir notificaciones, luego ubicacion when-in-use, y solo pedir Always cuando el usuario active recordatorios en segundo plano.

## Mejoras de accesibilidad

- Adoptar Dynamic Type real. El proyecto usa `@AppStorage("accessibilityTextSizeScale")` y fuentes manuales (`Theme.swift:34`). Esto no respeta automaticamente el tamano de texto del sistema. Alternativa:

```swift
Text(item.name)
    .font(.body.weight(.regular))
    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
```

Para medidas no tipograficas, usar `@ScaledMetric`:

```swift
@ScaledMetric(relativeTo: .body) private var checkboxSize = 32
```

- Asegurar minimo tactil de 44x44 pt en controles principales. Apple recomienda controles iOS de 44x44 pt por defecto. Hoy hay botones de 32, 36x32, 40 y 42 pt: `ItemRowView.swift:166`, `SummaryBarView.swift:45`, `VoiceNotePlayerButton.swift:50`, `ShoppingModeItemRow.swift:28`, `Theme.swift:167`.
- Revisar contraste en claro y oscuro. Problemas concretos:
  - `Color.appTextPurchased` claro `#C0C0C0` sobre `#FAF8F5` es demasiado tenue para notas o estados.
  - texto blanco sobre `Theme.accentYellow` aparece en `StoreSelectorView.swift:58` y `CategorySectionView.swift:111`.
  - modo compra usa blanco sobre superficies claras.
- Mejorar VoiceOver de filas. `ItemRowView` esta bastante bien agrupada, pero `ShoppingModeItemRow` no tiene `accessibilityLabel`, `accessibilityValue` ni accion custom. Debe anunciar "Pendiente/Comprado" y permitir accion de marcar.
- Anadir rasgo seleccionado a filtros de supermercado. `StoreFilterBar` cambia visualmente el chip, pero no agrega `.accessibilityAddTraits(.isSelected)` ni `accessibilityValue`. Esto es importante porque el color no debe ser el unico indicador.
- En `CategorySectionView`, el header combina categoria, conteo y chevron, pero no anuncia estado expandido/colapsado como value. Agregar:

```swift
.accessibilityLabel("\(category.displayName), \(items.count) productos")
.accessibilityValue(isCollapsed ? "Colapsada" : "Expandida")
```

- Respetar Reduce Motion. `CompletionCelebrationView` genera 70 particulas y animaciones infinitas (`CompletionCelebrationView.swift:180`, `CompletionCelebrationView.swift:231`). Usar `@Environment(\.accessibilityReduceMotion)` para desactivar confeti o renderizar una version estatica.
- Evitar depender solo de haptics. La app usa haptics bien, pero acciones como anadir rapido, grabar o completar deben tener feedback visual persistente para usuarios con sensibilidad tactil reducida.

## Observaciones tecnicas

- Configuracion Swift desalineada. El target usa `IPHONEOS_DEPLOYMENT_TARGET = 26.5`, pero `SWIFT_VERSION = 5.0` (`CasiListo.xcodeproj/project.pbxproj:420`). Para un proyecto con `@Observable`, `@MainActor` y SwiftData moderno, subir a Swift 6 y activar strict concurrency ayudaria a detectar problemas antes.
- Filtros y totales se recalculan demasiadas veces en render. `ShoppingListView.body` calcula grupos, conteos y totales en varios pases (`ShoppingListView.swift:14`, `ShoppingListView.swift:25`). En `ShoppingModeViewModel`, `categories`, `activeItems`, `purchasedCount`, `pendingCount` filtran repetidamente (`ShoppingModeViewModel.swift:16`, `ShoppingModeViewModel.swift:28`, `ShoppingModeViewModel.swift:44`). Con 290 items esta bien; con listas compartidas o historiales puede causar invalidaciones.
- `@Observable` se usa como view model amplio. Muchas vistas reciben `ShoppingListViewModel` completo cuando solo necesitan acciones o valores concretos (`ShoppingListView.swift:7`, `CategorySectionView.swift:9`). Esto aumenta fan-out de observacion. Pasar bindings/closures o derived view data reduce renders.
- Uso de `DispatchQueue.main.asyncAfter` en modelos `@MainActor`. `ShoppingModeViewModel.checkAutoAdvance` y `CompletionCelebrationView.triggerTripleHaptic` usan GCD (`ShoppingModeViewModel.swift:105`, `CompletionCelebrationView.swift:196`). Preferir `Task { try? await Task.sleep(...) }`, guardando cancelacion si el usuario sale.
- `Timer` en `AddEditVoiceNoteSection` puede sobrevivir a cambios de vista si no se detiene al desaparecer (`AddEditVoiceNoteSection.swift:101`). Agregar `.onDisappear { stopRecordingIfNeeded() }`.
- `VoiceNotePlayerButton` calcula alturas con `CGFloat.random` dentro del `body` animado (`VoiceNotePlayerButton.swift:28`). Eso puede producir cambios visuales no deterministas por render. Precalcular alturas o usar `TimelineView`.
- `try? context.save()` oculta errores criticos. En `moveItem`, `toggleItem`, `seedDefaultItems`, audio y stats se silencian fallos. Para UX, los errores de persistencia deben al menos emitir un estado visible o log estructurado.
- `formattedPrice` no usa `NumberFormatter` localizado (`ShoppingItem.swift:62`). En Chile deberia contemplar moneda local y separadores: `1500` vs `$1.500`. Usar `Decimal` para dinero y `FormatStyle.Currency`.
- Liquid Glass esta bien encapsulado, pero el target minimo iOS 26.5 vuelve muertos los fallbacks `#available(iOS 26, *)`. Si se quiere compatibilidad real con iOS 17/18, bajar deployment target. Si se quiere solo iOS 26+, simplificar wrappers.
- `UIImage(named:)` en `LogoView` esta bien para assets pequenos, pero se hace desde `body` (`EmptyStateView.swift:48`). No es critico, aunque podria ser `Image("AppLogo")` con fallback eliminado si el asset existe.
- Tests actuales cubren solo totales, conteos y sort order (`CasiListoTests.swift:8`). Faltan tests de filtros por tienda, finalizacion de compra, parseo de precio, permisos, reordenamiento persistente y flujos UI basicos.

## Lista priorizada de acciones

### 1. Cambios rapidos de alto impacto

1. Corregir contraste de modo compra en claro: reemplazar blancos sobre superficies claras y definir tema propio para modo compra.
2. Hacer toda la fila de `ShoppingModeItemRow` tappable y accesible, no solo el checkbox.
3. Aumentar botones tactiles pequenos a minimo 44x44 pt.
4. Cambiar texto blanco sobre amarillo por negro o color primario.
5. Agregar claves de privacidad de microfono y ubicacion al Info.plist generado.
6. Agregar CTA "Anadir este producto" en `NoResultsView`.
7. Agregar `accessibilityValue` y rasgos seleccionados en filtros, categorias y modo compra.
8. Respetar Reduce Motion en confeti y waveform.

### 2. Mejoras importantes de mediano esfuerzo

1. Crear modo "Ordenar" con `EditMode` visible y persistencia validada.
2. Redisenar cierre de compra: resumen, archivar/limpiar, mantener pendientes.
3. Separar catalogo de sugerencias de items pendientes; no sembrar todo como compra activa por defecto.
4. Reemplazar slider propio de texto por Dynamic Type + `@ScaledMetric`, manteniendo el slider solo como opcion extra si realmente aporta.
5. Cachear/derivar grupos, conteos y totales en un `ShoppingListSnapshot`.
6. Agregar estados "no encontrado" o "pospuesto" en modo compra.
7. Usar formato monetario localizado con `Decimal`.
8. Agregar UI tests de crear producto, marcar comprado, borrar, modo compra y finalizacion.

### 3. Mejoras avanzadas o de mayor alcance

1. Introducir `ShoppingList` y migrar datos actuales a una lista activa.
2. Crear historial real de compras con detalle de fecha, tienda, productos y gasto.
3. Sincronizar con iCloud/CloudKit y preparar listas compartidas.
4. Crear motor de sugerencias basado en frecuencia, tienda y estacionalidad.
5. Implementar widgets, App Intents y Atajos de Siri.
6. Crear onboarding de plantillas, permisos y supermercados favoritos.
7. Agregar escaneo de codigo de barras con base de datos de productos.

## Nuevas funcionalidades recomendadas

### 1. Listas activas e historial

- Nombre de la funcionalidad: Listas e historial de compras.
- Que problema resuelve: separa compra actual de compras pasadas.
- Como funcionaria: el usuario crea "Compra semanal", la completa, y queda archivada con fecha, tienda, productos y gasto.
- Dificultad estimada: alta.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

### 2. Catalogo de productos frecuentes

- Nombre de la funcionalidad: Productos frecuentes.
- Que problema resuelve: evita sembrar cientos de productos como pendientes.
- Como funcionaria: sugerencias aparecen al escribir y en chips rapidos; el usuario puede anadir frecuentes con un toque.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

### 3. Modo comprando con una mano

- Nombre de la funcionalidad: Modo comprando optimizado.
- Que problema resuelve: reduce errores cuando el usuario esta en el supermercado.
- Como funcionaria: filas grandes, tocar toda la fila, botones abajo, saltar seccion, finalizar compra, posponer item.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

### 4. Categorias automaticas robustas

- Nombre de la funcionalidad: Autocategoria por producto.
- Que problema resuelve: reduce pasos al anadir productos.
- Como funcionaria: al escribir "leche 2", la app asigna lacteos, cantidad 2 y tienda probable.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### 5. Reordenar por pasillos

- Nombre de la funcionalidad: Orden de supermercado.
- Que problema resuelve: las categorias no siempre coinciden con el recorrido real.
- Como funcionaria: el usuario define orden de secciones por tienda; modo compra recorre ese orden.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### 6. Cantidades y unidades inteligentes

- Nombre de la funcionalidad: Cantidades estructuradas.
- Que problema resuelve: cantidad hoy es texto libre, dificil de resumir o reutilizar.
- Como funcionaria: parser de "2 kg arroz", unidades sugeridas y edicion rapida.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### 7. Presupuesto estimado

- Nombre de la funcionalidad: Presupuesto de compra.
- Que problema resuelve: el precio existe, pero no hay control de presupuesto.
- Como funcionaria: el usuario define presupuesto, ve pendiente/comprado y alertas si supera el limite.
- Dificultad estimada: media.
- Valor para el usuario: medio-alto.
- Prioridad recomendada: P1.

### 8. Listas compartidas

- Nombre de la funcionalidad: Compartir y colaborar.
- Que problema resuelve: compras familiares no son individuales.
- Como funcionaria: compartir lista por iCloud/CloudKit, cambios en vivo, autores por item.
- Dificultad estimada: alta.
- Valor para el usuario: alto.
- Prioridad recomendada: P2.

### 9. Recordatorios inteligentes

- Nombre de la funcionalidad: Recordatorios por tienda y horario.
- Que problema resuelve: recordar comprar en el momento correcto.
- Como funcionaria: notificaciones al acercarse a supermercados, con permisos graduales y resumen de pendientes.
- Dificultad estimada: media-alta.
- Valor para el usuario: medio.
- Prioridad recomendada: P2.

### 10. Widgets y Live Activity

- Nombre de la funcionalidad: Widget de lista pendiente.
- Que problema resuelve: consultar rapido sin abrir la app.
- Como funcionaria: widget con proximos productos pendientes y boton para abrir modo compra.
- Dificultad estimada: media.
- Valor para el usuario: medio.
- Prioridad recomendada: P2.

### 11. Atajos de Siri y App Intents

- Nombre de la funcionalidad: Anadir por voz con Siri.
- Que problema resuelve: entrada rapida sin tocar pantalla.
- Como funcionaria: "Oye Siri, anade leche a CasiListo"; intent crea item y sugiere categoria.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P2.

### 12. Escaneo de codigos de barras

- Nombre de la funcionalidad: Escaner de productos.
- Que problema resuelve: anadir productos especificos rapidamente.
- Como funcionaria: camara escanea codigo, rellena nombre, marca, precio estimado si existe.
- Dificultad estimada: alta.
- Valor para el usuario: medio.
- Prioridad recomendada: P3.

### 13. Recetas o planificacion de comidas

- Nombre de la funcionalidad: Planificador de comidas.
- Que problema resuelve: convertir recetas en lista de compra.
- Como funcionaria: usuario guarda recetas y anade ingredientes faltantes a una lista.
- Dificultad estimada: alta.
- Valor para el usuario: medio.
- Prioridad recomendada: P3.

## Roadmap sugerido

### Version 1.1: mejoras rapidas

- Corregir contraste y modo claro del modo compra.
- Ampliar targets tactiles a 44x44 pt.
- Hacer toda la fila de modo compra tappable.
- Agregar claves de privacidad para microfono y ubicacion.
- Agregar valores/labels accesibles en filtros, categorias y modo compra.
- Respetar Reduce Motion en celebracion y animaciones infinitas.
- Agregar accion en `NoResultsView` para crear el producto buscado.
- Agregar UI tests basicos de crear, marcar y borrar producto.

### Version 1.2: funcionalidades utiles de producto

- Separar productos frecuentes de lista activa.
- Crear modo "Ordenar" visible.
- Redisenar finalizacion de compra con opciones de archivar/limpiar/mantener.
- Mejorar entrada rapida con parseo de cantidad.
- Agregar estados "pospuesto/no encontrado".
- Mejorar presupuesto con formato local y total claro.
- Agregar orden por pasillos/tienda.
- Reemplazar escala visual propia por Dynamic Type real + ajustes opcionales.

### Version 2.0: mejoras avanzadas

- Introducir entidad `ShoppingList` y migracion de datos.
- Historial completo de compras.
- iCloud/CloudKit y listas compartidas.
- App Intents, Siri y widgets.
- Recordatorios inteligentes con permisos graduales.
- Motor de sugerencias por frecuencia y contexto.
- Escaneo de codigos de barras.
- Planificacion de recetas/comidas.

## Fixes aplicados en esta pasada - 2026-05-23

### Contraste y claridad visual

- Se creo un set de colores dedicado para `ShoppingMode`: `Color.shoppingModeBackground`, `shoppingModeSurface`, `shoppingModeControlBackground`, `shoppingModeText` y `shoppingModeSecondaryText` en `CasiListo/Theme/Theme.swift`.
- `ShoppingModeView` ahora usa un fondo oscuro estable para garantizar contraste, sin depender del modo claro/oscuro del sistema.
- `ShoppingModeHeaderView`, `ShoppingModeActiveView` y `StoreSelectorView` dejaron de usar texto blanco sobre superficies claras en el flujo de compra.
- Los contadores de categoria en `CategorySectionView` ahora usan texto negro sobre amarillo para mejorar contraste.
- El CTA "Comenzar Compra" en `StoreSelectorView` usa texto negro sobre amarillo.

### Usabilidad y uso con una mano

- `ShoppingModeItemRow` ahora permite tocar casi toda la fila para marcar/desmarcar el producto, no solo el circulo de checkbox.
- La fila de modo compra ahora tiene altura minima mas generosa y mejor feedback visual sobre superficie oscura.
- Los botones pequenos de edicion, resumen, notas de voz y barra inferior fueron elevados a un target minimo de 44 pt mediante `Theme.minimumTouchTarget`.
- `NoResultsView` ahora ofrece un CTA para anadir el producto buscado cuando no hay resultados.

### Accesibilidad

- `ShoppingModeItemRow` ahora anuncia label, valor "Comprado/Pendiente" y accion accesible de marcar/desmarcar.
- `StoreFilterBar` ahora anuncia estado seleccionado/no seleccionado y aplica trait `.isSelected`.
- `CategorySectionView` ahora anuncia categoria, conteo y estado expandida/colapsada.
- Los botones principales de entrada rapida y reproduccion de notas de voz tienen areas tactiles mas confortables.
- `CompletionCelebrationView` respeta parcialmente Reduce Motion al desactivar el confeti animado cuando `accessibilityReduceMotion` esta activo.

### Privacidad y permisos

- Se agregaron descripciones de privacidad al Info.plist generado desde `CasiListo.xcodeproj/project.pbxproj`:
  - `NSMicrophoneUsageDescription`
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`

### Concurrencia y ciclo de vida

- `ShoppingModeViewModel.checkAutoAdvance()` reemplazo `DispatchQueue.main.asyncAfter` por `Task { @MainActor in ... }` con `Task.sleep`.
- `CompletionCelebrationView.triggerTripleHaptic()` reemplazo callbacks con `DispatchQueue` por `Task.sleep` en MainActor.
- `AddEditVoiceNoteSection` invalida el timer y detiene la grabacion al desaparecer la vista para evitar timers vivos o grabacion colgante.

## Fuentes usadas

- Codigo fuente local de `CasiListo`.
- Skills locales: `swiftui-ui-patterns`, `swiftui-liquid-glass`, `swiftui-expert-skill`, `swiftui-performance-audit`, `swift-concurrency-expert`.
- Apple Human Interface Guidelines - Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple Human Interface Guidelines - Buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- Apple SwiftUI `GlassEffectContainer`: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- Apple SwiftUI updates: https://developer.apple.com/documentation/updates/swiftui

## Validacion ejecutada

- `xcodebuild -list -project CasiListo.xcodeproj`: correcto; esquema disponible `CasiListo`.
- `xcodebuild build -project CasiListo.xcodeproj -scheme CasiListo -destination 'platform=iOS Simulator,name=iPhone 17'`: correcto, `BUILD SUCCEEDED` tras los fixes.
- `xcodebuild test -project CasiListo.xcodeproj -scheme CasiListo -destination 'platform=iOS Simulator,name=iPhone 17'`: en la auditoria inicial la build avanzo y compilo targets, pero la ejecucion de pruebas quedo bloqueada en el entorno local repitiendo `DebuggerLLDB.DebuggerVersionStore.StoreError` / `no debugger version`; se interrumpio para no dejar el proceso vivo.
- `xcodebuild test -project CasiListo.xcodeproj -scheme CasiListo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CasiListoTests`: en esta pasada tambien compilo, pero fallo al lanzar la app en el simulador con `NSMachErrorDomain Code=-308` / `(ipc/mig) server died`; se interrumpio. No hay evidencia de fallo de compilacion, pero la ejecucion de tests sigue bloqueada por el entorno de simulador.
