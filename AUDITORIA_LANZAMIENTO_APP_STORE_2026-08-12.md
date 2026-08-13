# Auditoría integral de CasiListo para lanzamiento en Apple App Store

> Fecha de auditoría: 12 de agosto de 2026
> Repositorio auditado: `/Users/allopze/dev/CasiListo`
> Versión declarada: 1.0 (build 1)
> Plataforma declarada: iOS 17.0 o posterior, iPhone y iPad
> Estado de lanzamiento: **ROJO — no enviar a App Store todavía**

---

## 1. Alcance, método y límites de evidencia

Esta es una auditoría de preparación para App Store del código actualmente presente en el repositorio. Se revisaron arquitectura SwiftUI/SwiftData, permisos, datos, WidgetKit, geofencing, notas de voz, OCR de boletas, accesibilidad, pruebas, configuración de targets y requisitos de App Review.

Se aplicaron criterios de revisión de App Store, SwiftData, WidgetKit, MapKit/Core Location, AVFoundation, SwiftUI, navegación y accesibilidad iOS. Para las exigencias vigentes de distribución se contrastaron las fuentes oficiales de Apple enlazadas al final.

### 1.1 Leyenda de certeza

| Estado | Significado |
|---|---|
| **CONFIRMADO ESTÁTICAMENTE** | El código o configuración demuestra la condición sin necesidad de ejecutar la app. |
| **PROBABLE — requiere runtime** | La implementación permite el fallo; debe reproducirse con una prueba en dispositivo o Simulator antes de declarar el comportamiento observado. |
| **NO VERIFICADO EN RUNTIME** | No es posible afirmar que funcione o falle porque este entorno no dispone de Xcode, `xcodebuild` ni `simctl`. |
| **NO ES UN HALLAZGO** | Se revisó y no hay evidencia suficiente de un problema actual. |

### 1.2 Limitación crítica del entorno de auditoría

Los comandos de compilación y Simulator no pueden ejecutarse en este equipo:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode,
but active developer directory '/Library/Developer/CommandLineTools'

