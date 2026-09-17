# CasiListo — UI/UX Polish & Production Readiness Audit

**Fecha de corte:** 14 de septiembre de 2026

**Estado auditado:** `main`, worktree con cambios locales sin commit

**Alcance real del producto:** iPhone, orientación vertical, iOS 26+, Swift 6, app local sin cuenta ni backend
**Evidencia:** revisión estática completa, 46 capturas reales (40 en iPhone 17 Pro claro/oscuro y 6 en iPhone 17e con Accessibility XXL), 208 pruebas unitarias ejecutadas, build Release sin firma, manifiestos de privacidad, sitio estático y comprobación pública de DNS.

> **Criterio de certeza.** “Verificado” significa observado en código, artefacto o ejecución de esta auditoría. “Needs Runtime Verification” identifica pruebas que requieren un runtime iOS 26, dispositivo físico, VoiceOver, permisos reales, firma de distribución o App Store Connect. No se declara como roto lo que no pudo probarse.

## 1. Executive Summary

CasiListo ya tiene una experiencia visual coherente y reconocible. La jerarquía es clara, el amarillo de marca se usa con una tinta de contraste específica, las superficies se adaptan correctamente entre claro y oscuro y el flujo principal —crear una lista, añadir productos, comprar, registrar boleta y consultar historial— se entiende sin capacitación previa. La navegación de cuatro pestañas es estable; el primer uso y los estados vacíos son especialmente buenos. La implementación usa SwiftUI, SwiftData y Liquid Glass de forma compatible con el piso real iOS 26, por lo que no corresponde exigir fallbacks antiguos.

La base funcional también es fuerte: el target unitario completó 208 pruebas sin fallos; el build Release para dispositivo terminó correctamente; app y widget contienen manifiestos válidos; existen pruebas de migración, importación/exportación, OCR, cantidades, contraste, persistencia y contrato del widget. Las 40 capturas de iPhone 17 Pro muestran adaptación clara/oscura correcta en las rutas cubiertas. Sin embargo, una corrida adicional en iPhone 17e con Accessibility XXL confirmó truncamiento severo en primer uso, plantillas, detalle y catálogo.

La compilación exacta no debe enviarse hoy. Las URLs compiladas de privacidad y soporte (`casilisto-privacy.pages.dev`) no resuelven por DNS, aunque Apple exige una política accesible tanto en App Store Connect como dentro de la app. Es un bloqueo comprobado. Además, no hay evidencia cerrada de Archive firmado, exportación IPA, carga a TestFlight, ejecución en el piso iOS 26 ni pruebas físicas de cámara, micrófono y widget.

Hay tres riesgos técnicos relevantes. El arnés “full-length” introdujo un `VStack` eager en la pantalla real de detalle histórico para beneficiar una captura, debilitando el rendimiento de listas largas. Sus imágenes dark son idénticas byte a byte a las light y el catálogo se trunca a seis elementos por categoría, por lo que ese arnés no puede considerarse evidencia de Dark Mode o contenido completo. Finalmente, la cola de acciones del widget se elimina antes del commit: ante un fallo de persistencia, una compra marcada desde el widget puede perderse silenciosamente.

La recomendación es una remediación corta, no un rediseño: publicar las páginas legales, desacoplar el arnés de producción, endurecer la cola del widget y completar la matriz física/accesible y el pipeline firmado.

## 2. Final Verdict

## 🔴 NOT READY

El producto es un beta avanzado y visualmente pulido, pero la compilación actual no cumple todavía los requisitos verificables para publicación pública. El dominio legal fuera de servicio es un bloqueo objetivo de App Review; la evidencia firmada, física y del piso iOS 26 sigue pendiente.

## 3. Final Score

**76/100 — nota chilena 5,2/7,0**

Escala usada: 60 puntos = 4,0; 70 = 4,7; 80 = 5,5; 90 = 6,2; 100 = 7,0. La nota representa preparación para release público, no solo calidad visual.

## 4. Would You Ship

**NO.** No enviaría esta compilación mientras privacidad y soporte no resuelvan públicamente. Después exigiría Archive firmado/TestFlight, prueba en iOS 26 y recorrido físico de permisos/widget.

No hace falta rehacer la interfaz; hace falta cerrar riesgos concretos y evidencia de release.

## 5. Release Blockers

