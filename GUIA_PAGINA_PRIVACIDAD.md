# Guía para construir la página de política de privacidad de CasiListo

Documento de referencia único para escribir, diseñar y publicar la página de política de
privacidad (y la de soporte) de **CasiListo**. Reúne tres cosas que hoy están repartidas por el
repo: los **tokens de diseño** de la app, los **hechos verificables** sobre qué datos maneja la app
—que son los que la política puede afirmar sin mentir— y el **pipeline de publicación** que ya
existe.

Última verificación contra el código: **13 de septiembre de 2026** (commit `a0b65fa`).

---

## 1. Estado actual: la página ya existe

No se parte de cero. Hay un sitio estático versionado en [privacy-site/](privacy-site/) que se
publica solo en Cloudflare Pages.

| Pieza | Ruta | Nota |
|---|---|---|
| Plantilla de privacidad | [privacy-site/src/privacy.html](privacy-site/src/privacy.html) | HTML plano con placeholders |
| Plantilla de soporte | [privacy-site/src/support.html](privacy-site/src/support.html) | Enlazada desde la de privacidad |
| Hoja de estilos | [privacy-site/src/assets/site.css](privacy-site/src/assets/site.css) | 12 líneas, sin build de CSS |
| Build | [privacy-site/scripts/build.mjs](privacy-site/scripts/build.mjs) | Node puro, sin dependencias ni lockfile |
| Deploy | [.github/workflows/deploy-privacy.yml](.github/workflows/deploy-privacy.yml) | Push a `main` tocando `privacy-site/**`, o `workflow_dispatch` |

**URLs en producción** (las declara [AppSupportLinks.swift](CasiListo/Services/AppSupportLinks.swift)):

- `https://casilisto.lat/privacy/`
- `https://casilisto.lat/support/`