xcrun: error: unable to find utility "simctl", not a developer tool or in PATH
```

Por ello se marca explícitamente como **NO VERIFICADO EN RUNTIME** lo siguiente:

- Compilación actual del target de app, widget, unit tests y UI tests.
- Pruebas XCTest y captura de fallos de UI test.
- Permisos de cámara, fotos, micrófono, notificaciones y ubicación.
- Ejecución de OCR Vision en imágenes reales.
- Background geofencing, notificaciones locales y reinstalación.
- Tap del widget, deep links, refresco de timeline y modos tintados.
- Accesibilidad real: VoiceOver, Voice Control, Dynamic Type, contraste, Reduce Motion e iPad.
- Archive, validación de firma, Privacy Report y subida a App Store Connect.

Existe una nota histórica de una compilación anterior exitosa, pero no sustituye la verificación del árbol de trabajo, toolchain y binario actuales; además esa misma nota registra pruebas obsoletas de Shopping Mode. Esta auditoría no atribuye ese resultado histórico al estado presente.

### 1.3 Reglas de severidad

| Severidad | Criterio aplicado |
|---|---|
| **Crítica** | Pérdida masiva de datos, vulnerabilidad explotable, crash recurrente o incumplimiento inequívoco que detiene envío. |
| **Alta** | Rechazo probable, funcionalidad visible rota, privacidad/permisos incorrectos, o pérdida de datos en una condición razonable. |
| **Media** | Funcionalidad incompleta o inconsistente, degradación de UX/accesibilidad, integridad parcial o deuda que debe resolverse antes de escalar. |
| **Baja** | Pulido, resiliencia o casos de borde que no bloquean una beta controlada. |

---

## 2. Inventario técnico y configuración

### 2.1 Targets y configuración de entrega

| Elemento | Evidencia | Estado |
|---|---|---|
| App principal | `com.allopze.CasiListo` | Configurado |
| Widget | `com.allopze.CasiListo.widget` | Configurado |
| Deployment target | iOS 17.0 | Configurado |
| Familias | `TARGETED_DEVICE_FAMILY = "1,2"` | iPhone e iPad declarados |
| Marketing / build | `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` | Configurado |
| Modelo de datos | `ShoppingItem`, `ShoppingList`, `ProductCatalogItem`, `Category` en `ModelContainer` | Configurado |
| App Group | `group.com.allopze.CasiListo` en app y widget | Configurado y coincidente |
| Dependencias externas | README declara frameworks Apple; búsqueda estática no encontró SDK/red de terceros | Probablemente nativo; archive pendiente |
| App icon | Asset con variante universal, oscura y tintada | Presente; revisión visual pendiente |
| Privacy Manifest | No se encontró `PrivacyInfo.xcprivacy` | **Bloqueador** |
| URL scheme | No se encontró `CFBundleURLTypes` | **Bloqueador para widget** |
| Política de privacidad in-app | No se encontró URL, texto ni pantalla | **Bloqueador** |
| `UIBackgroundModes` | No está declarado | Revisar al validar geofencing; no se concluye por sí solo que falle |

### 2.2 Permisos declarados

El proyecto declara mensajes de propósito específicos para cámara, fotos, micrófono, ubicación cuando se usa y ubicación siempre. Están presentes tanto en Debug como Release de la app principal:

| Permiso | Texto declarado | Evaluación estática |
|---|---|---|
| Cámara | Fotografiar boletas y registrar productos/precios | Específico y congruente con OCR |
| Fotos | Elegir una boleta | Específico y congruente |
| Micrófono | Guardar notas de voz | Específico y congruente |
| Ubicación cuando se usa | Recordar compras pendientes cerca del supermercado | Congruente con geofencing |
| Ubicación siempre | Avisar al pasar cerca de supermercado | Requiere flujo de autorización correcto |

La presencia de textos de propósito no valida el comportamiento de autorización, la justificación final, ni la información declarada en App Store Connect.

### 2.3 Persistencia y datos locales

| Dato / recurso | Mecanismo observado | Riesgo de privacidad / integridad |
|---|---|---|
| Ítems, listas, categorías y catálogo | SwiftData | Requiere migración y manejo de error de guardado |
| Estadísticas | `UserDefaults.standard` | Requiere Privacy Manifest por Required Reason API |
| Preferencia de tamaño de texto y geofencing | `UserDefaults.standard` | Requiere Privacy Manifest |
| Snapshot del widget | `UserDefaults(suiteName:)` en App Group | Requiere Privacy Manifest de targets pertinentes |
| Foto de boleta | `Application Support/Receipts` | Debe limpiarse ante fallo de persistencia |
| Nota de voz | `Documents/VoiceNotes` | Debe borrarse sólo tras commit y manejar errores |
| Red / analítica | No se encontró `URLSession`, WebSocket, URL HTTP/S ni SDK externo en fuentes Swift | No equivale a auditoría de tráfico del binario |

---

## 3. Inventario funcional y resultado por flujo

| Función | Implementación observada | Casos borde revisados | Estado para producción |
|---|---|---|---|
| Lista activa única | `ShoppingListLifecycleService.bootstrap` selecciona/crea lista activa | Múltiples listas activas, error de fetch, ítems huérfanos | Condicional |
| Cierre de compra por supermercado | Agrupa productos comprados con `Dictionary(grouping:)` y crea historial por tienda | Sin precios, mezcla Jumbo/Líder, fallo de save | Lógica base correcta; persistencia bloquea confianza |
| Historial y CSV | Historial por `listID`, ShareLink CSV | Comillas, saltos de línea, fórmulas y escala | Requiere corrección de exportación |
| Añadir/editar ítem | Hoja con categoría, tienda, cantidad, precio y audio | Duplicados, cambio de categoría, error de guardado | Condicional |
| Búsqueda y filtros | Filtra nombre, nota y categoría | Tildes, espacios, volúmenes grandes | Inconsistente |
| Importar texto y plantillas | Inserción masiva con categorías sugeridas | Duplicados y orden repetido | Inconsistente |
| Categorías | CRUD y fallback a Varios | Eliminación con productos asociados | Requiere confirmación |
| OCR de boletas | Vision local, edición de líneas, selección manual de tienda | Imagen inválida, OCR impreciso, error de save | Buen flujo; transacción pendiente |
| Comparación de precios | Filtra por nombre normalizado, tienda e historial | Volumen de datos y precios faltantes | Requiere prueba de escala |
| Notas de voz | AVAudioRecorder/AVAudioPlayer local | Denegación, interrupción, fallo de archivos, doble borrado | Condicional |
| Geofencing | Dos regiones predefinidas con notificación local | Denegación, autorización parcial, cambio global, background | Requiere corrección y validación real |
| Widget | Snapshot App Group, familias small/medium | URL, refresco, nombres repetidos, tintado | No listo |
| Modo Compra | No existe flujo/vista activo | UI test intenta abrirlo | No implementado |
| Accesibilidad | Labels y acciones personalizadas en filas | VoiceOver, Voice Control, Dynamic Type e iPad | No verificado |

---

## 4. Hallazgos detallados

Cada encabezado comienza con una casilla de seguimiento. Cambiar `[ ]` por `[x]` sólo después de aplicar la corrección y completar la validación de cierre indicada en el hallazgo.

### [ ] F-01 — Alta — Privacidad — Falta Privacy Manifest en app y widget

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** no existe `PrivacyInfo.xcprivacy` en el repositorio. Uso de `UserDefaults` en `CasiListo/Services/AppSettings.swift:7-15`, `CasiListo/Models/UserStats.swift:11-24`, `CasiListo/Services/WidgetDataBridge.swift:19-34` y `CasiListoWidget/WidgetDataModel.swift:15-23`.
- **Componente:** app principal y extensión WidgetKit.
- **Evidencia:** la búsqueda de archivos sólo devuelve los entitlements; no devuelve manifiestos de privacidad. Los cuatro componentes citados leen o escriben UserDefaults, incluida la suite del App Group.
- **Escenario de fallo:** se archiva o envía un binario que usa APIs con razón requerida sin que la declaración de privacidad represente el uso real.
- **Impacto para la persona usuaria:** no tiene transparencia revisable sobre persistencia de preferencias, estadísticas y snapshot de lista.
- **Impacto App Store:** alto riesgo de incumplimiento de los requisitos de Privacy Manifest y Required Reason APIs; no debe avanzar a envío sin corregirlo.
- **Causa raíz:** no se creó, añadió al target ni validó el archivo `PrivacyInfo.xcprivacy`.
- **Corrección propuesta:** crear manifiesto para la app y revisar si el widget necesita uno propio según sus APIs; declarar sólo datos, APIs y razones de uso reales. Confirmar los códigos de razón vigentes directamente contra la documentación de Apple antes del archive.
- **Validación de cierre:** archive Release en Xcode; inspeccionar Privacy Report; comparar cada entrada con el código y dependencias efectivas; revisar que ambos targets incluyan su manifiesto cuando corresponda.

### [ ] F-02 — Alta — Privacidad / App Review — No hay política de privacidad accesible dentro de la app

- **Estado:** CONFIRMADO ESTÁTICAMENTE para la ausencia en código; App Store Connect es NO VERIFICADO.
- **Archivos / líneas:** búsqueda de `privacy policy`, `política de privacidad`, `support` y `soporte` sin resultado funcional en fuentes Swift o README.
- **Componente:** Ajustes, metadata App Store y soporte.
- **Evidencia:** no existe URL externa registrada, `Link`, pantalla de política ni ruta de soporte.
- **Escenario de fallo:** una persona acepta cámara, fotos, micrófono o ubicación sin encontrar desde la app información sobre qué se guarda localmente, por cuánto tiempo y cómo eliminarlo.
- **Impacto para la persona usuaria:** baja confianza y ausencia de una vía clara para consultar o ejercer control sobre sus datos locales.
- **Impacto App Store:** probable rechazo si tampoco está configurada en App Store Connect; las App Review Guidelines exigen URL de política en metadata y acceso desde la app.
- **Causa raíz:** falta una política publicada y su integración en Ajustes.
- **Corrección propuesta:** publicar una política real, concisa y coherente con el binario. Debe cubrir almacenamiento local de listas, fotos, audio, App Group, permisos, retención, borrado y un contacto de soporte. Incluir `Link` accesible desde Ajustes y cargar la misma URL en App Store Connect.
- **Validación de cierre:** abrir la URL desde una instalación limpia, comprobar que es pública y estable, verificar lectura con Dynamic Type/VoiceOver y contrastar texto con Privacy Nutrition Labels finales.

### [ ] F-03 — Alta — WidgetKit / Navegación — El widget publica un deep link que la app no registra ni maneja

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListoWidget/CasiListoWidget.swift:192` define `.widgetURL(URL(string: "casilisto://open"))`; `CasiListo/CasiListoApp.swift:11-22` no contiene `.onOpenURL`; `project.pbxproj` no declara `CFBundleURLTypes`.
- **Componente:** widget small/medium y punto de entrada de la app.
- **Evidencia:** la búsqueda de `onOpenURL`, `CFBundleURLTypes` y `URLTypes` sólo encuentra la URL del widget.
- **Escenario de fallo:** la persona toca el widget esperando abrir CasiListo y el sistema no puede resolver la URL personalizada o la app no procesa la ruta.
- **Impacto para la persona usuaria:** interacción principal del widget rota; parece una app incompleta.
- **Impacto App Store:** riesgo alto respecto de funciones visibles que no funcionan y revisión de completitud.
- **Causa raíz:** se implementó la URL de salida sin registrar esquema ni implementar recepción.
- **Corrección propuesta:** registrar `casilisto` en `CFBundleURLTypes`; incorporar en el `WindowGroup` un `.onOpenURL` que valide host/path y navegue a una ruta segura. Alternativamente, eliminar `.widgetURL` hasta contar con una ruta funcional.
- **Validación de cierre:** instalar en dispositivo, añadir ambos tamaños de widget, tocar su superficie, probar app cerrada/en primer plano y validar URL desconocida o malformada sin crash.

