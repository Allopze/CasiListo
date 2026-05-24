# Auditoria UI/UX, producto y SwiftUI - CasiListo

Fecha: 2026-05-24  
Scope revisado: vistas SwiftUI, modelos SwiftData, view models, servicios de ciclo de lista, accesibilidad, modo compra, historial, componentes y tema visual.  
Validacion tecnica: `xcodebuild -scheme CasiListo -project CasiListo.xcodeproj -destination 'generic/platform=iOS Simulator' build` finalizo con `BUILD SUCCEEDED`. Tambien intente `test` en `iPhone 17 Pro, iOS 26.5`; compilo los targets, pero la ejecucion quedo sin progreso y fue interrumpida para no dejar `xcodebuild` vivo.

Nota sobre Context7: el usuario pidio usar Context7, pero no hay herramienta Context7 disponible en esta sesion; `tool_search` no encontro ninguna capability relacionada. La auditoria se basa en el codigo local y en las guias SwiftUI/Swift concurrency indicadas por las skills cargadas.

## Resumen ejecutivo

CasiListo ya tiene una base de producto fuerte para una app de lista de compra: SwiftData, lista activa e historial, entrada rapida, busqueda, categorias, supermercado, modo compra, notas de voz, geofencing, resumen de gasto y uso moderno de `@Observable`, `@Bindable`, `sheet(item:)` y wrappers Liquid Glass.

El mayor riesgo no es tecnico de compilacion, sino de experiencia: la app contiene muchas capacidades, pero varias quedan ocultas o se sienten poco cerradas en el flujo principal. Crear/anadir/marcar funciona, pero completar una compra, organizar productos, manejar pendientes/no encontrados y consultar historial tienen fricciones o inconsistencias de modelo visual.

Los problemas mas importantes son: el primer inicio siembra una lista enorme de productos pendientes, el modo compra no termina correctamente cuando quedan productos pospuestos/no encontrados, algunas acciones clave estan escondidas en menus/context menus, hay riesgo de overflow por doble escalado de texto, y la arquitectura recalcula filtros/agrupaciones en render con fan-out amplio de `@Observable`.

## Problemas criticos

### 1. El primer inicio crea cientos de productos pendientes. NOTA: ESTO ES DECISION DE PRODUCTO

- Descripcion: `ContentView.task` inserta productos por defecto cuando no hay items o no existe `hasSeededDefaultProducts` (`CasiListo/Views/ContentView.swift:123-138`). `SuggestedProducts.seedDefaultItems` crea `ShoppingItem` reales en la lista activa (`CasiListo/Models/SuggestedProducts.swift:154+`).
- Impacto en el usuario: una app de lista deberia partir desde una intencion del usuario. En cambio, el primer uso parece una compra gigante ya cargada. Esto dificulta entender que esta pendiente, que es sugerencia y que pertenece a la compra actual.
- Pantallas o archivos relacionados: `ContentView.swift:123-138`, `SuggestedProducts.swift`, `ShoppingListView.swift:52-69`.
- Severidad: alta.
- Recomendacion concreta: separar catalogo de sugerencias de items activos. Mantener `ProductCatalogItem` para frecuentes y ofrecer onboarding con tres opciones: "Empezar vacio", "Usar plantilla", "Anadir frecuentes". No insertar sugerencias como pendientes salvo confirmacion explicita.

### 2. Completar compra no cubre estados reales de supermercado