> ⚠️ Estas URLs están **hardcodeadas en el binario**: la pestaña Ajustes las abre con `Link`
> ([SettingsView.swift:63-75](CasiListo/Views/SettingsView.swift#L63-L75)). Cambiar de dominio
> obliga a editar `AppSupportLinks.swift`, **publicar una versión nueva de la app** y actualizar las
> URLs en App Store Connect. Si se migra a dominio propio, dejar redirección permanente desde
> `pages.dev` o las builds ya instaladas quedan con enlaces muertos.

### Cómo se construye

```bash
cd privacy-site
PUBLIC_SUPPORT_EMAIL="soporte@ejemplo.cl" \
PUBLIC_POLICY_EFFECTIVE_DATE="12 de agosto de 2026" \
npm run build      # genera dist/privacy/index.html y dist/support/index.html
```

- `npm run build` es el **único** script; no hay dependencias, `node_modules` ni lockfile.
- El build **falla a propósito** si `PUBLIC_SUPPORT_EMAIL` no está definido o no tiene forma de
  correo: la decisión fue no publicar jamás un correo de soporte ficticio.
- `PUBLIC_POLICY_EFFECTIVE_DATE` es opcional; su default es `"12 de agosto de 2026"`.
- Placeholders disponibles en las plantillas: `{{SUPPORT_EMAIL}}` y `{{EFFECTIVE_DATE}}`. Se
  reemplazan con `replaceAll`, así que se pueden usar varias veces por archivo.
- `dist/` se regenera desde cero (`rmSync`) en cada corrida y no está versionado.
- Rutas finales: cada página se emite como `<page>/index.html`, por eso las URLs llevan slash final
  (`/privacy/`, no `/privacy.html`). Los enlaces internos deben escribirse con esa forma.
- En CI, `PUBLIC_*` son **variables** de repositorio y `CLOUDFLARE_*` son **secretos**; el proyecto
  de Cloudflare Pages se llama `casilisto-privacy`.

---

## 2. Identidad de la app

| Dato | Valor |
|---|---|
| Nombre | CasiListo |
| Lema | «Casi listo para ir al súper.» |
| Bundle ID app | `com.allopze.CasiListo` |
| Bundle ID widget | `com.allopze.CasiListo.widget` |
| App Group | `group.com.allopze.CasiListo` |
| Esquema de URL | `casilisto://` |
| Versión | `MARKETING_VERSION = 1.0` |
| Plataforma | iOS 26.0 o superior, **solo iPhone** (`TARGETED_DEVICE_FAMILY = 1`) |
| Idioma | **Solo español (es-CL)**. Cero infraestructura de localización en la app; el sitio usa `lang="es-CL"` |
| Desarrollador | Alejandro López Zelaya |
| Dedicatoria (pie de Ajustes) | «Desarrollado por Alejandro López Zelaya para su querido padre, Casimiro López Díaz. Ojalá esta lista te acompañe por siempre.» |
| Logo | [CasiListo/Assets.xcassets/AppLogo.imageset/logo.png](CasiListo/Assets.xcassets/AppLogo.imageset/logo.png) |
| Ícono | [CasiListo/Assets.xcassets/AppIcon.appiconset/appicon-color.png](CasiListo/Assets.xcassets/AppIcon.appiconset/appicon-color.png) (1024×1024) + variante `appicon-tinted.png` |

**Tono de voz de la app**: en la interfaz se tutea («tus listas», «Borrar todos mis datos»). La
página de privacidad actual **usa «usted»**. Es una inconsistencia real: decidir una sola forma y
aplicarla a las dos páginas. Recomendación: tutear, para que la web suene como la app.

---

## 3. Tokens de diseño

Fuente única: [CasiListo/Theme/Theme.swift](CasiListo/Theme/Theme.swift) y la extensión `Color` al
final del mismo archivo. **Nada de literales de color fuera de ahí** es la regla en la app; la web
debería reflejar los mismos valores.

### 3.1 Colores de marca y superficie

| Token (app) | Claro | Oscuro | Uso |
|---|---|---|---|
| `Theme.accentYellow` | `#F5C518` | `#F5C518` | **Rellena**: fondos de botón, chips, acentos sólidos. Nunca texto sobre claro |
| `Theme.onAccent` | `#1A1A1A` | `#1A1A1A` | Tinta sobre el amarillo (10.7:1) |
| `Theme.accentInteractive` | `#8A6A00` | `#F5C518` | **Escribe**: texto y enlaces de acento |
| `Color.appBackground` | `#F5F1EB` | `#1C1B1A` | Fondo de página (crema cálido) |
| `Color.appCardBackground` | `#FFFFFF` | `#2A2928` | Tarjetas |
| `Color.appTextPrimary` | `#1A1A1A` | `#F5F5F5` | Texto principal |
| `Color.appTextSecondary` | `#6E6E6E` | `#A0A0A0` | Texto secundario / pie |
| `Color.appTextPurchased` | `#8A8680` | `#A8A8A8` | Texto atenuado (ítems comprados) |
| `Color.appSeparator` | `#EAE5DD` | `#3A3938` | Separadores |
| `AccentColor` (asset) | `#8A6A00` | `#F5C518` | Tinte del sistema; coincide con `accentInteractive` |

**La regla de oro del color, y por qué existe**: `accentYellow` rellena, `accentInteractive`
escribe. El amarillo de marca rinde **1.45:1 sobre el crema** y **1.63:1 sobre tarjeta blanca** —
como color de texto es ilegible. El oro `#8A6A00` rinde **4.52:1 sobre el crema** y **5.09:1 sobre
blanco** (AA para texto normal); en modo oscuro se recupera el amarillo, que ahí da **10.6:1**. En
la app esto lo fija el test `testAccentTokensMeetContrastOnLightSurfaces`; en la web no hay test que
lo proteja, así que hay que respetarlo a mano.

**Divergencia actual a resolver**: [site.css](privacy-site/src/assets/site.css) usa `#faf8f5` de
fondo (la app usa `#F5F1EB`), `#6b5200` para enlaces (la app usa `#8A6A00`) y `#806000` para el
eyebrow. Son valores cercanos pero no los tokens. Alinearlos es un cambio de una línea y hace que la
web se lea como la app.

### 3.2 Paleta secundaria (personalización de listas)

De [ListAppearanceCatalog.swift](CasiListo/Models/ListAppearanceCatalog.swift). Útil si la página
quiere ilustraciones o acentos que no sean solo amarillo:

`#F5C518` Amarillo CasiListo · `#FF9500` Naranja Cálido · `#FF5722` Coral Intenso ·
`#E53935` Rojo Frambuesa · `#E91E63` Rosa Fucsia · `#9C27B0` Violeta Mágico ·
`#5C6BC0` Índigo Profundo · `#2196F3` Azul Océano · `#00BCD4` Turquesa Caribe ·
`#4CAF50` Verde Esmeralda · `#00C853` Menta Fresco · `#795548` Café Tierra

Ninguno de estos colores cumple contraste como texto sobre crema salvo los oscuros. Usarlos solo
como relleno, y elegir la tinta con la misma lógica que `Theme.foreground(on:)`: blanco o `#1A1A1A`,
el que dé mayor razón de contraste.

### 3.3 Tipografía

La app usa **SF Rounded** vía `.system(design: .rounded)` con Dynamic Type. En web no hay SF Rounded
disponible como webfont del sistema; la aproximación fiel sin cargar fuentes externas es la pila
`-apple-system` (que en Safari/iOS resuelve a SF Pro) tal como ya hace el sitio. Si se quisiera el
redondeado, habría que empaquetar una fuente (p. ej. Nunito o Quicksand) — **decisión abierta**, hoy
el sitio no carga ninguna.

| Token de la app | Equivalente sugerido en web |
|---|---|
| `titleDynamic` — largeTitle rounded bold | `h1`, `clamp(2rem, 6vw, 3rem)`, weight 700 |
| `sectionHeaderDynamic` — title3 rounded bold | `h2`, ~1.35rem, weight 700 |
| `headlineDynamic` — headline rounded bold | `h3` / destacados |
| `bodyDynamic` — body rounded | `body`, 1rem, line-height 1.6 |
| `bodyBoldDynamic` — body rounded semibold | `strong`, weight 600 |
| `captionDynamic` — caption rounded | `footer`, `.9rem` |
| `chipDynamic` — caption rounded medium | `.eyebrow`, `.8rem`, uppercase, tracking `.08em` |

En la app **nunca hay tamaños fijos**: todo es Dynamic Type. El equivalente web es no fijar `px` en
texto y respetar el zoom; usar `rem` y `clamp()`.

### 3.4 Métricas, formas y movimiento

| Token | Valor | Traducción a web |
|---|---|---|
| `Theme.cornerRadius` | 20 pt | `border-radius: 20px` en tarjetas grandes |
| `Theme.smallCornerRadius` | 16 pt | Tarjetas pequeñas |
| `Theme.controlCornerRadius` / `chipCornerRadius` | 999 (cápsula) | `border-radius: 999px` en botones y chips |
| `Theme.cardPadding` | 16 pt | `padding: 16px` |
| `Theme.itemSpacing` | 12 pt | Separación entre elementos |
| `Theme.sectionSpacing` | 24 pt | Separación entre secciones |
| `Theme.minimumTouchTarget` | 44 pt | `min-height: 44px` en cualquier cosa tocable |
| `Theme.defaultAnimation` | `spring(response: 0.35, dampingFraction: 0.75)` | `cubic-bezier` suave, ~350 ms |
| `Theme.quickAnimation` | `easeOut 0.2 s` | `transition: .2s ease-out` |

La app honra **Reduce Motion** pasando `nil` como animación. El equivalente obligatorio en web:
`@media (prefers-reduced-motion: reduce) { * { animation: none; transition: none; } }`. El sitio
actual no lo declara.

El sitio actual sí declara `color-scheme: light dark` y un bloque
`@media (prefers-color-scheme: dark)` — mantenerlo: la app sigue la apariencia del sistema y la web
debe hacer lo mismo.

### 3.5 Bloque CSS listo para pegar

Reemplaza los literales sueltos de `site.css` por variables con los valores reales de la app:

```css
:root {
  color-scheme: light dark;

  /* Marca */
  --cl-accent-fill: #F5C518;       /* rellena */
  --cl-accent-ink: #1A1A1A;        /* tinta sobre el relleno — 10.7:1 */
  --cl-accent-text: #8A6A00;       /* escribe — 4.52:1 sobre crema */

  /* Superficies */
  --cl-bg: #F5F1EB;
  --cl-card: #FFFFFF;
  --cl-separator: #EAE5DD;

  /* Texto */
  --cl-text: #1A1A1A;
  --cl-text-secondary: #6E6E6E;    /* 4.8:1 sobre crema */

  /* Forma */
  --cl-radius-card: 20px;
  --cl-radius-small: 16px;
  --cl-radius-pill: 999px;
  --cl-pad-card: 16px;
  --cl-gap-item: 12px;
  --cl-gap-section: 24px;
  --cl-touch: 44px;

  /* Movimiento */
  --cl-ease-quick: .2s ease-out;

  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.6;
}

@media (prefers-color-scheme: dark) {
  :root {
    --cl-accent-text: #F5C518;     /* en oscuro el amarillo sí rinde: 10.6:1 */
    --cl-bg: #1C1B1A;
    --cl-card: #2A2928;
    --cl-separator: #3A3938;
    --cl-text: #F5F5F5;
    --cl-text-secondary: #A0A0A0;
  }
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; transition: none !important; }
}

body { margin: 0; background: var(--cl-bg); color: var(--cl-text); }
main { box-sizing: border-box; max-width: 760px; margin: 0 auto; padding: 48px 24px 72px; }
a { color: var(--cl-accent-text); font-weight: 650; }
.card {
  background: var(--cl-card);
  border-radius: var(--cl-radius-card);
  padding: var(--cl-pad-card);
  box-shadow: 0 4px 18px rgb(0 0 0 / .06);
}
.eyebrow {
  color: var(--cl-accent-text);
  font-weight: 700; text-transform: uppercase;
  letter-spacing: .08em; font-size: .8rem;
}
```

---

## 4. Hechos verificables sobre datos (la materia prima del texto legal)

Todo lo de esta sección está verificado contra el código en la fecha indicada arriba. **La política
no debe afirmar nada que no esté aquí.**

### 4.1 Arquitectura de datos: no hay servidor

- **Cero red**: no hay una sola aparición de `URLSession` en los targets de app, widget o shared.
- **Cero analítica, cero SDK de terceros**: el proyecto no tiene dependencias externas (ni SPM, ni
  CocoaPods, ni Carthage).
- **Cero tracking**: no hay `ATTrackingManager`, IDFA ni identificadores publicitarios.
- **Cero geolocalización**: `CoreLocation` fue eliminado del árbol por completo.
- Frameworks del sistema que sí se usan: SwiftUI, SwiftData, UIKit, WidgetKit, AppIntents,
  AVFoundation, Vision, VisionKit, PhotosUI, ImageIO, CoreGraphics, os.log.
- `ITSAppUsesNonExemptEncryption = false` en [CasiListo/Info.plist](CasiListo/Info.plist): no hay red
  ni criptografía propia.

**Traducción al texto legal**: el desarrollador no recibe, ve ni almacena ningún dato del usuario. No
hay cuenta, no hay login, no hay sincronización con iCloud (no se usa CloudKit). La copia de los
datos vive **solo en el dispositivo**.

### 4.2 Qué guarda la app, exactamente

**Base de datos SwiftData** — 4 modelos. Vive en el contenedor del App Group
`group.com.allopze.CasiListo` (consecuencia del entitlement, no de una configuración explícita):

| Modelo | Campos que puede contener datos escritos por la persona |
|---|---|
| `ShoppingItem` | nombre del producto, cantidad, nota libre, categoría, supermercado (Jumbo/Líder), estado, precio, nombre de archivo de nota de voz, fecha de creación |
| `ShoppingList` | título, fechas de creación y cierre, estado, supermercado, contadores, gasto total, nombre de archivo de boleta, ícono y color |
| `Category` | nombre, símbolo SF, orden, si es de sistema |
| `ProductCatalogItem` | nombre, categoría, supermercado, veces añadido, última vez añadido |

**Archivos (blobs)** — en el sandbox privado de la app, gestionados por
[LocalFileStore.swift](CasiListo/Services/LocalFileStore.swift):

| Contenido | Ruta | Formato |
|---|---|---|
| Fotos de boleta | `Application Support/Receipts/` | JPG |
| Notas de voz | `Documents/VoiceNotes/` | M4A (AAC), **máximo 30 segundos** por nota |
| Borradores de voz sin guardar | `Documents/VoiceNotes/.temporary/` | Se barren en cada arranque |

**`UserDefaults`** — preferencias de interfaz: lista activa seleccionada, categorías colapsadas por
lista, marcas de sembrado y de migraciones puntuales. Nada de esto identifica a una persona.

**Snapshot del widget** — en los `UserDefaults` del App Group, clave `widgetSnapshot`: JSON con el
conteo de pendientes y comprados, más los **primeros 5 productos pendientes** (id + nombre). Es el
único dato que cruza el límite del proceso de la app, y sigue dentro del dispositivo. Contrato en
[CasiListoShared/WidgetContract.swift](CasiListoShared/WidgetContract.swift).

### 4.3 Permisos: qué se pide, cuándo, y el texto exacto que ve el usuario

Los textos de permiso están en el pbxproj como `INFOPLIST_KEY_*`. **Cítalos literalmente en la
política**, porque son los que aparecen en el diálogo del sistema:

| Permiso | Texto declarado | Cuándo se pide |
|---|---|---|
| Cámara (`NSCameraUsageDescription`) | «CasiListo usa la cámara para fotografiar boletas y registrar productos y precios.» | Solo al elegir escanear una boleta |
| Micrófono (`NSMicrophoneUsageDescription`) | «CasiListo usa el micrófono para guardar notas de voz en productos de tu lista.» | Solo al iniciar una nota de voz |

**Fototeca**: la app **no declara `NSPhotoLibraryUsageDescription`**. Usa
`PHPickerViewController`, que corre fuera del proceso y entrega solo la imagen elegida sin dar acceso
a la biblioteca. Esto es una mejora real de privacidad y **vale la pena decirlo explícitamente** —
además, el texto actual de la página («La cámara y la fototeca se solicitan…») es impreciso y hay que
corregirlo: la fototeca no se solicita.

Denegar cualquiera de los dos permisos deja la app plenamente funcional, sin esa función concreta.

### 4.4 OCR de boletas: todo en el dispositivo

El reconocimiento de texto usa **Vision** (revisión 3) localmente, en un `Task.detached` fuera del
hilo principal. La imagen **no sale del dispositivo**. El flujo es: escaneo con VisionKit →
reconocimiento → parseo de montos → **revisión humana obligatoria** antes de registrar nada en el
historial. La foto se guarda como JPG asociada a la lista archivada y se borra con ella.

### 4.5 Exportación de datos (la página actual no lo menciona — debería)

Hay **dos** exportaciones, ambas iniciadas por la persona y entregadas a la hoja de compartir de iOS:

1. **Ajustes → «Exportar mis datos»** ([DataExportService.swift](CasiListo/Services/DataExportService.swift)):
   un **JSON** con nombre `CasiListo-AAAA-MM-DD-HHMM.json` que contiene categorías, listas, ítems y
   catálogo. **No incluye los archivos** de boleta ni de voz, solo sus nombres como referencia. Se
   escribe en el directorio temporal. Es un respaldo de lectura, no un formato de reimportación.
2. **Historial → exportar CSV** ([ShoppingHistoryView.swift:165-180](CasiListo/Views/ShoppingHistoryView.swift#L165-L180)):
   columnas `Fecha, Lista, Supermercado, Producto, Cantidad, Categoria, Estado, Precio`.

Punto importante para el texto: **desde el momento en que la persona comparte el archivo, el destino
lo decide ella** (Mail, Archivos, WhatsApp, etc.) y ese destino queda fuera del alcance de la app.
Conviene decirlo.

### 4.6 Borrado

**Ajustes → «Borrar todos mis datos guardados»**, con diálogo de confirmación cuyo texto literal es:

> «Se eliminarán tus listas, historial, categorías personalizadas, catálogo, fotos de boletas y notas
> de voz de este dispositivo. Esta acción no se puede deshacer.»

Lo que hace de verdad ([ShoppingPersistenceCoordinator.swift:195-232](CasiListo/Services/ShoppingPersistenceCoordinator.swift#L195-L232)):
borra los 4 modelos, los directorios `Receipts/` y `VoiceNotes/` completos, las preferencias de
interfaz, las marcas de sembrado, el snapshot del widget y la cola de acciones pendientes del widget;
luego vuelve a crear las categorías de sistema y a sembrar el catálogo sugerido, dejando la app como
recién instalada, **sin ninguna lista**.

> ⚠️ El texto actual de la web dice que «después se crea una lista local vacía». Es **incorrecto**:
> el reseteo no crea ninguna lista y la app queda en su estado de primer arranque. Corregirlo.

**Desinstalar la app** elimina el sandbox y el contenedor del App Group, es decir, todo. No queda
copia en ningún servidor porque nunca existió.

### 4.7 Manifiestos de privacidad y etiquetas de App Store

Los dos `PrivacyInfo.xcprivacy` ([app](CasiListo/PrivacyInfo.xcprivacy),
[widget](CasiListoWidget/PrivacyInfo.xcprivacy)) declaran:

- `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains` vacío.
- `NSPrivacyCollectedDataTypes` **vacío** — no se recolecta ningún tipo de dato.
- Única API de motivo requerido: `NSPrivacyAccessedAPICategoryUserDefaults`, con razones
  **`CA92.1` y `1C8F.1`** en la app y **`1C8F.1`** en el widget.

[ci/validate-privacy-manifests.sh](ci/validate-privacy-manifests.sh) verifica exactamente esos
valores en CI: cambiar un manifiesto sin actualizar el script rompe el build.

**La política de la web debe ser consistente con esto**: si el texto dijera que se recolecta algo, la
declaración de App Store Connect («No recolectamos datos de esta app») quedaría contradicha y es
motivo de rechazo.

---

## 5. Qué le falta a la página actual

Revisión de [privacy.html](privacy-site/src/privacy.html) contra el código de hoy:

| Hallazgo | Acción |
|---|---|
| Dice que «la fototeca se solicita» | **Incorrecto**: se usa `PHPickerViewController` sin permiso. Corregir y convertirlo en un punto a favor |
| No menciona la **exportación de datos** (JSON y CSV) | Añadir sección: qué contiene, que el destino lo elige la persona |
| No menciona que el **widget es interactivo** | Marcar comprado desde el widget encola el ID en el App Group y la app lo persiste al volver a primer plano. Sigue todo local, pero es un flujo de datos que conviene describir |
| No menciona el **deep link** `casilisto://` | Menor; se puede omitir o añadir una línea |
| Dice que tras el borrado «se crea una lista local vacía» | **Incorrecto**: el reseteo no crea ninguna lista. Ver §4.6 |
| Dice «esta política corresponde a CasiListo 1.0» | Verificar en cada release; si sube la versión, actualizar |
| Trata de «usted», la app tutea | Unificar (recomendado: tutear) |
| No hay sección de **menores de edad** | Añadir si App Store Connect asigna clasificación 4+ |
| No hay **jurisdicción ni titular responsable** | Falta el nombre/razón social y el país. Ver §7 |
| No hay **fecha de última actualización** visible aparte de la de vigencia | Añadir «Última actualización: …» |
| Sin `@media (prefers-reduced-motion)` ni tokens de la app en el CSS | Ver §3.5 |
| El build no emite un `index.html` en la raíz | `dist/` solo tiene `assets/`, `privacy/` y `support/`: la raíz del dominio responde 404. Añadir una portada mínima o una redirección a `/privacy/` |

---

## 6. Estructura recomendada de la página

Orden propuesto, cada sección con el respaldo factual de §4:

1. **Resumen en una tarjeta** (lo que ya hay): la app funciona con datos locales, sin tracking, sin
   analítica, sin venta de datos. Es la frase que más gente va a leer.
2. **Quién es el responsable** — nombre, país, correo de contacto.
3. **Qué guarda la app en tu dispositivo** — listas, productos, categorías, historial, precios,
   preferencias, y opcionalmente fotos de boleta y notas de voz.
4. **Dónde se guarda** — en el iPhone; la base en el contenedor del App Group para que el widget
   pueda mostrar el resumen; los archivos en el sandbox privado.
5. **Qué NO hace la app** — no hay cuenta, no hay servidor, no hay red, no hay publicidad, no hay
   identificadores de seguimiento, no hay ubicación, no hay SDK de terceros.
6. **Permisos** — cámara y micrófono, citando los textos literales; la fototeca sin permiso vía
   selector del sistema; se pueden revocar en Ajustes de iOS.
7. **Reconocimiento de boletas** — Vision en el dispositivo, revisión humana antes de registrar.
8. **El widget** — qué resumen recibe (conteos + 5 nombres) y por qué.
9. **Exportar tus datos** — JSON y CSV, iniciados por la persona, destino elegido por ella.
10. **Conservación y eliminación** — hasta que la persona borre; borrado total desde Ajustes;
    desinstalar elimina todo.
11. **Menores** — según la clasificación de edad declarada.
12. **Cambios a esta política** — cómo se avisan (la página se versiona con la app).
13. **Contacto** — `{{SUPPORT_EMAIL}}` + enlace a `/support/`.
14. **Pie** — versión de la app a la que corresponde y fecha de vigencia.

---

## 7. Decisiones pendientes (no están en el código, las tiene que tomar una persona)

1. **Correo de soporte real** → variable `PUBLIC_SUPPORT_EMAIL`. Sin esto el build falla, por diseño.
2. **Fecha de vigencia** → variable `PUBLIC_POLICY_EFFECTIVE_DATE`. El default codificado
   (`12 de agosto de 2026`) es un placeholder heredado.
3. **Titular responsable**: ¿persona natural (Alejandro López Zelaya) o razón social? La política
   necesita nombrar a alguien.
4. **Jurisdicción y marco legal aplicable**. La app está dirigida a Chile (supermercados Jumbo y
   Líder, precios en CLP). Conviene revisar con criterio legal qué normativa chilena de protección de
   datos citar y en qué estado de vigencia está a la fecha de publicación — **no dar por buena
   ninguna referencia legal sin verificarla contra fuente oficial**. Si la app se publica también en
   otras tiendas regionales, evaluar si hace falta mencionar GDPR/CCPA (aunque al no haber
   recolección de datos la exposición es mínima).
5. **Dominio propio** `casilisto.lat`. Si se migra nuevamente, recordar §1: es cambio de
   binario.
6. **Tipografía web**: mantener `-apple-system` o empaquetar una redondeada para acercarse a SF
   Rounded.

---

## 8. Checklist de publicación

```bash
# 1. Editar privacy-site/src/privacy.html (y support.html / site.css si aplica)

# 2. Build local para verificar
cd privacy-site
PUBLIC_SUPPORT_EMAIL="..." PUBLIC_POLICY_EFFECTIVE_DATE="..." npm run build
open dist/privacy/index.html

# 3. Commit con scope en español sin tildes (Conventional Commits)
#    docs(privacidad): ...

# 4. Push a main → deploy-privacy.yml publica solo si cambió privacy-site/**
#    (o dispararlo a mano desde la pestaña Actions: workflow_dispatch)
```

Antes de enviar a revisión de App Store:

- [ ] `https://casilisto.lat/privacy/` responde 200 y se ve bien en claro y oscuro.
- [ ] `https://casilisto.lat/support/` responde 200 y el enlace cruzado funciona.
- [ ] El correo de soporte del sitio es un buzón que alguien lee de verdad.
- [ ] Las dos URLs están registradas en App Store Connect (Privacy Policy URL y Support URL) y
      coinciden con [AppSupportLinks.swift](CasiListo/Services/AppSupportLinks.swift).
- [ ] App Privacy en App Store Connect: **Tracking = No**, **Data Collection = No recolectamos
      datos**; el texto de la web no contradice eso.
- [ ] `bash ci/validate-privacy-manifests.sh artifacts` pasa.
- [ ] La versión citada en el pie de la política coincide con `MARKETING_VERSION`.
- [ ] Probado con zoom al 200 % y con `prefers-reduced-motion` activo.

Referencia operativa complementaria: [docs/VALIDACION_LANZAMIENTO.md](docs/VALIDACION_LANZAMIENTO.md)
(secretos y variables de CI, checklist manual de lanzamiento).

---

## 9. Índice de archivos citados

| Tema | Archivo |
|---|---|
| Tokens de diseño | [CasiListo/Theme/Theme.swift](CasiListo/Theme/Theme.swift) |
| Paleta de listas | [CasiListo/Models/ListAppearanceCatalog.swift](CasiListo/Models/ListAppearanceCatalog.swift) |
| URLs de privacidad y soporte | [CasiListo/Services/AppSupportLinks.swift](CasiListo/Services/AppSupportLinks.swift) |
| Pantalla de Ajustes (borrado y exportación) | [CasiListo/Views/SettingsView.swift](CasiListo/Views/SettingsView.swift) |
| Exportación JSON | [CasiListo/Services/DataExportService.swift](CasiListo/Services/DataExportService.swift) |
| Exportación CSV | [CasiListo/Views/ShoppingHistoryView.swift](CasiListo/Views/ShoppingHistoryView.swift) |
| Rutas de archivos locales | [CasiListo/Services/LocalFileStore.swift](CasiListo/Services/LocalFileStore.swift) |
| Borrado total y barrido de huérfanos | [CasiListo/Services/ShoppingPersistenceCoordinator.swift](CasiListo/Services/ShoppingPersistenceCoordinator.swift) |
| Contrato del App Group / widget | [CasiListoShared/WidgetContract.swift](CasiListoShared/WidgetContract.swift) |
| Notas de voz | [CasiListo/Services/VoiceNoteService.swift](CasiListo/Services/VoiceNoteService.swift) |
| OCR de boletas | [CasiListo/Services/ReceiptServices.swift](CasiListo/Services/ReceiptServices.swift) |
| Manifiestos de privacidad | [CasiListo/PrivacyInfo.xcprivacy](CasiListo/PrivacyInfo.xcprivacy) · [CasiListoWidget/PrivacyInfo.xcprivacy](CasiListoWidget/PrivacyInfo.xcprivacy) |
| Validación de manifiestos | [ci/validate-privacy-manifests.sh](ci/validate-privacy-manifests.sh) |
| Esquema de URL y cifrado | [CasiListo/Info.plist](CasiListo/Info.plist) |
| Entitlements del App Group | [CasiListo/CasiListo.entitlements](CasiListo/CasiListo.entitlements) · [CasiListoWidget/CasiListoWidget.entitlements](CasiListoWidget/CasiListoWidget.entitlements) |
| Sitio y despliegue | [privacy-site/](privacy-site/) · [.github/workflows/deploy-privacy.yml](.github/workflows/deploy-privacy.yml) |