### [ ] F-04 — Alta — Permisos / Core Location — El onboarding solicita autorizaciones sin esperar ni reflejar el resultado

- **Estado:** CONFIRMADO ESTÁTICAMENTE; resultado del sistema NO VERIFICADO EN RUNTIME.
- **Archivos / líneas:** `CasiListo/Views/LocationPermissionOnboardingView.swift:59-63`; `CasiListo/Views/SettingsSheet.swift:82-90`; `CasiListo/Services/GeofenceService.swift:46-52, 61-77, 159-170`.
- **Componente:** Ajustes, onboarding de recordatorios y `CLLocationManager`.
- **Evidencia:** el botón llama seguidamente `requestWhenInUsePermission()` y `requestAlwaysPermissionForBackgroundReminders()`, después ejecuta `onFinished()` y cierra la hoja. `onFinished()` pone `isGeofencingEnabled = true` e inicia monitoreo antes de conocer la resolución de autorización.
- **Escenario de fallo:** la persona deniega ubicación, entrega sólo permiso al usar, o el sistema aplaza el segundo prompt; la interfaz puede seguir mostrando recordatorios activos.
- **Impacto para la persona usuaria:** recordatorios que no llegan, confusión y repetición de permisos sin explicación.
- **Impacto App Store:** riesgo de revisión por experiencia de permiso poco transparente y potencial solicitud de privilegio más amplio sin estado/beneficio comprobable.
- **Causa raíz:** no existe una máquina de estados que dependa de `CLAuthorizationStatus` y callbacks antes de activar el toggle/monitoreo.
- **Corrección propuesta:** separar solicitud de notificaciones, When In Use y Always; esperar `locationManagerDidChangeAuthorization`; activar monitoreo sólo al alcanzar la autorización necesaria; mostrar estado real, explicación y enlace a Ajustes para denegación/restricción.
- **Validación de cierre:** matriz en dispositivo real: primera instalación, permitir/denegar cada nivel, “Sólo esta vez” si aplica, ubicación global desactivada, cambio desde Ajustes, reinicio de app y entrada a una región.

### [ ] F-05 — Alta — Persistencia / datos locales — `safeSave()` no propaga errores y se borra audio antes de confirmar SwiftData

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Theme/Theme.swift:307-317`; `CasiListo/Views/AddEditItemSheet.swift:101-107, 232-274`; `CasiListo/Services/ReceiptServices.swift:307-322, 363`; `CasiListo/ViewModels/ShoppingListViewModel.swift:251-303`.
- **Componente:** alta/edición de productos, archivado, boletas, undo y archivos de audio.
- **Evidencia:** `safeSave()` captura el error y sólo lo registra. El botón marca éxito, emite haptic y descarta la hoja inmediatamente. Al editar, el archivo de audio antiguo se elimina en líneas 264-267 antes de `modelContext.safeSave()` de la línea 273. La foto de una boleta se graba en disco antes de insertar/guardar su historial.
- **Escenario de fallo:** falta de espacio, incompatibilidad de esquema o error de persistencia. La UI informa éxito; se pierde un audio anterior, se deja una foto huérfana o se descarta una mutación sin aviso.
- **Impacto para la persona usuaria:** pérdida silenciosa de información y una experiencia imposible de corregir sin saber que hubo fallo.
- **Impacto App Store:** riesgo alto de pérdida de contenido generado por la persona y comportamiento incompleto.
- **Causa raíz:** operaciones no transaccionales entre filesystem y SwiftData, y una API de guardado que oculta el resultado a sus llamadores.
- **Corrección propuesta:** reemplazar `safeSave()` por una operación que lance o devuelva `Result`; confirmar el commit antes de eliminar audio anterior; escribir nuevos recursos en staging y eliminarlos si falla la base; mostrar alerta recuperable/reintento cuando corresponda.
- **Validación de cierre:** tests de servicio que inyecten fallo de save y fallo de filesystem; verificar que audio y foto antiguos sobreviven a un fallo, archivos temporales se limpian y la hoja no confirma éxito cuando no hay commit.

### [ ] F-06 — Alta — SwiftData / actualización — No existe un plan verificable de migración 1.0 a 1.1

- **Estado:** CONFIRMADO ESTÁTICAMENTE para la ausencia de migración; impacto real NO VERIFICADO.
- **Archivos / líneas:** `CasiListo/CasiListoApp.swift:18-21` crea un `ModelContainer` directo; búsqueda de `VersionedSchema` y `SchemaMigrationPlan` sin resultados.
- **Componente:** modelo persistente y futuras actualizaciones.
- **Evidencia:** el modelo actual ya conserva compatibilidad mediante `@Attribute(originalName: "isPurchased")` en `CasiListo/Models/ShoppingItem.swift:29`, pero no hay esquemas versionados, plan ni test fixture de una base 1.0.
- **Escenario de fallo:** se cambia una propiedad, relación, tipo o regla de borrado para 1.1 y una instalación con listas, boletas o audios deja de abrir o pierde asociaciones.
- **Impacto para la persona usuaria:** datos de compra e historial inaccesibles después de actualizar.
- **Impacto App Store:** no es rechazo automático, pero sí riesgo de regresión grave de actualización que debe resolverse antes de publicar una nueva versión.
- **Causa raíz:** la evolución del modelo no tiene contrato ni prueba migratoria reproducible.
- **Corrección propuesta:** definir `VersionedSchema` para 1.0 y 1.1, un `SchemaMigrationPlan` explícito si la migración ligera no basta, y fixture de base de datos/archivos reales de la versión anterior.
- **Validación de cierre:** instalar un binario 1.0, crear lista mixta, boleta, precios y nota de voz; actualizar sobre esa instalación a 1.1 y comprobar todos los registros, métricas, widget e historial.

### [ ] F-07 — Alta — Funcionalidad / pruebas — Modo Compra no está implementado aunque una UI test lo exige

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListoUITests/CasiListoUITests.swift:43-54` intenta tocar `"Entrar a Modo Compra"`; búsqueda de `Modo Compra`, `ShoppingMode`, `Entrar a Modo Compra` y `fullScreenCover` sólo encuentra esa prueba y colores en `CasiListo/Theme/Theme.swift:364-377`.
- **Componente:** flujo de compra y suite UI.
- **Evidencia:** no hay botón, vista, ruta ni view model de modo compra en los archivos actuales. La prueba tampoco espera la existencia del botón antes de tocarlo.
- **Escenario de fallo:** la UI test falla; si screenshots, metadata o soporte anuncian Modo Compra, una persona no puede acceder a la función prometida.
- **Impacto para la persona usuaria:** expectativa incumplida en un flujo central de compra.
- **Impacto App Store:** riesgo de 2.1/2.3 si aparece en material promocional o se mantiene como funcionalidad declarada.
- **Causa raíz:** funcionalidad removida o incompleta, con recursos y test obsoletos que quedaron en el proyecto.
- **Corrección propuesta:** elegir explícitamente una de dos rutas: implementar el modo compra completo, accesible y probado; o retirar prueba, colores muertos, documentación, metadata y cualquier referencia comercial.
- **Validación de cierre:** XCTest de flujo completo; creación de ítems, marcar comprado, posponer, no encontrado, volver a lista e historial. Si se retira, búsqueda global sin referencias residuales y actualización de README/App Store Connect.