- Descripcion: `ShoppingModeViewModel.checkCompletion()` solo completa cuando `pendingCount == 0` (`CasiListo/ViewModels/ShoppingModeViewModel.swift:110-117`). Pero la app permite `skipped` y `unavailable` (`ShoppingModeViewModel.swift:99-108`), y esos estados no cuentan como comprados. Una compra con productos no encontrados puede quedar en un estado raro: sin categorias pendientes visibles, pero sin celebracion/finalizacion clara.
- Impacto en el usuario: si el usuario marca "No encontrado" o "Pospuesto", la compra puede no sentirse terminada aunque ya no haya nada accionable en pantalla.
- Pantallas o archivos relacionados: `ShoppingModeActiveView.swift:26-37`, `ShoppingModeViewModel.swift:18-38`, `ShoppingModeViewModel.swift:110-117`.
- Severidad: alta.
- Recomendacion concreta: distinguir `isActionableCompleted` de `isPurchasedCompleted`. Finalizar la sesion cuando no queden items accionables, mostrando resumen: comprados, pospuestos, no encontrados y pendientes restantes.

```swift
private var actionableCount: Int {
    items.filter { $0.status == .pending }.count
}

private func checkCompletion() {
    if actionableCount == 0 && totalCount > 0 {
        isCompleted = true
    }
}
```

### 3. Organizar productos existe, pero esta oculto y puede fallar mentalmente por categoria

- Descripcion: `CategorySectionView` implementa `.onMove` (`CasiListo/Views/CategorySectionView.swift:101-103`) y `ContentView` tiene una opcion "Ordenar productos" dentro del menu (`CasiListo/Views/ContentView.swift:198-207`). No hay affordance visible en la lista hasta entrar al menu, ni pista de que el reordenamiento ocurre solo dentro de la categoria.
- Impacto en el usuario: la expectativa moderna es arrastrar o ver handles claros. Hoy "organizar productos" parece una accion escondida y no comunica alcance.
- Pantallas o archivos relacionados: `ContentView.swift:198-207`, `CategorySectionView.swift:37-103`, `ShoppingListViewModel.swift:244-251`.
- Severidad: media-alta.
- Recomendacion concreta: convertir el modo ordenar en estado visual explicito: boton "Listo", handles visibles, texto de cabecera "Ordenando en esta categoria" y bloquear/explicar movimiento entre categorias. Para mover entre categorias, usar editar producto o drag/drop avanzado.

### 4. Fila de producto sobrecargada y con riesgo de truncamiento

- Descripcion: `ItemRowView` pone nombre, tienda, cantidad, precio y estado en un unico `HStack` (`CasiListo/Views/ItemRowView.swift:108-158`). Con Dynamic Type alto, productos largos, tienda, cantidad y precio compiten en la misma linea.
- Impacto en el usuario: en listas reales, los nombres y cantidades son el dato principal. Si los chips desplazan el nombre, la lista pierde escaneabilidad.
- Pantallas o archivos relacionados: `ItemRowView.swift:108-158`, `ShoppingHistoryDetailView.swift:166-214`.
- Severidad: media-alta.
- Recomendacion concreta: usar layout de dos niveles. Primera linea: checkbox + nombre + edit/menu. Segunda linea: chips envueltos o `ViewThatFits` con tienda/cantidad/precio. En historial, permitir `lineLimit(2)` para nombres.

### 5. Acciones importantes estan repartidas entre toolbar, menu, swipe y context menu

- Descripcion: editar/eliminar/marcar aparecen en boton lapiz, swipe actions y context menu (`ItemRowView.swift:55-94`, `CategorySectionView.swift:64-95`). Archivar, historial, ajustes, mostrar comprados y ordenar estan dentro de `Menu` (`ContentView.swift:198-243`).
- Impacto en el usuario: para acciones frecuentes durante compra, depender de menu/context menu aumenta friccion y reduce descubribilidad.
- Pantallas o archivos relacionados: `ContentView.swift:198-243`, `ItemRowView.swift:55-94`, `CategorySectionView.swift:64-95`.
- Severidad: media.
- Recomendacion concreta: jerarquizar acciones. Primera capa: anadir, comprar, buscar, marcar. Segunda capa: editar/eliminar por swipe. Tercera capa: ajustes/historial. Poner "Archivar comprados" como CTA visible cuando `purchasedCount > 0`, no solo en menu.