1. **Privacidad y soporte no están publicados.** `curl` falló por resolución de host y `dig +short casilisto-privacy.pages.dev` no devolvió registros. La app abre esas URLs desde [AppSupportLinks.swift](../CasiListo/Services/AppSupportLinks.swift#L3-L5) y la checklist aún deja el despliegue sin marcar en [VALIDACION_LANZAMIENTO.md](VALIDACION_LANZAMIENTO.md#L9-L19). Apple exige una URL de política en App Store Connect y acceso a la política dentro de la app en sus [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
2. **Artefacto distribuible no verificado.** El build Release sin firma pasó, pero Archive firmado, exportación IPA, firma del App Group, upload y procesamiento en TestFlight son **Needs Runtime Verification**.
3. **Piso declarado no ejecutado.** Solo había runtimes iOS 27.0. La compatibilidad real con iOS 26.0 es **Needs Runtime Verification** antes de publicar.

## 6. Polish Blockers

1. Separar las vistas/cambios del arnés full-length del código de producción y restaurar renderizado lazy en historial.
2. Corregir la durabilidad de acciones del widget ante fallos de persistencia.
3. Diferenciar “widget sin snapshot” de “lista realmente vacía”.
4. Corregir la semántica roja/destructiva de “Archivar”.
5. Corregir el truncamiento confirmado con Accessibility XXL en iPhone compacto; después completar AX5, VoiceOver y Pro Max.

## 7. Score Breakdown

| Área | Peso | Puntaje | Fundamento |
|---|---:|---:|---|
| Visual polish | 20 | **18** | Identidad consistente, jerarquía sólida y adaptación claro/oscuro verificada; quedan densidad y redundancias menores. |
| UX & navigation | 20 | **17** | Flujo principal comprensible, buenos vacíos y navegación estable; Ajustes prioriza ayuda sobre tareas y hay CTAs duplicados. |
| Interaction & microinteraction | 10 | **8** | Buen feedback, undo, estados y blancos táctiles; “Archivar” usa rol destructivo incorrecto. |
| Accessibility | 10 | **5** | Fuentes semánticas, objetivos de 44 pt, etiquetas y contraste; Accessibility XXL en iPhone compacto presenta truncamiento severo y VoiceOver/AX5 no se ejecutaron. |
| Functional reliability & data | 15 | **13** | 208 pruebas unitarias pasan y la persistencia tiene rollback; quedan dos defectos del contrato widget. |
| Stability & performance | 10 | **7** | OCR/imagen/audio sacan trabajo pesado del main thread; historial eager y operaciones de respaldo requieren medición. |
| Production & App Store | 10 | **4** | Build Release y manifests válidos; URLs legales caídas y pipeline firmado/metadata pendientes. |
| Tests & regression risk | 5 | **4** | Suite amplia y capturas reales; el arnés full-length es inválido y el test de performance no tiene umbral. |
| **Total** | **100** | **76** | **No apto para release público aún.** |

## 8. Screen Matrix

| Pantalla / flujo | Entrada | Acción primaria | Vacío | Loading | Error | Destructiva | Claro/oscuro | Dynamic Type | VoiceOver | Estado |
|---|---|---|---|---|---|---|---|---|---|---|
| Mis Listas | Compra | Abrir/crear lista | Verificado | N/A | Alerta persistencia | Eliminar lista con confirmación | Verificado | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Primer arranque | Compra sin listas | Crear / sugerida | Verificado | N/A | Banner si store falla | N/A | Verificado | Truncamiento en XXL compacto | Needs Runtime Verification | Requiere corrección |
| Nueva/editar lista | `+` o menú tarjeta | Guardar | Validación inline | N/A | Alerta | N/A | Parcial | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Detalle de compra | Tarjeta de lista | Marcar/añadir | Verificado | N/A | Alerta persistencia | Borrar producto + undo | Verificado | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Añadir/editar producto | Fila o barra inferior | Guardar | Validación | Grabación de audio | Alerta | Borrar audio | Parcial | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Importar texto | Menú de lista | Procesar | Campo vacío | N/A | Alerta | N/A | Verificado | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Plantillas | Menú / lista vacía | Añadir plantilla | N/A | N/A | Alerta | N/A | Verificado | Truncamiento en XXL compacto | Needs Runtime Verification | Requiere corrección |
| Catálogo | Pestaña Catálogo | Añadir/quitar | Tiene contenido semilla | N/A | Alerta | Quitar de compra | Verificado | Truncamiento severo en XXL compacto | Needs Runtime Verification | Requiere corrección |
| Cerrar compra / boleta | Menú / resumen | Escanear/elegir foto | Estado inicial verificado | OCR y guardado explícitos | Alertas específicas | Descartar/cancelar | Verificado | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Historial | Pestaña Historial | Abrir / exportar CSV | Implementado | N/A | Alertas | Eliminar compra con confirmación | Verificado | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Detalle historial | Compra histórica | Revisar detalle/boleta | Implementado | Miniatura async | Fallback sin productos | N/A | Verificado | Needs Runtime Verification | Needs Runtime Verification | Riesgo eager |
| Categorías | Ajustes | Crear/editar/reordenar | Categoría fallback | N/A | Alerta | Eliminar con confirmación | Revisión estática | Needs Runtime Verification | Needs Runtime Verification | Buena |
| Ajustes | Pestaña Ajustes | Privacidad/datos | N/A | Sin indicador en respaldo | Alertas | Borrar todo con confirmación | Verificado | Needs Runtime Verification | Needs Runtime Verification | Jerarquía mejorable |
| Widget | Home/Lock Screen | Abrir o marcar comprado | Defecto confirmado | Timeline del sistema | Sin UI de error | N/A | Revisión estática | Sistema limitado | Etiqueta en botones medium | Riesgo funcional |

## 9. Product Flow Assessment

El flujo mental es correcto: **listas → lista activa → compra → archivo/historial**. Catálogo y Ajustes quedan como herramientas laterales; Historial es destino estable. La selección de lista activa se comparte con Catálogo, evitando añadir a un destino ambiguo. Las rutas desconocidas del deep link se ignoran y `casilisto://list` vuelve a Compra.

Fortalezas:

- El primer arranque ofrece creación explícita y tres atajos, sin pantalla vacía muerta.
- La lista vacía combina básicos, creación manual y plantillas.
- La boleta explica qué se procesará y que todo queda local antes de pedir cámara/foto.
- El historial conserva compras sin precios, evitando pérdida de información.

Fricciones:

- La pantalla Mis Listas expone dos controles visibles para “Nueva” cuando ya hay listas.
- Ajustes comienza con una guía extensa que ya aparece en onboarding, relegando privacidad y respaldo.
- “Archivar” se pinta como acción destructiva aunque mueve datos al historial.

## 10. Visual Polish Audit

Las capturas reales muestran una identidad cálida, clara y consistente. La escala de radios, tarjetas blancas/oscuro carbón, tipografía redondeada y acento amarillo funciona. La pantalla vacía de Mis Listas es la pieza más lograda: icono, mensaje, CTA y sugerencias forman una jerarquía nítida.

En Compra, filtros, resumen y tarjeta de categoría se leen por capas. El campo inferior y el tab bar usan vidrio nativo sin ocultar la acción principal. En Catálogo, las filas admiten nombres de dos líneas y conservan el botón a la derecha. En Historial, la densidad es baja y legible.

Aspectos a pulir: la guía de Ajustes ocupa casi toda la primera ventana; la tarjeta-resumen y el botón de toolbar compiten para crear una lista; algunas capturas de catálogo quedan bajo el tab bar durante el scroll, comportamiento nativo pero que exige revisar el último elemento en tamaños grandes.

## 11. Design System Consistency

`Theme` centraliza espaciado, radios, target mínimo de 44 pt, tipografía dinámica, colores de estado y contraste. La regla “amarillo como relleno, oro como tinta” es correcta y está probada. `@ScaledMetric` se usa en componentes de densidad variable.

Liquid Glass está justificado en filtros, navegación y controles flotantes. Como el piso real es iOS 26, no se necesita `#available` para APIs de vidrio. El uso coincide con la documentación de Apple para [Liquid Glass en vistas personalizadas](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

Inconsistencia estructural: las vistas full-length duplican piezas reales y reemplazan controles interactivos por facsímiles; no son parte del sistema de diseño y no deben compilarse en el target de producción.

## 12. UX & Navigation Audit

La barra de cuatro pestañas es predecible y persistente. Cada pestaña contiene su propio `NavigationStack` o flujo equivalente. No se observaron rutas sin salida en las capturas. La navegación por UUID vuelve a raíz si una lista desaparece mientras está abierta.

La arquitectura soporta múltiples listas sin convertir el concepto en navegación compleja. La lista seleccionada se almacena explícitamente y Catálogo muestra el destino. Los modales usan títulos, Cancelar/Guardar y detent grande, adecuados para formularios.

La decisión de iPhone vertical es explícita en README y build settings. No se penaliza como un bug, pero debe reflejarse en ficha, QA y expectativas de soporte.

## 13. Interaction & Microinteraction Audit

Se verificaron blancos de 44 pt en checkbox, menú de fila y acciones de catálogo. Hay hápticos de selección/éxito y undo de borrado. Las categorías exponen estados colapsado/expandido y el producto recién comprado permanece visible brevemente antes de ocultarse.

`accessibilityReduceMotion` se propaga al view model y las animaciones de contenido pueden anularse. Queda una mejora menor: los estilos de botón personalizados animan el estado presionado directamente; conviene confirmar en dispositivo que Reducir movimiento conserva feedback sin resultar excesivo.

El único error semántico comprobado es el `role: .destructive` de Archivar.

## 14. Empty / Loading / Error States

Estados vacíos verificados: sin listas, lista vacía, historial sin datos y detalle histórico sin productos. Todos incluyen explicación y, cuando corresponde, recuperación. OCR tiene estado de reconocimiento; guardado de boleta usa `isSaving`; formularios muestran validación o alertas.

La persistencia dispone de un banner visible si la base cae a memoria o si falta el store. Es una buena defensa: evita que el usuario confunda una sesión no durable con datos guardados.

Debilidades:

- Importar/exportar respaldo no muestra progreso y ejecuta lectura/fetch/encoding en `@MainActor`.
- El widget no diferencia “nunca abierto” de “lista real vacía”.
- Los fallos al aplicar acciones pendientes del widget se silencian con `try?`.

## 15. Apple-native Experience

La app se siente nativa: SwiftUI, `NavigationStack`, `TabView`, `Form`, `confirmationDialog`, Share Sheet, PHPicker, Document Camera, App Intents y WidgetKit. Los permisos aparecen al usar la función, no al iniciar. La cámara ofrece alternativa de fototeca.

El target usa la sintaxis histórica `.tabItem`; funciona, pero la migración al tipo `Tab` moderno puede evaluarse como mantenimiento, no como condición de release. No se recomienda cambiarlo solo por novedad si no mejora comportamiento observable.

## 16. Accessibility

Fortalezas verificadas en fuente:

- Fuentes semánticas y `@ScaledMetric` en componentes principales.
- Targets táctiles de 44 pt.
- Etiquetas, valores, hints y acciones personalizadas en filas, filtros, categorías, widget e historial.
- Contraste automatizado de acento, estados y badges.
- Soporte explícito de Reducir movimiento.

Accessibility XXL se ejecutó en iPhone 17e y confirmó que el layout no conserva la legibilidad: el texto del estado vacío se extiende bajo el tab bar, los títulos y CTAs se eliden, el contenido de plantilla desborda la ventana y las filas del catálogo colapsan a pocas letras por línea. AX5, VoiceOver, Voice Control, Switch Control, Reducir transparencia y Aumentar contraste siguen **Needs Runtime Verification**. Apple indica que solo debe declararse una función en Accessibility Nutrition Labels si todas las tareas comunes pueden completarse con ella; no marcar soporte hasta cerrar la matriz en [App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels).

## 17. Responsive UI & Dynamic Type

La jerarquía usa scroll, texto multilínea y métricas escaladas, pero esas decisiones no bastan en el extremo probado. La prueba `testFirstRunStartsEmptyAndTemplatePopulatesList` pasó funcionalmente en iPhone 17e/iOS 27 con Accessibility XXL y produjo seis capturas. Visualmente falló: el estado vacío queda oculto por el tab bar; el detalle elide título, subtítulo y acciones; Plantillas deja el CTA fuera de la primera ventana; y Catálogo comprime palabras a columnas de una a tres letras y corta etiquetas del tab bar. No es un falso positivo del test: la automatización valida presencia/acciones, no calidad del layout.

Pro Max, AX5 y el piso iOS 26 siguen **Needs Runtime Verification**. La guía oficial de [layout](https://developer.apple.com/design/human-interface-guidelines/layout) exige adaptarse a tamaño, safe areas y Dynamic Type; la matriz debe cerrarse antes de declarar compatibilidad accesible.

## 18. Dark Mode & Appearance

Las 20 capturas oscuras reales del worktree muestran fondos, tarjetas, separadores, texto, acento y vidrio adaptados correctamente. No se observaron texto negro sobre fondo oscuro ni estados ilegibles. Las paletas de categoría mantienen distinción.

Las cinco imágenes oscuras de `build/screenshots-full` no son evidencia: sus SHA-256 coinciden exactamente con las cinco claras. Este defecto corresponde al arnés `ImageRenderer`, no al Dark Mode real de la app.

## 19. Modo Compra Deep Dive

Modo Compra concentra adecuadamente la experiencia:

1. La lista activa muestra identidad, tienda y menú en navegación.
2. Filtros Todos/Jumbo/Líder reducen ruido sin ocultar el destino.
3. Resumen expone pendientes y control de comprados.
4. Categorías colapsables mantienen listas de cientos de ítems manejables.
5. Cada fila tiene checkbox, nombre editable, metadatos y menú explícito.
6. La barra inferior permite alta rápida o con detalle y muestra sugerencias.
7. Plantillas e importación de texto resuelven cargas masivas.
8. Cerrar con boleta integra OCR, corrección, precios e historial.

Riesgos: el fixture de 363 ítems prueba estrés visual, pero el rendimiento de scroll real debe medirse en Release/dispositivo; el test actual mide derivación del view model sin umbral de regresión. El archivo histórico usa render eager en el worktree actual.

## 20. Widget Polish

El widget ofrece familias small, medium y accesorias; medium permite marcar productos con App Intent. Las etiquetas de accesibilidad de sus botones son claras y el snapshot optimista entrega feedback inmediato.

Dos defectos impiden considerarlo terminado:

- `isPlaceholder` se deriva de contadores vacíos, por lo que una lista realmente vacía muestra “Abre CasiListo para empezar”.
- La cola se borra antes del fetch/commit. Si persiste un error, no se reencola y la app oculta el fallo.

## 21. Functional Reliability

La suite unitaria ejecutada pasó completa: **208/208 pruebas**, excluyendo únicamente cinco tests de generación full-length. Cubre persistencia, migraciones, catálogo, listas múltiples, OCR, cantidades, CSV, importación JSON, contraste, store recovery y widget.

El build Release para dispositivo con validación de producto terminó en `BUILD SUCCEEDED`. La ejecución UI produjo las 40 imágenes, pero Xcode 27 falló después al guardar el result bundle (`mkstemp: No such file or directory`); por eso el script informó 0/2 aunque los PNG quedaron escritos. Es una falla del arnés/infraestructura, no evidencia de un crash funcional.

## 22. Data Integrity

Fortalezas:

- `ShoppingPersistenceCoordinator` hace rollback al fallar `context.save()`.
- Registro de boleta elimina el JPEG si falla la transacción.
- Importación es aditiva, idempotente, versionada y descarta referencias a blobs ausentes.
- Migraciones y ubicación del store tienen pruebas específicas.
- CSV escapa RFC 4180 y prefijos de fórmula.

Riesgo confirmado: la acción pendiente del widget se drena de UserDefaults antes del commit; el rollback de SwiftData no restaura esa cola.

## 23. Performance & Lifecycle

Bien resuelto: OCR, compresión de boleta y activación de `AVAudioSession` salen del main thread; tareas cancelables sustituyen trabajo obsoleto; `LazyVStack` se usa en listas activas; el bootstrap costoso se limita a una vez por lanzamiento.

Pendientes:

- [ShoppingHistoryDetailView.swift](../CasiListo/Views/ShoppingHistoryDetailView.swift#L44-L78) cambió de `LazyVStack` a `VStack` para `ImageRenderer`; renderiza todo el historial abierto.
- [SettingsView.swift](../CasiListo/Views/SettingsView.swift#L186-L225) lee, decodifica, consulta y escribe respaldos en el actor principal sin progreso.
- `ContentView` y `CatalogView` observan colecciones completas. La prueba de 1.000/5.000/10.000 elementos mide tiempo, pero no establece un límite que haga fallar CI.
- Time Profiler, memoria, energía y app lifecycle en dispositivo son **Needs Runtime Verification**.

## 24. Privacy & Permissions

La app no contiene SDKs de analítica, ads, tracking, login, red propia ni ubicación. Usa cámara, PHPicker y micrófono con textos de uso concretos. La política local describe almacenamiento, boletas, audio, App Group y respaldo del dispositivo.

App y widget contienen `PrivacyInfo.xcprivacy` válidos, sin tracking ni datos recopilados, y declaran razones de UserDefaults. El script de validación pasó. Apple mantiene los requisitos de manifiestos y APIs de razón requerida en [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

La frase web “Puedes exportar todo en JSON” debe corregirse: el JSON no incluye las fotos ni notas de voz, aunque la sección detallada enumera correctamente el contenido estructurado.

## 25. Production Configuration

Verificado en build Release:

- Bundle ID app: `com.allopze.CasiListo`.
- Widget: `com.allopze.CasiListo.widget`.
- App Group coincidente: `group.com.allopze.CasiListo`.
- Versión `1.0`, build local `1`; workflow reemplaza el build por un número monótono.
- iOS mínimo 26.0, iPhone, portrait, arm64.
- Descripción de cámara y micrófono presente.
- `ITSAppUsesNonExemptEncryption = false`.
- Iconos color/tinted 1024×1024.
- App Release sin firma: 12 MB; binario principal 9,5 MB; widget 508 KB.

Desde el 28 de abril de 2026 Apple exige Xcode 26+ y SDK iOS 26+ para uploads; la auditoría usó Xcode 27/SDK 27, por lo que cumple el requisito de herramienta publicado en [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).

## 26. App Store Readiness

No listo. Las URLs legales no resuelven y la metadata permanece como checklist manual. Deben prepararse screenshots para los tamaños requeridos por la ficha actual; Apple permite de 1 a 10 y prioriza 6,9 pulgadas para iPhone según [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). iPad no aplica porque el target es iPhone-only.

Archive firmado, reporte de privacidad del Organizer, validación de entitlements, App Privacy, Accessibility Nutrition Labels, descripción, subtítulo, keywords, categorías, Review Notes y TestFlight son **Needs Runtime Verification**.

## 27. Testing & Regression Risk

La cobertura lógica es superior al promedio para un 1.0. La suite está bien dirigida a invariantes de dominio y casos históricos. El CI fija Xcode y SwiftLint y valida privacidad.

Debilidades:

- El arnés full-length modifica vistas de producción y entrega resultados falsos para Dark Mode/contenido completo.
- El runner visual real produjo PNGs pero no un `.xcresult` válido en esta sesión.
- No hay snapshots con aserciones visuales; las capturas requieren inspección humana.
- Performance usa `measure` sin baseline/umbral.
- No hay gate automatizado AX5, VoiceOver ni runtime iOS 26.

## 28. Top 10 Polish Issues

1. Accessibility XXL en iPhone compacto trunca contenido y vuelve ilegibles filas del catálogo.
2. “Nueva lista” aparece en toolbar y tarjeta-resumen al mismo tiempo.
3. Guía de uso domina el primer viewport de Ajustes y duplica onboarding.
4. “Archivar” adopta color/rol destructivo pese a conservar los datos.
5. El widget vacío muestra copy de primer uso después de haber usado la app.
6. Mensajes de importación usan “lista(s)” y “producto(s)” en lugar de pluralización natural.
7. El arnés full-length sustituye controles reales por facsímiles, degradando fidelidad visual.
8. El catálogo full-length se titula “completo” pero limita a seis ítems por categoría.
9. Ajustes deja acciones de respaldo/borrado bajo varias pantallas de scroll.
10. La política resume “exportar todo” aunque excluye archivos multimedia.

## 29. Top 10 Production Risks

1. Dominio legal sin DNS — rechazo o imposibilidad de completar la ficha.
2. Archive firmado/TestFlight no verificados.
3. Compatibilidad con iOS 26 no ejecutada.
4. Acción del widget perdida si falla persistencia.
5. Render eager en historial introducido por un arnés de screenshots.
6. Evidencia full-length dark inválida y potencialmente engañosa.
7. Cámara, micrófono, interrupciones de audio y OCR real no probados físicamente.
8. Accessibility XXL falla en iPhone compacto; AX5/VoiceOver/Voice Control/Switch Control siguen sin verificar.
9. Importación/exportación y queries completas pueden bloquear con volúmenes grandes.
10. App Store metadata, labels, screenshots y Review Notes siguen sin cierre comprobable.

## 30. Critical Findings

**Ninguno.** No se encontró pérdida generalizada de datos, crash reproducible del flujo principal, credenciales expuestas, tracking oculto ni bloqueo total de uso.

## 31. High Findings

### CASI-101 — URLs legales públicas no resuelven

- **ID:** CASI-101
- **Severity:** High
- **Confidence:** Verificado
- **Category:** Production / App Store / Privacy
- **Screen/Component:** Ajustes → Privacidad y soporte
- **Title:** La política de privacidad y el soporte compilados están fuera de línea
- **File:** `CasiListo/Services/AppSupportLinks.swift`
- **Lines:** 3–5
- **Evidence:** `curl -fsSIL` devolvió “Could not resolve host”; `dig +short` no devolvió DNS; la checklist mantiene el deploy pendiente.
- **Observed behavior:** Los enlaces de Ajustes apuntan a un host inexistente públicamente.
- **Expected experience:** Ambas páginas responden por HTTPS con contenido final antes de App Review.
- **User impact:** No puede consultar privacidad ni soporte desde la app.
- **Release impact:** Bloquea release público y expone rechazo por metadata incompleta/no funcional.
- **Recommended improvement:** Configurar variables/secrets, desplegar Cloudflare Pages y validar desde red externa; si cambia el dominio, actualizar app y metadata.
- **Acceptance criteria:** `/privacy/` y `/support/` responden 200, sin redirects rotos, con correo/fecha reales; los enlaces se abren desde build Release.
- **Effort:** S
- **Regression risk:** Low
- **How to validate:** `curl -fsSIL` a ambas URLs, revisión móvil y toque desde Ajustes/TestFlight.

### CASI-102 — El arnés de captura volvió eager el detalle histórico real

- **ID:** CASI-102
- **Severity:** High
- **Confidence:** Verificado
- **Category:** Performance / Architecture
- **Screen/Component:** Detalle de Historial
- **Title:** `LazyVStack` fue reemplazado por `VStack` para beneficiar `ImageRenderer`
- **File:** `CasiListo/Views/ShoppingHistoryDetailView.swift`
- **Lines:** 44–78
- **Evidence:** El diff local cambia explícitamente el contenedor lazy por uno eager y el comentario cita el renderizado total para ImageRenderer.
- **Observed behavior:** Abrir una compra construye todas sus categorías y filas, aunque estén fuera del viewport.
- **Expected experience:** La pantalla de producción virtualiza contenido largo; el arnés no condiciona arquitectura runtime.
- **User impact:** Mayor tiempo de apertura, memoria y riesgo de jank con compras grandes.
- **Release impact:** Regresión de performance en el worktree candidato.
- **Recommended improvement:** Restaurar `LazyVStack` en producción y crear un renderer/test adapter separado, excluido del app target.
- **Acceptance criteria:** Historial usa layout lazy en la app; la captura no requiere cambiar la vista real; Time Profiler con 1.000 filas no muestra hitch >100 ms atribuible a construcción total.
- **Effort:** M
- **Regression risk:** Medium
- **How to validate:** Diff de target membership, UI test, scroll largo e Instruments Release en dispositivo.

### CASI-103 — La cola del widget se elimina antes de confirmar persistencia

- **ID:** CASI-103
- **Severity:** High
- **Confidence:** Verificado en código; reproducción de fallo Needs Runtime Verification
- **Category:** Data Integrity / Widget
- **Screen/Component:** Widget interactivo → app activa
- **Title:** Una compra marcada desde el widget puede perderse silenciosamente
- **File:** `CasiListoShared/WidgetContract.swift`; `CasiListo/Services/ShoppingPersistenceCoordinator.swift`; `CasiListo/Views/MainTabView.swift`
- **Lines:** 96–103; 175–183; 131–135
- **Evidence:** `drain` borra la clave antes de fetch/commit; `commit` puede lanzar; la llamada superior usa `try?` y no reencola.
- **Observed behavior:** En un fallo, el snapshot optimista cambia, la base no y la acción deja de existir.
- **Expected experience:** La acción se elimina solo tras commit o se restaura/reintenta de forma acotada.
- **User impact:** Un producto puede reaparecer pendiente sin explicación.
- **Release impact:** Riesgo de confianza y consistencia en una función publicitada.
- **Recommended improvement:** Implementar `peek` + `ack`, o reencolar IDs válidos en el `catch`; registrar el fallo y republicar fuente de verdad.
- **Acceptance criteria:** Test con ModelContext/commit fallido conserva la cola; reintento exitoso aplica una sola vez; IDs obsoletos se descartan de forma explícita.
- **Effort:** M
- **Regression risk:** Medium
- **How to validate:** Test unitario de save failure, prueba de widget/app y refresh posterior.

### CASI-104 — Evidencia firmada y física del release incompleta

- **ID:** CASI-104
- **Severity:** High
- **Confidence:** Needs Runtime Verification
- **Category:** Release Engineering / App Store
- **Screen/Component:** Binario completo
- **Title:** No existe evidencia de que el artefacto exacto complete distribución y uso físico
- **File:** `docs/VALIDACION_LANZAMIENTO.md`; `.github/workflows/release-testflight.yml`
- **Lines:** 21–82; 1–108
- **Evidence:** La checklist está sin marcar; esta auditoría solo pudo hacer build Release sin firma y simulador iOS 27.
- **Observed behavior:** Archive, IPA, TestFlight, iOS 26, App Group firmado, cámara/micrófono/widget físico no están confirmados.
- **Expected experience:** El mismo commit y build number pasan pipeline firmado y smoke test físico.
- **User impact:** Potenciales fallos solo visibles en distribución, permisos o extensión.
- **Release impact:** Gate operativo pendiente; no implica que el código esté roto.
- **Recommended improvement:** Ejecutar workflow de release con secretos reales y checklist de dispositivo.
- **Acceptance criteria:** Archive/export/upload exitosos, procesamiento TestFlight completo, smoke test iOS 26 y físico firmado.
- **Effort:** M
- **Regression risk:** Low
- **How to validate:** Artefactos CI, Organizer Privacy Report, TestFlight y checklist firmada.

## 32. Medium Findings

### CASI-105 — Lista vacía y ausencia de snapshot son indistinguibles en widget

- **ID:** CASI-105
- **Severity:** Medium
- **Confidence:** Verificado
- **Category:** Widget / Empty State
- **Screen/Component:** Widget small, medium y accessory
- **Title:** Un snapshot real vacío se trata como placeholder
- **File:** `CasiListoShared/WidgetContract.swift`; `CasiListoWidget/CasiListoWidget.swift`
- **Lines:** 43–49; 61–69, 118–132, 215–244
- **Evidence:** `isPlaceholder` solo comprueba cero contadores/ítems; `.empty` comparte exactamente esos valores.
- **Observed behavior:** Tras terminar o vaciar la lista, el widget dice “Abre CasiListo para empezar”.
- **Expected experience:** Primer uso muestra onboarding; lista real vacía muestra “Lista vacía” o “Todo listo”.
- **User impact:** Estado incorrecto y confuso.
- **Release impact:** Baja la calidad de una superficie visible del sistema.
- **Recommended improvement:** Añadir estado/version de snapshot (`hasPublishedSnapshot` o enum codificable) con compatibilidad de decoding.
- **Acceptance criteria:** Tests cubren nunca abierto, vacío real, pendientes y comprados; copy correcto en todas las familias.
- **Effort:** S
- **Regression risk:** Low
- **How to validate:** Unit tests y previews/widget físico tras vaciar lista.

### CASI-106 — El arnés full-length produce evidencia inválida

- **ID:** CASI-106
- **Severity:** Medium
- **Confidence:** Verificado
- **Category:** Testing / Visual QA
- **Screen/Component:** Capturas full-length
- **Title:** Dark es idéntico a light y “catálogo completo” está truncado
- **File:** `CasiListoTests/FullLengthScreenshotTests.swift`; `CasiListo/Views/Components/FullLengthViews.swift`
- **Lines:** 86–125; 144–289
- **Evidence:** Los cinco pares claro/oscuro tienen SHA-256 idéntico; `groupedCatalog` usa `prefix(6)`; la imagen de catálogo generada presenta composición inválida.
- **Observed behavior:** El arnés puede dar una falsa aprobación visual.
- **Expected experience:** Cada variante refleja traits reales y el nombre describe su contenido.
- **User impact:** Indirecto: defectos de apariencia podrían llegar a producción.
- **Release impact:** Reduce confianza de QA; no demuestra fallo del Dark Mode real.
- **Recommended improvement:** Priorizar UI screenshots reales; añadir asserts de hashes distintos/traits y no llamar “completo” a contenido truncado.
- **Acceptance criteria:** Dark/light difieren, colores se resuelven con traits correctos, catálogo no se invierte y el alcance queda documentado.
- **Effort:** M
- **Regression risk:** Low
- **How to validate:** Hash, inspección de PNG y comparación con screenshot real de simulator.

### CASI-107 — Importación y exportación trabajan síncronamente en MainActor

- **ID:** CASI-107
- **Severity:** Medium
- **Confidence:** Needs Runtime Verification
- **Category:** Performance / Responsiveness
- **Screen/Component:** Ajustes → Datos locales
- **Title:** Respaldos grandes pueden bloquear la interfaz sin progreso
- **File:** `CasiListo/Views/SettingsView.swift`; `CasiListo/Services/DataExportService.swift`
- **Lines:** 186–225; 95–177, 247–469
- **Evidence:** `Data(contentsOf:)`, múltiples fetches, JSON encode/decode y escritura se llaman desde un servicio `@MainActor` sin `isLoading`.
- **Observed behavior:** No medido con archivo grande; el camino es síncrono por diseño.
- **Expected experience:** Lectura/codec/I/O fuera del main actor, mutación SwiftData acotada y progreso/cancelación razonable.
- **User impact:** Posible congelamiento perceptible con años de historial.
- **Release impact:** Riesgo medio; requiere perfil antes de decidir refactor.
- **Recommended improvement:** Medir primero; si supera 100 ms, separar DTO/codec/I/O en tarea no aislada y mantener ModelContext en MainActor.
- **Acceptance criteria:** 5.000 ítems no bloquean interacción >100 ms en Release/dispositivo; UI muestra estado durante importación.
- **Effort:** M
- **Regression risk:** Medium
- **How to validate:** Signposts + Time Profiler y archivo de estrés real.

### CASI-108 — Dynamic Type rompe layouts en iPhone compacto

- **ID:** CASI-108
- **Severity:** Medium
- **Confidence:** Verificado
- **Category:** Accessibility / QA
- **Screen/Component:** Primer uso, detalle de compra, Plantillas y Catálogo
- **Title:** Accessibility XXL produce truncamiento severo y contenido ilegible
- **File:** `CasiListoUITests/ScreenshotCaptureTests.swift`; `ci/capture-screenshots.sh`; `docs/VALIDACION_LANZAMIENTO.md`
- **Lines:** 38, 181–240; 45–49; 75–82
- **Evidence:** La UI test pasó en iPhone 17e/iOS 27 con `UICTContentSizeCategoryAccessibilityXXL` y generó seis capturas. En ellas, textos se extienden bajo el tab bar, títulos/acciones aparecen elididos y las filas del catálogo colapsan a columnas de pocas letras. `--full` todavía no cubre AX5.
- **Observed behavior:** Las acciones automatizadas siguen funcionando, pero la información y los controles no conservan una presentación comprensible en el tamaño probado.
- **Expected experience:** Flujo completo accionable y sin truncamiento en la matriz declarada.
- **User impact:** Una persona que necesita texto grande no puede leer ni operar con confianza varias tareas centrales.
- **Release impact:** Defecto de accesibilidad confirmado; además impide declarar soporte accesible con confianza.
- **Recommended improvement:** Sustituir composiciones horizontales rígidas por layouts adaptativos, permitir crecimiento vertical y mantener acciones esenciales visibles; después añadir AX5 al arnés y ejecutar VoiceOver/Voice Control/Switch Control.
- **Acceptance criteria:** Checklist completa, sin botones truncados ni foco perdido; labels de App Store solo tras aprobar tareas comunes.
- **Effort:** M
- **Regression risk:** Low
- **How to validate:** Dispositivo/simulador con settings reales y Accessibility Inspector.

### CASI-109 — Archivar usa semántica destructiva

- **ID:** CASI-109
- **Severity:** Medium
- **Confidence:** Verificado
- **Category:** Interaction / Semantics
- **Screen/Component:** Compra → Archivar comprados
- **Title:** La acción de conservar en historial aparece como eliminación
- **File:** `CasiListo/Views/ShoppingListDetailView.swift`
- **Lines:** 101–125
- **Evidence:** El botón “Archivar … comprados” lleva `role: .destructive`; el mensaje dice que mueve al historial.
- **Observed behavior:** iOS lo presenta con énfasis destructivo.
- **Expected experience:** Rol normal para archivar; rojo reservado a borrar.
- **User impact:** Duda y temor a perder datos.
- **Release impact:** Degrada confianza en el flujo de cierre.
- **Recommended improvement:** Quitar rol destructivo; mantener confirmación informativa si aporta valor.
- **Acceptance criteria:** Archivar usa estilo normal en claro/oscuro y VoiceOver no lo anuncia como destructivo.
- **Effort:** XS
- **Regression risk:** Low
- **How to validate:** Captura del dialog y recorrido VoiceOver.

### CASI-110 — Crear lista tiene dos CTAs simultáneos

- **ID:** CASI-110
- **Severity:** Medium
- **Confidence:** Verificado visualmente
- **Category:** Visual Hierarchy / UX
- **Screen/Component:** Mis Listas con contenido
- **Title:** Toolbar `+` y botón “Nueva” compiten por la misma acción
- **File:** `CasiListo/Views/ListsOverviewView.swift`
- **Lines:** 75–85, 125–155
- **Evidence:** Ambos controles son visibles en la captura `listas-una.png` y abren `createList`.
- **Observed behavior:** Dos focos primarios en la misma ventana.
- **Expected experience:** Un CTA primario; el resumen se dedica a estado o navegación distinta.
- **User impact:** Ruido visual y menor claridad jerárquica.
- **Release impact:** Polish, no bloqueo funcional.
- **Recommended improvement:** Conservar el `+` nativo o el CTA de tarjeta, no ambos; validar descubribilidad.
- **Acceptance criteria:** Una sola acción primaria visible y estado-resumen conserva balance.
- **Effort:** XS
- **Regression risk:** Low
- **How to validate:** Capturas con una y varias listas y test de creación.

### CASI-111 — Ajustes prioriza documentación sobre tareas

- **ID:** CASI-111
- **Severity:** Medium
- **Confidence:** Verificado visualmente
- **Category:** Information Architecture
- **Screen/Component:** Ajustes
- **Title:** La guía duplicada ocupa casi todo el primer viewport
- **File:** `CasiListo/Views/SettingsView.swift`; `CasiListo/Views/Components/GestureGuideRows.swift`
- **Lines:** 107–123; 14–39
- **Evidence:** La guía es siempre la primera sección y repite cuatro instrucciones del onboarding.
- **Observed behavior:** Categorías, privacidad, soporte y respaldo quedan después de una tarjeta educativa extensa.
- **Expected experience:** Ajustes prioriza controles/tareas; ayuda queda al final o en sección colapsable.
- **User impact:** Más scroll para respaldo, soporte y borrado.
- **Release impact:** Polish y eficiencia de uso.
- **Recommended improvement:** Mover la guía al final o abrirla desde una fila “Cómo usar CasiListo”.
- **Acceptance criteria:** Privacidad/datos aparecen antes; onboarding sigue accesible bajo demanda.
- **Effort:** S
- **Regression risk:** Low
- **How to validate:** Capturas default/AX5 y prueba de localización de respaldo con usuarios.

### CASI-112 — Resumen legal sobrepromete el respaldo JSON

- **ID:** CASI-112
- **Severity:** Medium
- **Confidence:** Verificado
- **Category:** Privacy Copy / Data Portability
- **Screen/Component:** Sitio de privacidad
- **Title:** “Exportar todo en JSON” contradice la exclusión de fotos y audio
- **File:** `privacy-site/src/privacy.html`; `CasiListo/Services/DataExportService.swift`
- **Lines:** 58–67, 196–204; 4–10
- **Evidence:** El resumen usa “todo”; el servicio y la UI confirman que blobs no viajan.
- **Observed behavior:** Un usuario puede esperar una copia completa recuperable.
- **Expected experience:** Copy preciso: “exportar listas, historial, categorías y catálogo”; indicar que multimedia depende del respaldo del dispositivo.
- **User impact:** Expectativa equivocada al migrar o desinstalar.
- **Release impact:** Debe corregirse antes de publicar la política.
- **Recommended improvement:** Reescribir el bullet y FAQ; mantener consistencia con confirmación dentro de la app.
- **Acceptance criteria:** Ninguna página llama “completo/todo” al JSON sin la exclusión inmediata.
- **Effort:** XS
- **Regression risk:** Low
- **How to validate:** Test del sitio y revisión legal/editorial final.

## 33. Low Findings

### CASI-113 — Pluralización técnica en mensajes visibles

- **ID:** CASI-113
- **Severity:** Low
- **Confidence:** Verificado
- **Category:** Copy / Polish
- **Screen/Component:** Ajustes → Restaurar respaldo
- **Title:** La UI muestra “lista(s)” y “producto(s)”
- **File:** `CasiListo/Views/SettingsView.swift`
- **Lines:** 228–243
- **Evidence:** Strings interpolados usan sufijo `(s)`.
- **Observed behavior:** Copy correcto pero mecánico.
- **Expected experience:** Singular/plural natural en español.
- **User impact:** Sensación menos cuidada.
- **Release impact:** Bajo.
- **Recommended improvement:** Helpers de pluralización para cada contador.
- **Acceptance criteria:** Mensajes naturales para 0, 1 y varios.
- **Effort:** XS
- **Regression risk:** Low
- **How to validate:** Unit tests de mensajes o previews.

### CASI-114 — README contradice el CI actual

- **ID:** CASI-114
- **Severity:** Low
- **Confidence:** Verificado
- **Category:** Documentation / Maintenance
- **Screen/Component:** Repositorio
- **Title:** La documentación afirma que no hay SwiftLint ni gate de CI
- **File:** `README.md`; `.github/workflows/ios.yml`
- **Lines:** 224–232; 25–44
- **Evidence:** README dice “no hay SwiftLint”; el workflow instala 0.65.1 y ejecuta lint.
- **Observed behavior:** Instrucción de mantenimiento obsoleta.
- **Expected experience:** README describe el pipeline real.
- **User impact:** Ninguno directo.
- **Release impact:** Bajo; aumenta confusión del equipo.
- **Recommended improvement:** Actualizar el párrafo y conservar el límite de archivo como aspiracional.
- **Acceptance criteria:** Documentación coincide con workflow actual.
- **Effort:** XS
- **Regression risk:** Low
- **How to validate:** Revisión cruzada README/CI.

## 34. Prioritized Release Plan

### P0 — antes de cualquier submission

1. Desplegar privacidad/soporte y verificar HTTPS, contenido y enlaces desde Release.
2. Retirar el acoplamiento full-length del app target; restaurar historial lazy.
3. Hacer durable la cola del widget y corregir snapshot vacío, con pruebas.
4. Corregir copy “exportar todo” y rol destructivo de Archivar.

### P1 — release candidate

5. Ejecutar tests + build desde worktree limpio y producir `.xcresult` válido.
6. Probar iOS 26 real, iPhone compacto, Pro Max y AX5.
7. Completar VoiceOver, Voice Control, Switch Control y ajustes de visión.
8. Medir historia/import/export/lista larga con Instruments en Release.
9. Ejecutar Archive firmado, Privacy Report, export IPA y TestFlight.

### P2 — ficha y polish final

10. Resolver jerarquía de Ajustes, CTA duplicado y pluralización.
11. Preparar capturas App Store con datos realistas y sin estados de fixture confusos.
12. Completar metadata, App Privacy, Accessibility Labels y Review Notes.

## 35. Manual Release Checklist

### Infraestructura y legal

- [ ] `https://casilisto-privacy.pages.dev/privacy/` responde 200.
- [ ] `https://casilisto-privacy.pages.dev/support/` responde 200.
- [ ] Correo y fechas son reales; copy JSON no promete multimedia.
- [ ] Enlaces se abren desde build TestFlight.

### Build y distribución

- [x] Build Release sin firma pasa con Xcode 27/SDK 27.
- [x] Manifiestos app/widget son válidos y están en el bundle.
- [ ] Worktree candidato está limpio, etiquetado y con build number único.
- [ ] Archive firmado pasa Validate App.
- [ ] App Group app/widget coincide en firma y provisioning.
- [ ] Organizer Privacy Report no muestra APIs/SDKs inesperados.
- [ ] IPA exporta, sube y procesa en TestFlight.

### Función y datos

- [x] 208 pruebas unitarias pasan en iOS 27.
- [ ] UI suite termina con `.xcresult` válido.
- [ ] Instalar/actualizar desde versión anterior conserva store y archivos.
- [ ] Crear, editar, duplicar y borrar listas.
- [ ] Añadir rápido, editar, marcar, posponer, no encontrado, borrar y undo.
- [ ] Cerrar compra con y sin boleta; revisar totales por tienda.
- [ ] Exportar/importar JSON real; abrir CSV en Numbers, Excel y Sheets.
- [ ] Simular fallo de persistencia al aplicar acción del widget.

### Dispositivos, accesibilidad y apariencia

- [ ] iOS 26.0 real.
- [x] Primer uso, plantillas y catálogo capturados en iPhone 17e con Accessibility XXL; **fallan visualmente**.
- [ ] Revalidar iPhone compacto tras corregir CASI-108; ejecutar iPhone 17 Pro y Pro Max.
- [x] 20 rutas claro + 20 oscuro revisadas en iPhone 17 Pro/iOS 27.
- [ ] AX5 máximo sin truncamiento ni controles fuera de pantalla.
- [ ] VoiceOver completa tareas comunes.
- [ ] Voice Control y Switch Control accionan controles.
- [ ] Reducir movimiento, transparencia y aumentar contraste.
- [ ] Interrupción por llamada, Bluetooth y auriculares durante audio.

### Hardware y extensiones

- [ ] Cámara denegada/permitida/revocada y fallback a Fotos.
- [ ] Boletas reales Jumbo/Líder con distintas luces y formatos.
- [ ] Micrófono denegado/permitido/revocado y límite de 30 s.
- [ ] Widget small/medium/Lock Screen: nunca abierto, vacío, pendiente y comprado.
- [ ] Deep link con app cerrada/abierta y URL desconocida.

### App Store Connect

- [ ] Bundle ID y app creados.
- [ ] Descripción, subtítulo, keywords, categorías y Review Notes.
- [ ] Privacy URL y Support URL registradas y públicas.
- [ ] App Privacy coincide con binario y política.
- [ ] Accessibility Nutrition Labels solo para funciones validadas.
- [ ] Screenshots actuales, sin datos personales ni UI engañosa.
- [ ] Age rating, copyright, contacto y disponibilidad territorial.

## 36. Final Recommendation

**No publicar la compilación actual.** La interfaz y el dominio funcional están suficientemente maduros; el trabajo restante es acotado y medible. El release puede pasar a **FINAL POLISH** cuando el dominio legal esté en línea, Dynamic Type compacto sea legible, el arnés deje de afectar producción y el widget conserve acciones ante fallos. Puede pasar a **READY** después de un release candidate firmado que complete iOS 26, hardware, accesibilidad, Instruments y TestFlight sin hallazgos nuevos.

No se recomienda rediseñar la app ni añadir funciones. La mayor ganancia viene de preservar la calidad ya lograda y cerrar la evidencia que Apple y un usuario real necesitan.

---

CASILISTO RELEASE REPORT
Verdict: NOT READY
Score: 76/100
Chilean Grade: 5.2/7.0
Would Ship: NO
Critical Findings: 0
High Findings: 4
Medium Findings: 8
Low Findings: 2
Release Blockers: 3
Primary Blocker: Privacy and support URLs do not resolve publicly
Required Next State: Publish legal pages, fix compact Dynamic Type, isolate screenshot harness, harden widget durability, and validate signed RC on iOS 26 and physical hardware