### [ ] F-08 — Media — Core Location / producto — Las geocercas sólo representan dos sucursales fijas de Los Ángeles

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Models/Store.swift:27-44`; `CasiListo/Services/GeofenceService.swift:61-77`; `CasiListo/Views/Components/SettingsGeofencingSection.swift:54-77`.
- **Componente:** recordatorios cerca de supermercados.
- **Evidencia:** las coordenadas están codificadas para un Jumbo y un Líder de Los Ángeles, Chile; `startMonitoringAll()` recorre exclusivamente `Store.allCases`.
- **Escenario de fallo:** una persona en otra ciudad activa recordatorios creyendo que cubren sus sucursales y nunca recibe la alerta.
- **Impacto para la persona usuaria:** funcionalidad opcional que aparenta ser general pero sólo sirve en dos ubicaciones.
- **Impacto App Store:** no implica rechazo directo, pero es una promesa funcional potencialmente engañosa si se promociona sin esa limitación.
- **Causa raíz:** el modelo `Store` mezcla marca comercial y una sola geografía fija.
- **Corrección propuesta:** permitir configurar sucursal/ubicación propia, suministrar catálogo geográfico mantenible, o restringir claramente la función a esas dos sucursales mientras se desarrolla una solución general.
- **Validación de cierre:** prueba en las coordenadas configuradas y fuera de ellas; cambio de sucursal; límite del sistema de regiones; reinstalación; notificación al entrar en región real.

### [ ] F-09 — Media — UX / lógica — La categoría automática puede reemplazar una elección manual

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Views/AddEditItemSheet.swift:162-177`.
- **Componente:** formulario Añadir/Editar producto.
- **Evidencia:** cada cambio de `name` asigna la categoría sugerida cuando existe. No hay estado que registre que la persona eligió manualmente una categoría ni condición que preserve esa decisión.
- **Escenario de fallo:** se selecciona manualmente “Mascotas”, luego se corrige el nombre y el autocompletado reasigna “Despensa” u otra categoría.
- **Impacto para la persona usuaria:** pérdida de control y productos que aparecen en secciones inesperadas.
- **Impacto App Store:** degradación de experiencia; no rechazo directo.
- **Causa raíz:** automatización sin regla de precedencia para la intención explícita.
- **Corrección propuesta:** incorporar `isCategoryManuallyChosen`; aplicar sugerencia sólo en el valor inicial o mientras no exista elección manual, y ofrecer una acción visible para restaurar la sugerencia.
- **Validación de cierre:** editar producto existente, cambiar nombre antes/después de elegir categoría manual y seleccionar una sugerencia de catálogo.

### [ ] F-10 — Media — Integridad / UX — Importador de texto y plantillas omiten control de duplicados

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Views/TextImporterSheet.swift:194-207`; `CasiListo/Views/TemplatesSheet.swift:162-179`; control de duplicados usado por alta normal en `CasiListo/Views/AddEditItemSheet.swift:232-235`.
- **Componente:** importación masiva y plantillas.
- **Evidencia:** ambos flujos insertan todos los ítems seleccionados directamente y guardan al final. No llaman al closure `checkDuplicate` usado por la hoja de producto.
- **Escenario de fallo:** se importa dos veces una lista o se aplica una plantilla con productos ya pendientes en la misma tienda.
- **Impacto para la persona usuaria:** lista duplicada, conteos incorrectos y trabajo extra durante la compra.
- **Impacto App Store:** no rechazo directo; sí inconsistencia de comportamiento entre caminos equivalentes.
- **Causa raíz:** reglas de negocio duplicadas en vistas en vez de un servicio compartido.
- **Corrección propuesta:** centralizar normalización y política de duplicados; en preview marcar repetidos, permitir omitir/reemplazar/añadir de forma explícita y calcular `sortOrder` incrementalmente para el lote.
- **Validación de cierre:** importar texto con mayúsculas/tildes/espacios, repetir importación, aplicar plantilla dos veces y probar mismo nombre en supermercados distintos.

### [ ] F-11 — Media — Búsqueda — Normalización inconsistente entre filtro y resaltado

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/ViewModels/ShoppingListViewModel.swift:82-113`; `CasiListo/Views/ItemRowView.swift:245-259`.
- **Componente:** búsqueda de productos, notas y categorías.
- **Evidencia:** el filtro usa sólo `lowercased().contains`, mientras el resaltado usa `.caseInsensitive` y `.diacriticInsensitive` más trim.
- **Escenario de fallo:** buscar `lider` no encuentra `Líder`, aunque otras superficies sí tratan equivalentes las tildes.
- **Impacto para la persona usuaria:** resultados inesperados y sensación de que la búsqueda falla.
- **Impacto App Store:** no rechazo directo.
- **Causa raíz:** normalización implementada de manera distinta en dos componentes.
- **Corrección propuesta:** crear una única función de normalización que haga trim, case-folding y diacritic-folding para consulta y campos buscables.
- **Validación de cierre:** tabla de casos con tildes, ñ, mayúsculas, espacios iniciales/finales y coincidencias en nombre, nota y categoría.

### [ ] F-12 — Media — Widget / estado — La sincronización puede no ocurrir al cambiar propiedades de un `ShoppingItem`

- **Estado:** PROBABLE — requiere runtime.
- **Archivos / líneas:** `CasiListo/Views/ContentView.swift:19-22, 125-129`; `CasiListo/Services/WidgetDataBridge.swift:19-35`; mutaciones de estado en `CasiListo/ViewModels/ShoppingListViewModel.swift:202-207`.
- **Componente:** snapshot y timeline del widget.
- **Evidencia:** el bridge se escribe al arrancar y con `.onChange(of: activeItems)`. `activeItems` se deriva de una colección de objetos de referencia; cambiar `item.status` puede no cambiar identidad o pertenencia de la matriz y no disparar el `onChange` esperado.
- **Escenario de fallo:** se marca un producto comprado; la lista principal se actualiza, pero el widget sigue mostrando el producto pendiente hasta otro cambio estructural o una recarga posterior.
- **Impacto para la persona usuaria:** el widget pierde su utilidad principal: información inmediata y fiable.
- **Impacto App Store:** experiencia degradada; no rechazo directo salvo que la funcionalidad se presente como actualizada en tiempo real.
- **Causa raíz:** sincronización basada en observación indirecta en lugar de una escritura explícita tras mutaciones exitosas.
- **Corrección propuesta:** emitir snapshot mediante un servicio central tras alta, edición, cambio de estado, eliminación, importación y archivado, sólo cuando el guardado haya sido exitoso. Considerar una representación con IDs y revision token.
- **Validación de cierre:** en dispositivo, modificar estado, nombre, borrado, importación y cierre de lista; comprobar `updatedAt`, contenido y timeline del widget sin reabrir la app.