### 6. Doble sistema de escalado puede romper accesibilidad visual

- Descripcion: el proyecto usa `@ScaledMetric` y ademas multiplica por `accessibilityTextSizeScale` desde `@AppStorage` en muchas vistas (`ItemRowView.swift:12-26`, `BottomAddBarView.swift:10-22`, `Theme.swift:47-99`). Esto mezcla Dynamic Type del sistema con un slider propio.
- Impacto en el usuario: en tamanos de accesibilidad altos, frames, padding y fuentes pueden crecer dos veces, provocar overflow y reducir informacion visible. Ademas el slider propio puede contradecir preferencias del sistema.
- Pantallas o archivos relacionados: `Theme.swift:45-123`, `SettingsSheet.swift`, `ItemRowView.swift:12-26`, `ShoppingModeActiveView.swift:11-20`.
- Severidad: media-alta.
- Recomendacion concreta: usar Dynamic Type nativo como fuente de verdad. Mantener el slider solo como "densidad de interfaz" si aporta, pero no multiplicar todos los valores ya escalados. Para dimensiones tactiles, usar `@ScaledMetric` y `max(44, value)`.

### 7. El cierre de compra no actualiza counters de la lista activa con los items ya movidos

- Descripcion: `archivePurchasedItems` mueve `purchasedItems` al nuevo historial asignando `item.listID = completedList.id`, pero luego llama `updateActiveListCounters(activeList, items: items)` sobre el array recibido (`CasiListo/Services/ShoppingListLifecycleService.swift:50-56`). Como los items ya cambiaron de `listID`, puede funcionar por referencia, pero es fragil y mezcla snapshot de entrada con mutacion.
- Impacto en el usuario: contadores del resumen o historial pueden quedar incoherentes si hay filtros por tienda o si el array no representa todos los items activos.
- Pantallas o archivos relacionados: `ShoppingListLifecycleService.swift:25-58`, `ContentView.swift:101-112`, `ShoppingModeView.swift:52-66`.
- Severidad: media.
- Recomendacion concreta: despues de archivar, recalcular desde un fetch del contexto o pasar explicitamente `remainingActiveItems`. Para store-specific archive, los contadores de pendientes deben ser de la lista activa restante, no del subconjunto de la tienda.

## Mejoras de UI

- Reducir ruido de tarjetas y sombras. La lista usa headers con fondo, sombra y filas con sombra (`CategorySectionView.swift:147-169`). Para uso repetido en supermercado, conviene una jerarquia mas plana: header con color suave, filas con separador o agrupacion nativa, menos elevacion.

- Rehacer la fila principal como componente escaneable:

```swift
HStack(alignment: .top, spacing: 12) {
    checkbox
    VStack(alignment: .leading, spacing: 6) {
        Text(item.name)
            .font(.body)
            .lineLimit(2)
        FlowPills {
            storePill
            quantityPill
            pricePill
            statusPill
        }
        if !item.note.isEmpty { noteText }
    }
    itemMenuButton
}
```

- Cambiar el boton lapiz permanente por `Menu` o swipe si el row queda muy cargado. En lista de compra, la accion mas frecuente es marcar, no editar. El lapiz ocupa espacio y compite con precio/cantidad (`ItemRowView.swift:191-204`).

- Hacer el resumen mas util. `SummaryBarView` deberia mostrar una lectura inmediata: "12 pendientes - $34.500 estimado" y una accion secundaria para comprados. Si el usuario esta comprando, el resumen de gasto no deberia tapar anadir rapido.

- Usar color por estado ademas de texto. `skipped` y `unavailable` existen, pero en lista normal quedan como un chip mas (`ItemRowView.swift:148-157`). Propuesta: agrupar al final o usar icono/estado fijo para que no compitan con cantidad/precio.