### [ ] F-13 — Media — WidgetKit — Nombres repetidos se usan como ID de filas

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListoWidget/CasiListoWidget.swift:151-166`; snapshot en `CasiListo/Services/WidgetDataBridge.swift:19-27`.
- **Componente:** widget mediano.
- **Evidencia:** `ForEach(snapshot.topItems.prefix(5), id: \.self)` usa `String` como identidad. El importador permite duplicados y el snapshot sólo serializa nombres, no IDs.
- **Escenario de fallo:** existen dos productos pendientes llamados “Leche”; SwiftUI recibe IDs duplicados y puede omitir, reutilizar o renderizar incorrectamente una fila.
- **Impacto para la persona usuaria:** widget con lista incompleta o visualmente inconsistente.
- **Impacto App Store:** degradación funcional visible.
- **Causa raíz:** modelo de snapshot insuficiente para representar elementos de forma estable.
- **Corrección propuesta:** serializar `WidgetItemSnapshot(id: UUID, name: String)` y utilizar su ID persistente en `ForEach`.
- **Validación de cierre:** crear/importar cinco nombres con duplicados, actualizar widget y verificar todas las filas en tamaños small y medium.

### [ ] F-14 — Media — Audio / permisos — Denegación y fallo de grabación no entregan feedback recuperable

- **Estado:** CONFIRMADO ESTÁTICAMENTE para ausencia de feedback; runtime del permiso NO VERIFICADO.
- **Archivos / líneas:** `CasiListo/Views/Components/AddEditVoiceNoteSection.swift:96-115`; `CasiListo/Services/VoiceNoteService.swift:48-75, 88-125`.
- **Componente:** grabación y reproducción de notas de voz.
- **Evidencia:** cuando `requestRecordPermission()` devuelve `false`, la tarea no informa nada. Si `startRecording` devuelve `false`, tampoco se muestra estado o alerta. El servicio registra errores en logger y usa `try?` al crear/borrar directorios o desactivar sesión.
- **Escenario de fallo:** micrófono denegado, sin espacio, audio ocupado por llamada o archivo imposible de abrir; al tocar grabar no sucede nada explicable.
- **Impacto para la persona usuaria:** incertidumbre, incapacidad de recuperar la función y posible repetición inútil de la acción.
- **Impacto App Store:** no rechazo automático, pero mala gestión de permiso de recurso sensible.
- **Causa raíz:** el contrato del servicio devuelve Bool sin error tipado y la vista no trata estados de fallo/denegación.
- **Corrección propuesta:** usar resultado con error de dominio; mostrar alerta accesible con explicación, reintento y enlace a Ajustes cuando aplique. Escuchar interrupciones/rutas de `AVAudioSession` y sincronizar el estado visual.
- **Validación de cierre:** denegar permiso, revocarlo desde Ajustes, simular interrupción/llamada, desconectar ruta de audio, llenar almacenamiento y probar reproducción de archivo ausente.

### [ ] F-15 — Media — Archivos locales — Dos eliminaciones consecutivas pueden dejar una nota de voz huérfana

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/ViewModels/ShoppingListViewModel.swift:250-307`.
- **Componente:** eliminación con Undo.
- **Evidencia:** sólo existe un `deletedItemUndoBuffer` y un `undoTimerTask`. Al eliminar B durante los cuatro segundos de A, se cancela el timer de A y el buffer se reemplaza por B. El audio de A ya no tiene una ruta de limpieza programada.
- **Escenario de fallo:** eliminar rápidamente dos ítems distintos con notas de voz y no deshacer; el primer archivo queda en `Documents/VoiceNotes` sin modelo que lo refiera.
- **Impacto para la persona usuaria:** consumo de almacenamiento y retención no intencional de una grabación que se creía eliminada.
- **Impacto App Store:** preocupación de privacidad local y mantenimiento; no rechazo directo por sí solo.
- **Causa raíz:** el undo se modela como una única operación global, no como una cola de operaciones pendientes con sus recursos.
- **Corrección propuesta:** conservar una cola identificada por ítem o retirar el archivo al confirmar cada eliminación; no cancelar la limpieza previa cuando se inicia otra eliminación.
- **Validación de cierre:** eliminar dos o más ítems con audio dentro de la ventana de Undo, con y sin restauración, e inspeccionar que el directorio coincide con las referencias de SwiftData.

### [ ] F-16 — Media — UX / datos — Eliminar una categoría reasigna productos sin confirmación ni Undo

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Views/CategoryManagementView.swift:132-159`.
- **Componente:** gestión de categorías.
- **Evidencia:** `deleteCategory` mueve todos los ítems y catálogo al fallback “Varios”, borra relaciones y elimina la categoría inmediatamente. No recibe confirmación, recuento de afectados ni mecanismo de deshacer.
- **Escenario de fallo:** se toca borrar por error una categoría personalizada que contiene muchos productos; toda la organización se pierde en un paso.
- **Impacto para la persona usuaria:** pérdida de clasificación y trabajo de recuperación manual.
- **Impacto App Store:** no rechazo directo; sí patrón destructivo débil para una app de gestión personal.
- **Causa raíz:** la operación irreversible está directamente conectada a la acción UI sin capa de confirmación.
- **Corrección propuesta:** presentar alerta con nombre de categoría y número de productos/catálogo afectados; ofrecer Cancelar y Confirmar, y preferiblemente Undo.
- **Validación de cierre:** categoría vacía, categoría con lista activa, categoría con historial, fallback Varios y cancelación/confirmación con VoiceOver.

### [ ] F-17 — Media — Exportación — CSV no escapa contenido ni mitiga fórmulas

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Views/ShoppingHistoryView.swift:92-105`.
- **Componente:** exportación de historial.
- **Evidencia:** cada campo se interpola entre comillas sin escapar comillas internas ni saltos de línea. No hay protección para nombres que comiencen con `=`, `+`, `-` o `@` al abrir en una hoja de cálculo.
- **Escenario de fallo:** producto `Pan "integral"` o una nota/categoría con salto de línea desestructura filas; una entrada que comienza por `=HYPERLINK(...)` puede evaluarse en software de planillas.
- **Impacto para la persona usuaria:** archivo exportado corrupto, pérdida de fidelidad y riesgo al compartirlo.
- **Impacto App Store:** no rechazo directo.
- **Causa raíz:** CSV construido por concatenación sin serializador ni normalización de campos.
- **Corrección propuesta:** implementar `escapeCSV` que duplique comillas y cubra delimitadores/line breaks; prefijar valores de riesgo según política de exportación; documentar encoding UTF-8 y locale de fecha/precio.
- **Validación de cierre:** abrir exportación en Numbers, Excel y Google Sheets usando comillas, comas, saltos de línea, tildes y prefijos de fórmula.

### [ ] F-18 — Baja — Accesibilidad — La animación continua de grabación ignora Reduce Motion

- **Estado:** CONFIRMADO ESTÁTICAMENTE.
- **Archivos / líneas:** `CasiListo/Views/Components/AddEditVoiceNoteSection.swift:21-29`.
- **Componente:** estado de grabación.
- **Evidencia:** aplica `repeatForever` al pulso del indicador rojo sin consultar `accessibilityReduceMotion`. En contraste, `ItemRowView` sí condiciona una animación a `reduceMotion` en la línea 114.
- **Escenario de fallo:** con Reducir movimiento activado, el punto rojo continúa pulsando indefinidamente.
- **Impacto para la persona usuaria:** incomodidad o distracción para personas sensibles al movimiento.
- **Impacto App Store:** no rechazo automático, pero impide declarar con confianza soporte de Reduce Motion.
- **Causa raíz:** falta de uso del environment de accesibilidad en este componente.
- **Corrección propuesta:** leer `@Environment(\.accessibilityReduceMotion)` y usar opacidad fija, transición mínima o ningún pulso cuando esté activo.
- **Validación de cierre:** activar Reducir movimiento en Ajustes del sistema, iniciar/detener grabación y comprobar ausencia de animación repetitiva.

### [ ] F-19 — Media — Rendimiento / arquitectura — Consultas y transformaciones completas en el actor principal no tienen prueba de escala

- **Estado:** PROBABLE — requiere runtime y profiling.
- **Archivos / líneas:** `CasiListo/Views/ContentView.swift:19-28`; `CasiListo/ViewModels/ShoppingListViewModel.swift:82-113`; `CasiListo/Views/ShoppingHistoryView.swift:92-102`; `CasiListo/Services/ReceiptServices.swift:254-284`.
- **Componente:** lista principal, búsqueda, historial, exportación y comparación de precios.
- **Evidencia:** se filtran y ordenan colecciones completas en memoria; `ContentView` busca todas las listas/ítems; agrupación y orden se recomputan a partir de arrays; CSV hace un filtro de todos los ítems por cada lista completada.
- **Escenario de fallo:** historial extenso, muchos ítems importados y búsqueda mientras se procesa una boleta generan tirones, input lento o consumo elevado.
- **Impacto para la persona usuaria:** interfaz menos fluida, especialmente en dispositivos antiguos soportados por iOS 17.
- **Impacto App Store:** no rechazo directo salvo congelamientos/crashes observables; riesgo de calidad.
- **Causa raíz:** no hay límites, paginación, fetch descriptors especializados ni medición de performance para tamaños representativos.
- **Corrección propuesta:** medir antes de optimizar; mover filtros al `FetchDescriptor` cuando sea conveniente, evitar N×M en CSV/historial, cachear agregados derivados y usar pruebas de datos grandes.
- **Validación de cierre:** Instruments y XCTest de rendimiento con 1.000, 5.000 y 10.000 ítems; historial de boletas; búsqueda por texto; edición rápida y widget activo.

### [ ] F-20 — Alta — Operación de release — No se puede producir ni validar el archive en este entorno

- **Estado:** CONFIRMADO EN EL ENTORNO; no es un defecto del código fuente por sí solo.
- **Archivos / líneas:** configuración de entrega en `CasiListo.xcodeproj/project.pbxproj`; ejecución bloqueada por selección de Command Line Tools.
- **Componente:** pipeline de distribución y calidad.
- **Evidencia:** `xcodebuild` y `simctl` no están disponibles. Apple exige actualmente usar Xcode 26 o posterior con el SDK iOS 26 para subir builds a App Store Connect.
- **Escenario de fallo:** se intenta enviar sin un archive actual que ejecute tests, valide entitlements, Privacy Manifest, firma y warnings Release.
- **Impacto para la persona usuaria:** una regresión visual, de permisos, widget o migración llega sin detección previa.
- **Impacto App Store:** no hay una entrega verificable; el envío debe detenerse hasta archivar con toolchain soportado.
- **Causa raíz:** entorno de auditoría sin Xcode completo y ausencia de evidencia CI/Archive adjunta al repositorio.
- **Corrección propuesta:** instalar/seleccionar Xcode 26+ en una máquina autorizada, automatizar build/test de los targets y conservar artefactos de archive/Privacy Report en CI.
- **Validación de cierre:** `xcodebuild build`, `xcodebuild test`, archive Release, export validation y subida a TestFlight con el binario exacto que se revisará.

---

## 5. Observaciones revisadas que no deben registrarse como bugs actuales

### 5.1 Historial por supermercado

`ShoppingListLifecycleService.archivePurchasedItems` agrupa únicamente los ítems con estado `purchased` y los mueve a una lista completada por tienda. Los ítems pendientes, pospuestos y no encontrados permanecen en la lista activa. Por tanto, que `pendingCount`, `skippedCount` y `unavailableCount` sean cero en la lista histórica creada en `ShoppingListLifecycleService.swift:43-53` es coherente con el comportamiento actual de “archivar comprados”; no se registra como defecto sin un requisito distinto de negocio.

### 5.2 OCR y confirmación de supermercado

El flujo de boletas conserva edición de líneas y selección de tienda antes de registrar. La detección se usa como preselección, no como sustituto de la confirmación manual. Esto es adecuado para OCR, que puede fallar en cabeceras, abreviaturas o promociones.

### 5.3 Entitlements App Group

Los entitlements de app y widget comparten `group.com.allopze.CasiListo`. No se encontró una discordancia entre ambos targets. Esto no resuelve por sí solo el F-01 de Privacy Manifest ni el F-03 de deep link.

### 5.4 Accesibilidad semántica de filas

`ItemRowView` incluye label, value, hint y acciones personalizadas para marcar, editar, posponer, no encontrado y eliminar (`ItemRowView.swift:42-45, 95-114`). Es una buena base. No habilita una declaración de accesibilidad validada hasta ejecutar las pruebas de la sección 8.

### 5.5 Ausencia de networking hallada en la búsqueda estática

No se encontraron `URLSession`, Alamofire, WebSocket ni URLs HTTP/S en fuentes Swift de app/widget. No se debe traducir automáticamente a “la app no recopila datos”: el binario, frameworks del sistema, configuración de App Store Connect y cualquier asset futuro deben revisarse en el archive final.

---

## 6. Privacidad, seguridad y App Review

### 6.1 Mapa de datos observado