- Mejorar el modo compra como superficie especializada. Ya usa `Color.shoppingModeBackground` (`ShoppingModeView.swift:15`), pero los tokens deberian aplicarse en todos los controles. En `ShoppingModeActiveView`, mantener header fijo y row de 64-72 pt con alto contraste.

- Ajustar Liquid Glass. La encapsulacion esta bien (`Theme.swift:137-260`), pero `AdaptiveGlassButtonStyle` fuerza botones circulares de ancho fijo (`Theme.swift:213-216`). En `shoppingModeButton`, el label tiene texto "Comprar" (`ContentView.swift:157-161`) pero el estilo lo comprime a circulo. Usar estilo prominente/capsula para botones con texto.

- Revisar colores de tiendas como unico indicador. `Store` usa verde/azul (`Store.swift:22-23`); agregar icono o texto siempre visible, y no depender solo del color para distinguir supermercados.

## Mejoras de UX

- Flujo recomendado de primer uso: pantalla vacia real, campo "Anadir rapido", chips "Leche", "Pan", "Huevos" desde catalogo, y boton "Usar plantilla". No crear items pendientes automaticamente.

- Entrada rapida: ya parsea "2 leche", "pan x3", "tomates 1 kg" (`ShoppingListViewModel.swift:154-174`, `274-338`). Hacerlo visible con placeholder dinamico y feedback: al escribir "2 leche", mostrar chip "Cantidad: 2".

- Sugerencias mas utiles: hoy `suggestions(for:)` hace contains sobre todos los productos. Ordenar por frecuencia, prefijo y tienda. Un usuario espera que "le" sugiera "Leche" antes que cualquier palabra que contenga "le".

- Modo compra con una mano: `ShoppingModeItemRow` ya hace tappable la zona principal de la fila y mantiene menu separado, lo cual es una buena base. El siguiente salto UX es agregar un boton grande "Finalizar" cuando no queden items accionables o cuando el usuario quiera cerrar con pendientes.

- Navegacion de categorias: ademas de siguiente/anterior, agregar una hoja "Pasillos" con todas las categorias y conteos. Si el usuario cambia de pasillo, no quiere pulsar varias veces.

- Confirmaciones: eliminar un producto por swipe no pide confirmacion ni undo (`CategorySectionView.swift:64-72`). Para lista de compras, mejor undo/snackbar que alert bloqueante.

- Historial: existe y tiene detalle (`ShoppingHistoryView.swift`, `ShoppingHistoryDetailView.swift`), pero esta oculto en el menu. Hacerlo accesible desde una pestaña o desde una tarjeta "Ultima compra" cuando no hay compra activa.

- Cierre de compra: tras archivar, mostrar resumen claro: gasto, comprados, no encontrados, pospuestos, tiempo estimado si se mide. La celebracion deberia ser breve y siempre ofrecer "Volver a lista", "Archivar y limpiar", "Nueva lista".

- Geofencing: no pedir permisos hasta que el usuario active una tienda o recordatorio. La copia en ajustes ya explica valor; falta convertirlo en onboarding progresivo.

## Mejoras de accesibilidad

- VoiceOver: `ItemRowView` esta bastante trabajado (`ItemRowView.swift:42-45`, `95-103`), pero falta accion "Editar" como custom action, ya que el lapiz separado puede ser menos obvio para usuarios de VoiceOver.

```swift
.accessibilityAction(named: "Editar") {
    onEdit()
}
```

- VoiceOver en modo compra: `ShoppingModeItemRow` ya tiene label, value y accion de marcar; faltan acciones custom para "Posponer" y "No encontrado", que hoy viven dentro de un `Menu`. Debe decir "Leche, 2 unidades, pendiente" y ofrecer esas acciones sin obligar a descubrir el menu.

- Dynamic Type: evitar doble escalado. Ejemplo actual: `@ScaledMetric` + `accessibilityTextSizeScale` en `ItemRowView.swift:12-26` y uso de `Theme.bodyFont(scale:)`. Cambiar a fonts semanticas y `@ScaledMetric` solo para tamanos no textuales.