| Tipo de dato | Origen | Almacenamiento | Transmisión encontrada | Acción de eliminación |
|---|---|---|---|---|
| Productos, cantidades, notas, tienda, estados y precios | Persona usuaria | SwiftData local | No encontrada estáticamente | Parcial: eliminar producto; no gestión global explícita |
| Historial de compra | Derivado de productos / boletas | SwiftData local | No encontrada estáticamente | No se revisó un borrado de historial global |
| Foto de boleta | Cámara o biblioteca | Application Support | No encontrada estáticamente | Debe validarse al borrar historial/boleta |
| Texto OCR | Procesamiento Vision local | SwiftData como nombres/precios confirmados | No encontrada estáticamente | Según borrado del historial/ítem |
| Nota de voz | Micrófono | Documents/VoiceNotes | No encontrada estáticamente | Hay borrado, con riesgo F-05/F-15 |
| Ubicación de dispositivo | Core Location | No se observa persistencia directa | No encontrada estáticamente | Toggle/permisos del sistema |
| Preferencias y estadísticas | Interacción con app | UserDefaults / App Group | No encontrada estáticamente | Falta política y control documentado |

### 6.2 Declaración de privacidad propuesta, pendiente de confirmar con archive

No se deben completar Privacy Nutrition Labels por inferencia. Con la evidencia actual, la hipótesis a verificar es que los datos permanecen en el dispositivo y no son “collected” por el desarrollador. Antes de declarar **Data Not Collected**, se debe revisar el archive, SDKs enlazados, configuraciones de analítica, crash reporting, tráfico real y la implementación final de soporte/política.

### 6.3 Riesgos de App Review

| Guía / requisito | Riesgo en CasiListo | Acción necesaria |
|---|---|---|
| 2.1 App Completeness | Widget con interacción rota; UI test que exige flujo inexistente | Resolver F-03 y F-07; probar el binario final |
| 2.3 Accurate Metadata | Riesgo si se promociona Modo Compra o geofencing general | Alinear screenshots, descripción y keywords con funcionalidades reales |
| 5.1.1 Data Collection and Storage | Falta política visible dentro de la app | Resolver F-02 |
| Privacy Manifest / Required Reason APIs | No existe manifiesto pese a UserDefaults | Resolver F-01 |
| Permisos y HIG | Flujo de ubicación puede mostrar estado falso | Resolver F-04 y ejecutar matriz real |
| Toolchain de entrega | Debe usarse Xcode 26+ / iOS 26 SDK para upload actual | Resolver F-20 en el pipeline |

### 6.4 Seguridad y resiliencia que requieren una revisión posterior

- Confirmar protección de archivos de fotos y audio en dispositivo bloqueado.
- Auditar eliminación de imágenes de boleta cuando se elimine el historial asociado.
- Verificar que el deep link futuro no acepte acciones destructivas ni datos no validados.
- Verificar que exports no contienen datos inesperados de otras listas ni de App Group.
- Añadir un flujo de eliminación global de datos locales y documentarlo en la política.

---

## 7. Pruebas existentes y brechas

### 7.1 Cobertura encontrada

| Suite | Cobertura aparente | Estado de ejecución |
|---|---|---|
| `CasiListoTests` | ModelContainer in-memory y lógica de lista/catálogo | NO VERIFICADO |
| `PurchaseHistoryTests` | Historial por supermercado, boletas y comparación de precio | NO VERIFICADO |
| `CasiListoUITests.testCreateMarkArchiveAndOpenHistory` | Alta, marcado, archivado e historial | NO VERIFICADO |
| `CasiListoUITests.testShoppingModeSupportsSkippedAndUnavailableActions` | Intenta una funcionalidad inexistente | Fallará probablemente; no ejecutado |

### 7.2 Brechas obligatorias antes de release

| Área | Prueba faltante |
|---|---|
| Privacy Manifest | Validación de archive y comparación contra APIs/targets reales |
| Migración | Base creada con 1.0 abierta por 1.1, con datos y archivos reales |
| Guardado con error | Inyección de save/filesystem failure; UI no confirma éxito |
| Boletas | Imagen inválida, OCR vacío, asociación manual, save fallido, limpieza de foto |
| Audio | Permiso denegado, interrupción, archivo ausente, falta de espacio, doble borrado y Undo |
| Ubicación | Todos los estados de autorización, servicio global desactivado, background y regiones |
| Widget | App Group vacío/corrupto, cambios de estado, nombres duplicados, deep link y tintado |
| Importación | Duplicados, tildes, nombres equivalentes, lotes grandes y cancelación |
| CSV | RFC 4180/compatibilidad con Numbers, Excel y Google Sheets |
| Rendimiento | 1k/5k/10k ítems, búsqueda, historial, OCR y widget concurrentes |
| Accesibilidad | VoiceOver, Voice Control, Switch Control, Dynamic Type, contraste y Reduce Motion |
| iPad | Portrait, Split View/Stage Manager cuando aplique, teclado y tamaños variados |

### 7.3 Orden recomendado para recuperar la suite

1. Corregir o retirar `testShoppingModeSupportsSkippedAndUnavailableActions` según la decisión de producto.
2. Hacer que persistencia y servicios devuelvan errores testeables en lugar de logs silenciosos.
3. Introducir protocolos/inyección para `VoiceNoteService`, `GeofenceService`, reloj y filesystem.
4. Añadir fixtures de SwiftData versionadas y App Group aislado para widget.
5. Ejecutar unit tests en CI y UI tests en un runtime iOS soportado.

---

## 8. Matriz de validación manual obligatoria

### 8.1 Dispositivos y apariencia

| Caso | Debe comprobarse |
|---|---|
| iPhone compacto | Lista, formularios, teclado, hoja de boleta, menú, toast Undo |
| iPhone grande | Alcance de controles, widget, modo oscuro y Dynamic Type |
| iPad | Layout, orientación soportada, presentación de sheets, contenido no truncado |
| iOS 17 | Flujos base y disponibilidad de APIs |
| iOS 26 | Widget tintado, icono tintado, materiales y requisitos de upload |
| Claro / oscuro | Contraste, iconos, cards, estado comprado y widget |
| Aumentar contraste / Reducir transparencia | Legibilidad de superficies y botones |
| Texto grande máximo | Formularios, filtros, celdas, controles, mensajes y hojas |
| Reducir movimiento | Grabación, transiciones, marcado y toast |

### 8.2 Tecnologías asistivas

| Tecnología | Casos obligatorios |
|---|---|
| VoiceOver | Añadir, editar, marcar, posponer, no encontrado, eliminar/deshacer, importar, boleta, audio, ajustes y widget |
| Voice Control | Nombres visibles de botones, duplicidad de controles, acciones contextuales y navegación de sheets |
| Switch Control | Acciones personalizadas de ItemRow, foco predecible, eliminar categoría y CTA de permisos |
| Full Keyboard Access en iPad | Orden de foco, Escape en sheets, activar botones y menús |

No se debe declarar aún ninguna Accessibility Nutrition Label como validada. En particular, **Reduce Motion no es conforme** hasta corregir F-18 y ejecutarlo en runtime.

### 8.3 Permisos y resiliencia