- Touch targets: varios controles usan frames que pueden quedar por debajo o demasiado dependientes del slider. Consolidar helper:

```swift
extension View {
    func minimumHitArea(_ size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }
}
```

- Contraste: `Color.appTextSecondary` claro `#8A8A8A` sobre `#FAF8F5` es aceptable para texto normal, pero chips pequenos y texto secundario multiplicado por opacidad pueden quedar bajos. Evitar opacidades adicionales sobre textos pequenos.

- Reduce Motion: `CompletionCelebrationView` ya declara `@Environment(\.accessibilityReduceMotion)` segun busqueda, revisar que todas las animaciones de confetti y waveform se apaguen de verdad. `VoiceNotePlayerButton` anima barras (`VoiceNotePlayerButton.swift`) y deberia respetar `accessibilityReduceMotion`.

- No depender solo de color: filtros de tienda y estados deben tener `accessibilityValue("Seleccionado")` y rasgo `.isSelected`. `StoreFilterBar` parece hacerlo segun busqueda, mantener ese patron en `StoreSelectorView` y `CategoryPickerView`.

- Textos localizados y acentos: hay strings sin acento en historial ("guardara", "aqui"; `ShoppingHistoryView.swift:15`). Pulir copy mejora VoiceOver y percepcion de calidad.

## Observaciones tecnicas

- Build: el proyecto compila correctamente con Swift 6, iOS simulator 26.5 y `default-isolation=MainActor`.

- Concurrencia: los view models principales estan `@MainActor` (`ShoppingListViewModel.swift:27-29`, `ShoppingModeViewModel.swift:6-8`). Bien para UI/SwiftData. `ShoppingModeViewModel` guarda `autoAdvanceTask` con `@ObservationIgnored` (`ShoppingModeViewModel.swift:15`), correcto para no invalidar UI. Falta cancelar al salir del modo compra: `stopSession()` existe (`ShoppingModeViewModel.swift:79-82`) pero no se ve llamado desde `ShoppingModeView`.

- Performance: `ShoppingListView.body` deriva `groups` y `summary` desde arrays cada render (`ShoppingListView.swift:20-25`). `ShoppingModeViewModel.categories`, `activeItems`, `purchasedCount`, `pendingCount` filtran repetidamente (`ShoppingModeViewModel.swift:18-52`). Para cientos de items va bien; para listas compartidas/historial grande conviene un `ShoppingListSnapshot`.

- Fan-out de observacion: `ShoppingListView` recibe todo el `ShoppingListViewModel` como `@Bindable` (`ShoppingListView.swift:9`) aunque muchos subcomponentes solo necesitan uno o dos bindings/acciones. Pasar valores derivados reduce invalidaciones.

- Persistencia: `togglePurchased` y `markItem` en lista normal mutan estado pero no llaman `context.safeSave()` (`ShoppingListViewModel.swift:179-186`). SwiftData puede guardar por ciclo, pero para acciones criticas conviene persistencia explicita o centralizada, sobre todo si se archiva luego.

- Precio: `Double` y `NumberFormatter` creado por llamada (`ShoppingItem.swift`) funciona, pero dinero deberia ser `Decimal` o entero de centavos. Ademas crear formatter repetidamente en filas/historial puede costar. Usar `FormatStyle.Currency` o formatter estatico.

- `ShoppingListLifecycleService.archivePurchasedItems` mezcla archivo, counters y mutacion de items en un metodo estatico `@MainActor` (`ShoppingListLifecycleService.swift:25-58`). Conviene extraer un resultado:

```swift
struct ArchiveResult {
    let completedList: ShoppingList
    let archivedCount: Int
    let remainingActiveCount: Int
}
```

- Sheets: bien el uso de `sheet(item:)` en `ContentView.swift:95`. `AddEditItemSheet` recibe el `viewModel` completo (`AddEditItemSheet.swift:21-24`); mejor pasar solo `selectedStore`, `quickAddDraft` y `nextSortOrder` como dependencias o servicio.