| Permiso / recurso | Estados que se deben ejecutar |
|---|---|
| Cámara | Permitir, denegar, cancelar captura, foto inválida, autorización revocada |
| Fotos | Acceso limitado, denegado, selección cancelada, imagen grande y corrupta |
| Micrófono | Permitir, denegar, revocar, interrupción de llamada, ruta Bluetooth/cable, falta de almacenamiento |
| Notificaciones | Permitir, denegar, ajustes del sistema y alerta al entrar a región |
| Ubicación | Not determined, When In Use, Always, denied, restricted, servicios globales off, cambio desde Ajustes |
| Persistencia | Reinicio forzado durante alta, edición, archivado, boleta y borrado |

---

## 9. Puntuación ponderada de preparación

| Área | Máximo | Puntaje | Justificación |
|---|---:|---:|---|
| Lógica funcional | 20 | 11 | Flujos principales existen, pero Modo Compra falta y hay inconsistencias de importación/búsqueda |
| UX y HIG | 15 | 8 | Base cuidada, pero operaciones destructivas, geofencing y estados de error requieren trabajo |
| Persistencia e integridad | 10 | 3 | Guardado silencioso, archivos no transaccionales y migración no demostrada |
| Privacidad y permisos | 10 | 2 | Falta manifiesto, política y flujo robusto de ubicación |
| Accesibilidad | 10 | 5 | Buena semántica en filas; matriz real pendiente y Reduce Motion no cubierto |
| Widget / App Group | 10 | 4 | Entitlements coherentes, pero deep link roto, posible stale state e IDs duplicados |
| Rendimiento / estabilidad | 10 | 5 | Diseño simple, sin medición ni pruebas de volumen/fallo |
| Arquitectura y tests | 5 | 3 | Código nativo y test base; suite rota/insuficiente y servicios difíciles de simular |
| Operación App Store | 10 | 3 | Versionado básico, iconos presentes; no hay archive actual ni privacidad completada |
| **Total** | **100** | **44** | **No apta para envío** |

### 9.1 Decisión por etapa

| Etapa | Estado | Condición |
|---|---|---|
| Desarrollo local | Amarillo | Se puede continuar corrigiendo y añadiendo pruebas |
| Beta cerrada | Rojo | Resolver F-01 a F-07 y ejecutar tests básicos antes de invitar usuarios |
| TestFlight amplio | Rojo | Añadir validación de permisos, audio, migración, widget y accesibilidad |
| App Store | Rojo | Archive Release, privacidad, política, metadata y matriz manual completadas |

La probabilidad estimada de aprobación en primera revisión, si se enviara el binario actual sin resolver las condiciones anteriores, es **25%**. No es una predicción de Apple: es una señal de riesgo basada en bloqueadores estáticos y falta de evidencia ejecutable.

---

## 10. Plan de remediación completo

### Fase A — Bloqueadores de envío

1. Crear y validar Privacy Manifest para targets aplicables.
2. Publicar política de privacidad y enlazarla desde Ajustes y App Store Connect.
3. Registrar y manejar el URL scheme del widget, o retirar la interacción.
4. Reescribir el flujo de permisos de ubicación como máquina de estados.
5. Sustituir guardados silenciosos por errores recuperables y hacer transaccionales los recursos de disco.
6. Definir y probar migración 1.0 → 1.1.
7. Decidir e implementar o retirar Modo Compra junto con su test, documentación y metadata.
8. Instalar/usar Xcode 26+ y producir el primer archive verificable.

### Fase B — Integridad, coherencia y confianza

1. Preservar selección manual de categoría frente a sugerencias.
2. Centralizar normalización y duplicados para alta, importación y plantillas.
3. Corregir CSV y establecer una política de exportación segura.
4. Añadir confirmación/Undo para borrado de categoría.
5. Corregir cola de archivos pendientes de eliminación de audio.
6. Definir una fuente de verdad del snapshot del widget y usar IDs estables.
7. Decidir cobertura real de sucursales para geofencing.

### Fase C — Calidad de producto

1. Manejar denegación/interrupción/fallo de audio con feedback accesible.
2. Respetar Reduce Motion en grabación.
3. Medir rendimiento antes de optimizar y eliminar transformaciones N×M donde sean demostrablemente costosas.
4. Añadir pruebas de volumen, recuperación y flujos de personas mayores.
5. Ejecutar revisión visual en iPhone, iPad, claro, oscuro, texto grande y configuraciones de contraste.

---

## 11. Checklist final de envío

No marcar una casilla sin adjuntar evidencia del binario exacto.

### Código y datos

- [ ] F-05 resuelto: ningún flujo confirma éxito antes de persistir.
- [ ] F-06 resuelto: migración 1.0 → 1.1 probada sobre datos y archivos reales.
- [ ] Modo Compra implementado y probado, o retirado por completo.
- [ ] Importación y plantillas cumplen la misma política de duplicados que alta manual.
- [ ] CSV probado con contenido especial.
- [ ] Geofencing representa un alcance real y comunicable.

### Privacidad y App Store

- [ ] `PrivacyInfo.xcprivacy` incluido y validado en cada target necesario.
- [ ] Política de privacidad pública, exacta y accesible desde la app.
- [ ] Privacy Nutrition Labels revisadas contra archive y tráfico real.
- [ ] Screenshots, descripción, keywords y soporte no prometen funciones ausentes.
- [ ] URL de soporte y contacto operativos.

### Calidad técnica

- [ ] `xcodebuild build` Release exitoso con Xcode soportado.
- [ ] Unit tests ejecutados y aprobados.
- [ ] UI tests actualizados y aprobados.
- [ ] Archive creado, firmado y validado.
- [ ] Widget probado en tamaños soportados, con App Group vacío/corrupto y deep link.
- [ ] Permisos probados en todos sus estados.

### Accesibilidad y dispositivos

- [ ] VoiceOver recorrido completo sin bloqueos ni etiquetas ambiguas.
- [ ] Voice Control y Switch Control verifican controles principales.
- [ ] Dynamic Type máximo no corta controles ni oculta CTA.
- [ ] Reduce Motion, contraste y transparencia reducida revisados.
- [ ] iPhone compacto, iPhone grande e iPad probados.

---

## 12. Fuentes oficiales consultadas

- [App Review Guidelines — Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Privacy manifest files — Apple Developer](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files?changes=_9&language=objc)
- [Upcoming requirements — Apple Developer](https://developer.apple.com/news/upcoming-requirements/)
- [Human Interface Guidelines: Accessibility — Apple Developer](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- [Human Interface Guidelines: Materials — Apple Developer](https://developer.apple.com/design/human-interface-guidelines/materials)

---

## 13. Nota sobre el informe anterior del repositorio

El repositorio ya contiene `AUDITORIA_COMPLETA_CASILISTO.md`, fechado el 30 de julio de 2026. No se modificó para preservar su historial. Contiene referencias a archivos y funcionalidades que no están presentes en la revisión actual —por ejemplo, `ShoppingModeViewModel`, `ShoppingModeHeaderView` y `AchievementsView`— y no debe usarse como criterio de release sin contrastarlo con este informe y el código vigente.