- Liquid Glass: wrappers tienen disponibilidad correcta (`Theme.swift:145-181`, `198-205`). Como el deployment target usado por build es iOS 26.5, los fallbacks no se ejercitan. Si el producto apunta a iOS 17/18, bajar target y compilar esa ruta.

- Permisos sensibles: las descripciones de ubicacion y microfono si estan declaradas en build settings generados (`CasiListo.xcodeproj/project.pbxproj:403-405`, `439-441`). Punto positivo: no hay un bloqueo obvio de App Store por strings de privacidad basicos.

- Tests: intente la suite con un simulador concreto (`iPhone 17 Pro, iOS 26.5`), pero la ejecucion quedo colgada despues de compilar y la interrumpi. Faltan pruebas de parseo de entrada rapida, filtros, archivo de comprados, estados pospuesto/no encontrado, historial y modo compra.

## Lista priorizada de acciones

### 1. Cambios rapidos de alto impacto

1. Desactivar seeding automatico de productos pendientes para usuarios nuevos; dejar catalogo como sugerencias.
2. Corregir cierre de modo compra cuando no queden items accionables, no solo cuando todo este comprado.
3. Agregar acciones VoiceOver directas para "Posponer" y "No encontrado" en `ShoppingModeItemRow`.
4. Cambiar `shoppingModeButton` a capsula/prominente para que el texto "Comprar" no quede comprimido por estilo circular.
5. Agregar CTA visible "Archivar comprados" cuando haya comprados, con undo.
6. Evitar doble escalado en las filas mas usadas: `ItemRowView`, `BottomAddBarView`, `ShoppingModeActiveView`.
7. Llamar `stopSession()` al salir de `ShoppingModeView`.
8. Pulir copy y acentos de historial/empty states.

### 2. Mejoras importantes de mediano esfuerzo

1. Redisenar fila de producto con layout de dos niveles y chips que no compitan con el nombre.
2. Crear un snapshot derivado para grupos, resumen y totales.
3. Hacer modo ordenar explicito con handles, estado visible y alcance por categoria.
4. Redisenar cierre de compra con resumen y opciones: archivar, mantener pendientes, nueva lista.
5. Ordenar sugerencias por frecuencia/prefijo y guardar historial de uso.
6. Mejorar historial con acceso mas visible y filtros por fecha/tienda.
7. Agregar tests de unidad para parseo, archivo e historial; UI tests para crear, marcar y finalizar.

### 3. Mejoras avanzadas o de mayor alcance

1. Listas compartidas con iCloud/CloudKit.
2. Motor de pasillos/secciones configurable por supermercado.
3. Presupuesto estimado persistente con comparacion real vs estimado.
4. Widgets y App Intents para ver/anadir productos rapido.
5. Escaneo de codigos de barra.
6. Recetas/planificacion de comidas conectadas con lista.

## Nuevas funcionalidades recomendadas

### Categorias automaticas mejoradas

- Que problema resuelve: reduce pasos al anadir productos.
- Como funcionaria: al escribir, la app sugiere categoria y permite corregir; aprende de correcciones.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

### Reordenar por secciones del supermercado

- Que problema resuelve: evita caminar de mas y hace el modo compra mas natural.
- Como funcionaria: cada tienda tiene orden de pasillos; los productos se agrupan segun ese orden.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

### Historial de productos frecuentes

- Que problema resuelve: anadir rapido productos recurrentes sin llenar la lista activa.
- Como funcionaria: chips por frecuencia y busqueda priorizada por uso reciente.
- Dificultad estimada: baja-media.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

### Sugerencias inteligentes

- Que problema resuelve: ayuda a no olvidar productos.
- Como funcionaria: "Sueles comprar cafe cada 2 semanas" o "compraste pasta, quizas salsa".
- Dificultad estimada: media.
- Valor para el usuario: medio-alto.
- Prioridad recomendada: P1.

### Listas compartidas

- Que problema resuelve: compras familiares o de pareja.
- Como funcionaria: compartir lista por iCloud, cambios en tiempo real, autor de cambios opcional.
- Dificultad estimada: alta.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### Cantidades y unidades estructuradas

- Que problema resuelve: evita texto libre ambiguo.
- Como funcionaria: parser conserva texto rapido, pero almacena `amount`, `unit` y `displayQuantity`.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### Presupuesto estimado

- Que problema resuelve: control de gasto antes y durante compra.
- Como funcionaria: suma precios estimados, permite editar precio por item, compara con total final.
- Dificultad estimada: media.
- Valor para el usuario: medio-alto.
- Prioridad recomendada: P1.

### Escaneo de codigos de barras

- Que problema resuelve: anadir productos exactos rapidamente.
- Como funcionaria: camara escanea barcode y busca en catalogo local/remoto; si no existe, crea item.
- Dificultad estimada: alta.
- Valor para el usuario: medio.
- Prioridad recomendada: P2.

### Recetas o planificacion de comidas

- Que problema resuelve: transforma comidas planeadas en lista.
- Como funcionaria: el usuario elige receta, la app anade ingredientes faltantes.
- Dificultad estimada: alta.
- Valor para el usuario: medio.
- Prioridad recomendada: P2.

### Sincronizacion con iCloud

- Que problema resuelve: continuidad entre dispositivos y base para compartir.
- Como funcionaria: SwiftData + CloudKit, resolucion simple de conflictos por item.
- Dificultad estimada: alta.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### Widgets

- Que problema resuelve: ver pendientes sin abrir app.
- Como funcionaria: widget con proximos productos y contador; deep link a modo compra.
- Dificultad estimada: media.
- Valor para el usuario: medio.
- Prioridad recomendada: P2.

### Atajos de Siri / App Intents

- Que problema resuelve: anadir productos sin tocar pantalla.
- Como funcionaria: "Anade leche a CasiListo"; intent crea item en lista activa.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P1.

### Notificaciones y recordatorios

- Que problema resuelve: recordar compras segun lugar o hora.
- Como funcionaria: recordatorio al pasar cerca de supermercado o a cierta hora.
- Dificultad estimada: media.
- Valor para el usuario: medio.
- Prioridad recomendada: P2.

### Modo comprando optimizado para una mano

- Que problema resuelve: reduce errores mientras el usuario camina o sostiene carro/bolsas.
- Como funcionaria: filas grandes, controles inferiores, saltar pasillo, finalizar rapido, undo.
- Dificultad estimada: media.
- Valor para el usuario: alto.
- Prioridad recomendada: P0.

## Roadmap sugerido

### Version 1.1: mejoras rapidas

- Quitar seeding automatico de pendientes y mover sugerencias a catalogo/frecuentes.
- Arreglar finalizacion de modo compra con `skipped`/`unavailable`.
- Completar accesibilidad del modo compra con acciones directas para estados alternativos.
- Mejorar contraste, copy y touch targets.
- Agregar undo para eliminar/archivar.
- Llamar `stopSession()` al salir del modo compra.

### Version 1.2: funcionalidades utiles de producto

- Entrada rapida con feedback visible de cantidad/unidad/categoria.
- Historial mas visible con resumen de ultima compra.
- Modo ordenar explicito.
- Sugerencias ordenadas por frecuencia y prefijo.
- Resumen de compra al finalizar con comprados, pospuestos, no encontrados y gasto.
- Tests de flujos principales.

### Version 2.0: mejoras avanzadas

- iCloud sync y listas compartidas.
- Secciones configurables por supermercado.
- App Intents/Siri y widget.
- Presupuesto estimado vs real.
- Escaneo de codigos de barra.
- Recetas/planificacion de comidas.
