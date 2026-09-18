# CasiListo

App iOS nativa (SwiftUI + SwiftData, cero dependencias externas) de listas de compra para supermercados chilenos Jumbo/Líder, con OCR de boletas, widget de WidgetKit y notas de voz.

Toda la UI, los comentarios y los mensajes de commit están en **español**; identificadores, tipos y nombres de test en **inglés**. Mantén esa división.

---

## Comandos

`xcode-select` ya apunta a `/Applications/Xcode.app/Contents/Developer` en esta máquina — no hace falta exportar `DEVELOPER_DIR` (CASI-027; la referencia anterior a `Xcode-beta.app` estaba desactualizada y ese path ya no existe).

```bash
# Suite completa. El scheme CasiListo corre unitarios Y UI tests (sus dos
# TestableReference tienen skipped="NO"), incluidos los DOS arneses visuales:
# ScreenshotCaptureTests (23 PNG que caen en /tmp si no defines
# TEST_RUNNER_SCREENSHOT_DIR) y FullLengthScreenshotTests (ImageRenderer).
xcodebuild test -project CasiListo.xcodeproj -scheme CasiListo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Loop rápido: mismo comando + estos dos flags, que son los mismos que usa el CI.
#   -skip-testing:CasiListoUITests/ScreenshotCaptureTests
#   -skip-testing:CasiListoTests/FullLengthScreenshotTests
# Acotar: -only-testing acepta bundle, clase o método suelto. CasiListoTests son
# 15 archivos y ~225 `func test` (5 de ellos el arnés full-length) y
# CasiListoUITests 16, así que vale la pena apuntar fino.
#   -only-testing:CasiListoTests
#   -only-testing:CasiListoTests/PurchaseHistoryTests
#   -only-testing:CasiListoTests/PurchaseHistoryTests/testMatcherRecognizesTypicalReceiptAbbreviations

bash ci/validate-privacy-manifests.sh artifacts   # plutil + greps; parte del CI
bash ci/validate-public-site.sh                   # curl contra casilisto.lat: status, 404 con cuerpo, HSTS/CSP y HTTP→HTTPS
ci/capture-screenshots.sh                         # iPhone 17 Pro, claro+oscuro (~6-8 min)
ci/capture-screenshots.sh --full                  # + Pro Max y texto XXL (~30 min)
ci/capture-full-screenshots.sh                    # PNG de longitud completa vía ImageRenderer (~5-15 s)
ci/record-app-tour.sh                             # Graba video MP4 del recorrido de todas las pantallas (~3 min)
cd privacy-site && npm run build                  # sin deps ni lockfile, genera dist/
cd privacy-site && npm test                       # scripts/test.mjs sobre dist/: headers, 404, sitemap, dominio viejo
```

- **`-resultBundlePath artifacts/X.xcresult` falla en la segunda corrida**: xcodebuild aborta si el bundle ya existe. En CI el runner arranca limpio; en local borra el path o omite el flag.
- Solo hay **dos schemes**: `CasiListo` y `CasiListoWidget`; **`-scheme CasiListoTests` no existe**. No hay `.xctestplan`: se acota con `-only-testing` / `-skip-testing`. Ambos testables van con `parallelizable = "YES"` en el scheme versionado.
- El CI ([ios.yml](.github/workflows/ios.yml)) usa `iPhone 17 Pro,OS=latest` —el mismo de aquí— y corre unitarios y UI tests en un solo `xcodebuild test`, **saltando los dos arneses visuales** (`-skip-testing:CasiListoUITests/ScreenshotCaptureTests` y `-skip-testing:CasiListoTests/FullLengthScreenshotTests`, porque son diagnósticos lentos): un label en español roto no es un problema local, tumba el CI del PR, pero una regresión que solo rompa las capturas pasa el CI sin ruido. Antes de los tests corre **SwiftLint con la versión fijada** en el propio workflow (`SWIFTLINT_VERSION`); los umbrales de [.swiftlint.yml](.swiftlint.yml) están calibrados contra esa versión y contra el código actual, así que hoy no hay ningún error, solo warnings (medido el 18-09-2026 con 0.65.1: **38 warnings, 0 errores**). Subir la versión exige recalibrar.
- `capture-screenshots.sh` acepta `--devices`, `--os`, `--appearances`, `--text-sizes`, `--out`, `--keep-going`, `-h`; sale por defecto a `build/screenshots` (ignorado por git) y él mismo exporta `DEVELOPER_DIR` si no viene definido. Los nombres de dispositivo se comparan **literalmente** contra `simctl list devices available`, y ahora **dentro de la sección del runtime pedido**: con dos runtimes instalados, el `grep` plano booteaba el simulador equivocado.
- **El simulador del destino puede no existir.** El 18-09-2026 esta máquina ya no tenía instancia de `iPhone 17 Pro` ni `iPhone 17 Pro Max` (solo iPhone 17, 17e, Air y los 18 Pro), y el destino de arriba moría con `Unable to find a device matching the provided destination specifier`. El *device type* sí sigue disponible, así que se recrean sin descargar nada: `xcrun simctl create "iPhone 17 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0` (ídem `-17-Pro-Max`). Revisa con `xcrun simctl list devices available` antes de culpar al proyecto.
- Xcode local es 27.0 (Swift 6.4); el CI fija Xcode 26.0 y solo valida `major >= 26`, así que nada avisa de la divergencia. **El único runtime instalado es iOS 27.0**, así que `--os 26.0` y cualquier prueba del piso declarado no se pueden correr aquí hasta instalar ese runtime desde Xcode.
- Release: [release-testflight.yml](.github/workflows/release-testflight.yml) es `workflow_dispatch`; **`gh` no está instalado en esta máquina** (dispáralo desde la pestaña Actions, o `brew install gh` y luego `gh workflow run release-testflight.yml --ref main`). Sube con `xcrun iTMSTransporter -m upload -assetFile artifacts/export/CasiListo.ipa`. Secretos que espera: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`.
- El sitio público es **otro workflow**: [deploy-privacy.yml](.github/workflows/deploy-privacy.yml) (push a `main` que toque `privacy-site/**`, o `workflow_dispatch`) publica `privacy-site/` como **Worker de assets** de Cloudflare en `https://casilisto.lat`. Ahí viven `CLOUDFLARE_ACCOUNT_ID` y `CLOUDFLARE_API_TOKEN` (token con *Workers Scripts: Edit*; uno de Pages autentica pero no publica) y las variables `PUBLIC_SITE_URL`, `PUBLIC_SUPPORT_EMAIL`, `PUBLIC_POLICY_EFFECTIVE_DATE`. Las URLs compiladas en la app ([AppSupportLinks.swift](CasiListo/Services/AppSupportLinks.swift)) apuntan a ese dominio.

---

## Mapa de arquitectura

4 targets en un único `.xcodeproj`: `CasiListo`, `CasiListoWidget`, `CasiListoTests`, `CasiListoUITests`.

Todos usan **`PBXFileSystemSynchronizedRootGroup`**: poner un `.swift` en la carpeta lo agrega al target automáticamente; no se edita el pbxproj. La única `membershipException` es `Info.plist`. La carpeta **`CasiListoShared/`** está declarada en `fileSystemSynchronizedGroups` de la app **y** del widget: es el único código que comparten (el contrato del App Group y los tipos del snapshot). Cualquier otra cosa que deban compartir va ahí, no duplicada.

`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `TARGETED_DEVICE_FAMILY = 1` (solo iPhone). `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` **solo en app y widget**, no en los targets de test: por eso los tests anotan `@MainActor` a mano y el código de app anota `nonisolated`.

Navegación real (el README dibuja otra):
`CasiListoApp` → [MainTabView](CasiListo/Views/MainTabView.swift) (4 tabs) → **Compra**: [ContentView](CasiListo/Views/ContentView.swift) → [ListsOverviewView](CasiListo/Views/ListsOverviewView.swift) → `navigationDestination(for: UUID.self)` → [ShoppingListDetailView](CasiListo/Views/ShoppingListDetailView.swift) → [ShoppingListView](CasiListo/Views/ShoppingListView.swift) → [CategorySectionView](CasiListo/Views/CategorySectionView.swift) → [ItemRowView](CasiListo/Views/ItemRowView.swift). Los otros tabs ([CatalogView](CasiListo/Views/CatalogView.swift), [ShoppingHistoryView](CasiListo/Views/ShoppingHistoryView.swift), [SettingsView](CasiListo/Views/SettingsView.swift)) tienen su propio `NavigationStack`.

Datos: las **Views** poseen los `@Query` (no hay capa de repositorio) → pasan arrays planos al ViewModel → toda escritura pasa por [ShoppingPersistenceCoordinator](CasiListo/Services/ShoppingPersistenceCoordinator.swift) → `context.save()` → snapshot del widget.

---

## Subsistemas

**Arranque y persistencia.** [CasiListoApp](CasiListo/CasiListoApp.swift) monta la WindowGroup con `.modelContainer(CasiListoModelContainer.make())`, pero el *bootstrap real de datos no está ahí*: vive en el `.task` de [ContentView](CasiListo/Views/ContentView.swift) (limpieza de defaults legacy, `CategoryBootstrapService.bootstrap`, `ShoppingListLifecycleService.bootstrap`, `SuggestedProducts.seedCatalogItems`, normalización de `sortOrder`, barrido de huérfanos, refresco del widget) — **el orden importa**. Antes de todo eso, `resetStorageForUITestsIfNeeded()` ([ContentView.swift:105-140](CasiListo/Views/ContentView.swift)) intercepta los launch arguments de UI test y hace `return`. El container se crea sin `ModelConfiguration` explícita; como el target tiene el entitlement de App Group, **la base SwiftData vive en el contenedor del grupo** (`group.com.allopze.CasiListo`), mientras los blobs (boletas JPG, notas de voz M4A) viven en el sandbox privado vía [LocalFileStore](CasiListo/Services/LocalFileStore.swift).

**Modelo de datos.** Exactamente 4 `@Model`: [ShoppingItem](CasiListo/Models/ShoppingItem.swift), [Category](CasiListo/Models/Category.swift), [ShoppingList](CasiListo/Models/ShoppingList.swift), [ProductCatalogItem](CasiListo/Models/ProductCatalogItem.swift). `ShoppingList` ↔ `ShoppingItem` **no es una relación SwiftData**: es la clave blanda `ShoppingItem.listID` (deliberado; borrar una lista exige borrar sus ítems a mano). Delete rules todos `.nullify`; la única unicidad es `@Attribute(.unique)` en `Category.name`. El formateo de precios está centralizado en una extensión de `Double` al final de `ShoppingItem.swift` (`formattedPrice`, `formattedPriceWithSymbol`, `Optional<Double>.formattedPriceOrEmpty`).

**ViewModel y servicios.** [ShoppingListViewModel](CasiListo/ViewModels/ShoppingListViewModel.swift) es el **único** ViewModel (`@Observable`; no hay un solo `ObservableObject` en el repo). No observa el store: cachea un snapshot (`derivedGroups` / `derivedSummary`) que se invalida a mano en el bloque `onAppear`/`onChange` de [ShoppingListView.swift:177-208](CasiListo/Views/ShoppingListView.swift) — **si agregas un input de filtro tienes que agregar su `onChange`**. Los servicios son `enum` sin estado con funcs estáticas; los que tocan datos reciben el `ModelContext` (`CategoryBootstrapService`, `ShoppingListLifecycleService`, `CatalogService`, todos `@MainActor`) y los puros no ([CSVSerializer](CasiListo/Services/CSVSerializer.swift), [ProductNameNormalizer](CasiListo/Services/ProductNameNormalizer.swift) + `DuplicatePolicy`, ambos `nonisolated`).

**OCR de boletas.** [ReceiptDocumentCamera](CasiListo/Views/Components/ReceiptDocumentCamera.swift) (VisionKit) → [ReceiptServices.swift](CasiListo/Services/ReceiptServices.swift) `ReceiptTextRecognitionService` (Vision revisión 3, `usesLanguageCorrection = false` a propósito, off-main en `Task.detached`) → [ReceiptTextLine.swift](CasiListo/Services/ReceiptTextLine.swift) `ReceiptLineAssembler` (union-find sobre afinidad geométrica; el veto por solape horizontal >0.02 es lo que evita fusionar filas en fotos torcidas) → [ReceiptLineParser.swift](CasiListo/Services/ReceiptLineParser.swift) (gramática de montos CLP, ~15 regex, `classify()` ordenado y `walk()` como máquina de estados) → `ProductNameMatcher` (asignación 1:1 codiciosa, umbral 0.55) → [ReceiptCaptureSheet](CasiListo/Views/ReceiptCaptureSheet.swift) (revisión humana + conciliación con el TOTAL impreso) → `ReceiptPurchaseService.register`. La red de seguridad son las tres boletas reales de [ReceiptFixtures.swift](CasiListoTests/ReceiptFixtures.swift), que se auto-validan contra su propio total.

**Vista y diseño.** [Theme.swift](CasiListo/Theme/Theme.swift) es la única fuente de colores, tipografías Dynamic Type, métricas, animaciones, `HapticFeedback`, `glassFilterSurface`, `AccentProminentButtonStyle` y utilidades WCAG (la capa `Adaptive*` con gating `#available` se eliminó al subir el piso a iOS 26). [ListAppearanceCatalog](CasiListo/Models/ListAppearanceCatalog.swift) provee paleta/íconos por lista y `suggestAppearance(for:)`.

**Widget y notas de voz.** El widget **sigue sin abrir la base de datos**, también ahora que es interactivo: la app publica JSON en `UserDefaults(suiteName:)` del App Group desde [WidgetDataBridge](CasiListo/Services/WidgetDataBridge.swift), y el widget lo lee con los tipos de [WidgetContract.swift](CasiListoShared/WidgetContract.swift), compartidos de verdad (ya no duplicados). Marcar comprado desde el widget ([MarkPurchasedIntent](CasiListoWidget/MarkPurchasedIntent.swift)) **no persiste nada**: actualiza el snapshot de forma optimista y encola el ID en `pendingWidgetPurchases`; la app lo aplica en SwiftData al volver a primer plano (`ShoppingPersistenceCoordinator.applyPendingWidgetPurchases`, llamado desde `MainTabView`) y republica el snapshot desde la base, que es la única fuente de verdad. La cola es **`peek` + `acknowledge`, nunca `drain`** (CASI-103): se confirma con `acknowledgedWidgetPurchases` recién después del `commit()`, así que un save fallido deja la acción en la cola para el siguiente intento en vez de perderla en silencio; `drain` sigue existiendo marcado `deprecated`. El snapshot además lleva `publicationState`, que es lo que distingue «el widget nunca recibió datos» de «la lista está vacía de verdad» (CASI-105): no lo derives otra vez de los contadores. [VoiceNoteService](CasiListo/Services/VoiceNoteService.swift) es el único servicio con estado: `@Observable final class` con singleton `VoiceNoteService.shared`, que además se inyecta por `.environment` a las vistas (el código no-vista lo usa vía `.shared`). Graba borradores `draft-*.m4a` en `Documents/VoiceNotes/.temporary` y los promueve a `voice-*.m4a` al guardar.

**Tests.** Solo XCTest (cero swift-testing). `CasiListoTests` son 15 archivos: los grandes siguen siendo [CasiListoTests.swift](CasiListoTests/CasiListoTests.swift) (66) y [PurchaseHistoryTests.swift](CasiListoTests/PurchaseHistoryTests.swift) (59), y alrededor hay suites acotadas por tema —[ReceiptRecognitionFixtureTests](CasiListoTests/ReceiptRecognitionFixtureTests.swift), [WidgetContractTests](CasiListoTests/WidgetContractTests.swift), [SchemaMigrationTests](CasiListoTests/SchemaMigrationTests.swift), [DataExportServiceTests](CasiListoTests/DataExportServiceTests.swift), [CategoryStableLinkTests](CasiListoTests/CategoryStableLinkTests.swift), [QuantitySemanticsTests](CasiListoTests/QuantitySemanticsTests.swift), [StoreLocationTests](CasiListoTests/StoreLocationTests.swift), [HistoryCSVExportServiceTests](CasiListoTests/HistoryCSVExportServiceTests.swift), [CatalogSeedingTests](CasiListoTests/CatalogSeedingTests.swift), [SiteLinksTests](CasiListoTests/SiteLinksTests.swift), [SpanishPluralizationTests](CasiListoTests/SpanishPluralizationTests.swift)—. En UI, [CasiListoUITests.swift](CasiListoUITests/CasiListoUITests.swift) y [ScreenshotCaptureTests.swift](CasiListoUITests/ScreenshotCaptureTests.swift) (arnés visual: solo `testFirstRunStartsEmptyAndTemplatePopulatesList` asserta contenido —«355 pendientes»—, el resto solo alcanzabilidad). El segundo arnés, [FullLengthScreenshotTests.swift](CasiListoTests/FullLengthScreenshotTests.swift), vive **en el target unitario** y renderiza pantallas completas con `ImageRenderer` sin el límite de la pantalla del simulador; es diagnóstico, el CI lo salta y por eso la app solo expone el shim `ShoppingHistoryDetailView.contentWithoutScroll`, no vistas facsímil.

---

## Convenciones que debes seguir

- **Toda mutación persistente**: `try ShoppingPersistenceCoordinator(context: modelContext).commit()`, construido *ad hoc* en el call site (no es singleton ni se inyecta). `commitWithoutWidget()` solo si el cambio no afecta al snapshot. `context.save()` crudo queda restringido a la capa de modelo/bootstrap.
- **Enum → raw value String + wrapper computado** (`storeRawValue`/`store`, `statusRawValue`/`status`…). Los campos nuevos se añaden como `Optional` con default en el getter, nunca como columna no opcional.
- **Los raw values SON los textos de UI en español** (`case lider = "Líder"`, `case skipped = "Pospuesto"`). Renombrar un raw value por wording **es una migración de datos**.
- Un raw value desconocido **se coacciona en silencio** con un `Logger(subsystem: "com.casilisto.app")`: `store` → `.jumbo`, `status` → `.active`, `iconName` → `"cart.fill"`. No lanza.
- Para filtrar por estado en un `@Query`, usa el global `activeShoppingListStatusRawValue` ([ShoppingList.swift:9](CasiListo/Models/ShoppingList.swift)): `#Predicate` no evalúa `ShoppingListStatus.active.rawValue` en línea ni miembros estáticos.
- **Comparación de nombres**: siempre `ProductNameNormalizer.normalize`; duplicados con `DuplicatePolicy.key(named:store:)`. Las categorías se comparan **por `name`**, nunca por identidad de objeto. Para encontrar la categoría real de una `DefaultCategory` usa `Category.matching(_:in:)` (vínculo estable `defaultCategoryRawValue`, con caída a nombre), nunca `first { $0.name == defaultCat.rawValue }`: renombrar una categoría del sistema es válido y no rompe la categorización automática (CASI-008).
- **Colores**: `accentYellow` **rellena**, `accentInteractive` **escribe** (el amarillo mide 1.45:1 sobre crema — calculado, ningún test lo fija; lo que sí asserta `testAccentTokensMeetContrastOnLightSurfaces` es `accentInteractive` ≥ 4.5:1 sobre crema y blanco, y `onAccent` ≥ 4.5:1 sobre el relleno). CTA primario `.buttonStyle(.accentProminent)`; `.borderedProminent` con tint amarillo está prohibido. Nada de literales `Color(...)`: usa `Theme.*` / `Color.app*`.
- Comentarios en español que citan **la boleta o el bug concreto** que motivó la línea.
- Los sheets add/edit comparten forma exacta: `enum Mode: Identifiable { case add; case edit(X) }`, `NavigationStack` + `Form(.grouped)`, toolbar "Cancelar"/"Guardar", `.presentationDetents` fuera del stack.
- Errores en vistas: `@State var xErrorMessage: String?` + `.alert(isPresented:)` con un único botón "Entendido".
- `Reduce Motion` se honra pasando `nil` como animación.
- **Plurales en textos de usuario**: `SpanishPluralization.count(_:singular:plural:)` ([SpanishPluralization.swift](CasiListo/Models/SpanishPluralization.swift)), nunca «producto(s)» ni «lista(s)» (CASI-113).
- **No hay infraestructura de localización** (cero `.xcstrings`, cero `NSLocalizedString`, `knownRegions = en, Base`). No metas `LocalizedStringKey`: los strings van inline en español.
- Los `#Preview` viven **solo** en [PreviewSupport.swift](CasiListo/Views/PreviewSupport.swift), bajo `#if DEBUG`.
- Commits: Conventional Commits con scope en español sin tildes (`feat(boleta): …`, `fix(catalogo): …`).

**Regla de las 100 líneas del README: no se cumple y nada la aplica.** 46 de 75 `.swift` la exceden (peores: [ReceiptCaptureSheet.swift](CasiListo/Views/ReceiptCaptureSheet.swift) 1007, [PurchaseHistoryTests.swift](CasiListoTests/PurchaseHistoryTests.swift) 960, [ReceiptServices.swift](CasiListo/Services/ReceiptServices.swift) 873, [CasiListoTests.swift](CasiListoTests/CasiListoTests.swift) 835). No hay SwiftLint/SwiftFormat ni check de CI. Corolario práctico: **un tipo no vive necesariamente en el archivo con su nombre** — `DuplicatePolicy` está en `ProductNameNormalizer.swift`, `WidgetItemSnapshot` en `WidgetDataBridge.swift`, `ReceiptImageComposer` en `ReceiptDocumentCamera.swift`, y `ReceiptServices.swift` contiene 14 tipos de nivel superior.

---

## Gotchas e invariantes

**Persistencia y datos**
- Si el store persistente no abre, `CasiListoModelContainer.make()` cae a un container en memoria y marca `isUsingInMemoryFallback`. **[MainTabView](CasiListo/Views/MainTabView.swift) lo lee y muestra un banner fijo** («CasiListo no puede guardar en este dispositivo»): sin él, la persona usaba la app un día entero creyendo que guardaba. Un cambio de `@Model` sin su versión de esquema puede caer aquí.
- **Esquema versionado (V1→V2 desde CASI-008)**: las clases top-level son siempre la versión vigente; cada versión histórica es una copia congelada anidada en su enum (`CasiListoSchemaV1.Category`, …). Para V3, copia las clases vivas tal como están dentro de `CasiListoSchemaV2` y evoluciona las top-level; **nunca listes la misma clase viva en dos versiones** (checksums idénticos → `Duplicate version checksums detected`). `testSchemaInventoryIsFrozen` (vigente), `testV1InventoryIsFrozen` (copia congelada) y `testV1FixtureSurvivesTheCurrentMigrationPlan` (fixture real de la 1.0, no se regenera) son los guardianes; `testEverySchemaTransitionHasItsStage` exige N-1 etapas.
- **`ShoppingItem` guarda la categoría dos veces**: `@Relationship categoryRelation: Category?` y la sombra `categoryRawValue: String`. Solo el setter de la computada `category` mantiene ambas en sync — asignar `categoryRelation` directo las desincroniza. Además `categoryRelation` es `nil` para «Varios» ([ShoppingItem.swift:96](CasiListo/Models/ShoppingItem.swift)), que es el caso normal.
- **`status` tiene dos fuentes de verdad**: `statusRawValue: String?` y `@Attribute(originalName: "isPurchased") storedIsPurchased: Bool`. El getter cae a `storedIsPurchased` cuando el raw es `nil` (filas viejas).
- `item.category` devuelve `Category.fallback` —**instancia nueva, no gestionada, en cada acceso**— siempre que `categoryRelation == nil`. Compárala por `name` y usa `Category.resolvedFallback(in:)` si el valor va a una relación.
- `Category.name` es `@Attribute(.unique)` y a la vez identidad y base de comparación en todo el repo. La restricción única de SwiftData hace **upsert en conflicto en vez de lanzar**.
- `commitWithoutWidget()` hace `context.rollback()` ante cualquier fallo de save: descarta **todo** lo pendiente en el contexto, no solo el cambio del llamador.
- El barrido de huérfanos solo conoce `ShoppingItem.voiceNoteFilename` y `ShoppingList.receiptImageFilename` ([ShoppingPersistenceCoordinator.swift:163-164](CasiListo/Services/ShoppingPersistenceCoordinator.swift)). Un modelo nuevo que guarde un nombre de archivo y no se registre ahí verá sus archivos borrados al siguiente arranque.
- `removeUnreferencedFiles` usa `.skipsHiddenFiles`: eso es lo único que evita que el barrido borre la carpeta `.temporary` de notas de voz. Renombrarla a `temporary` rompe la grabación. `cleanupUnreferencedFiles` la barre con `keeping: []` en cada arranque.
- En `resetAllData()` los archivos se borran **al final**, después de `commit()`: si `resetAllFiles()` lanza, la base ya quedó reseteada y con categorías, y los blobs sueltos los barre `cleanupUnreferencedFiles` al siguiente arranque. No reordenes eso.
- `seedCatalogItems` siembra **una sola vez** (clave `SuggestedProducts.hasSeededCatalogKey`), deduplica dentro del bucle e itera `DefaultCategory.allCases`: 355 filas únicas y deterministas. Antes corría en cada arranque y resucitaba lo que la persona borraba del catálogo. `resetAllData()` borra la clave y vuelve a sembrar.
- Undo restaura un **registro distinto**: `ShoppingItem.init` siempre asigna `id` y `createdAt` nuevos. Es una sola ranura global, no una cola: borrar un segundo ítem finaliza el primero y borra su nota de voz definitivamente.

**Widget y deep link**
- El contrato del App Group vive una sola vez en `WidgetContract` ([CasiListoShared/WidgetContract.swift](CasiListoShared/WidgetContract.swift)): ID del grupo, `kind`, clave del snapshot y clave de la cola. **Lo único que sigue duplicado a mano son los dos `.entitlements`**, que repiten el ID del grupo y deben coincidir con `WidgetContract.appGroupID` o el reload es un no-op silencioso. Como la base SwiftData depende del entitlement, quitar el grupo huerfaniza los datos del usuario — `CasiListoStoreLocation` lo detecta y enciende el banner de «No encontramos tus datos guardados».
- Un fallo de decode en el widget es invisible: `try?` → snapshot con ceros y `updatedAt: .distantPast`. Renombrar un campo deja un widget plausible «0 pendientes» en vez de fallar.
- El «top 5» se ordena por `sortOrder` y `createdAt` en `itemsInActiveLists()`. Si quitas ese sort vuelve a ser no determinista entre refrescos.
- `AppRoute` rechaza **cualquier** query o fragment: `casilisto://list?screen=x` → `nil`. `onOpenURL` solo cambia de tab, no toca el `navigationPath`.

**Vistas**
- [CatalogView](CasiListo/Views/CatalogView.swift) y Compra comparten la lista destino vía `@AppStorage(ActiveListSelection.storageKey)`: Compra la escribe al abrir una lista y [ActiveListSelection](CasiListo/Services/ActiveListSelection.swift) resuelve (selección vigente → activa más reciente). Cualquier pantalla nueva que escriba en «la lista activa» debe usar ese resolver, no `first { $0.status == .active }`.
- El colapso de categorías se guarda **por lista** (`collapsedCategoryNames-<uuid>`). El VM se asocia con `bind(listID:)` desde el `onAppear`/`onChange` de [ShoppingListView](CasiListo/Views/ShoppingListView.swift); sin lista asociada (tests, previews) cae a la clave global histórica. Para borrarlo todo usa `ShoppingListViewModel.removeAllCollapsedCategoryState()`, no un `removeObject` suelto.
- [ContentView.swift:36-41](CasiListo/Views/ContentView.swift) muta `navigationPath` desde un `.onAppear`: quitarlo deja una pantalla en blanco irrecuperable al borrar una lista abierta.
- `ShoppingListDetailView` no declara `.navigationTitle` a propósito (usa `ToolbarItem(.principal)`); añadirlo duplica el título.
- `CategorySectionView` es una `Section`: fuera de una `List` pierde en silencio estilos y swipe actions.
- Ventana de gracia: `beginGracePeriod` mantiene un ítem visible 2 s tras marcarlo comprado cuando `showPurchased == false`, y `graceItemIDs` participa en el snapshot derivado.
- Claves de `UserDefaults` como literales repetidos sin enum central. `hasSeededDefaultProducts` es **clave muerta**: solo se hace `removeObject` o `set(false)`, nadie la lee. La que sí manda es `SuggestedProducts.hasSeededCatalogKey`.

**OCR**
- El piso de 100 pesos (`bareAmountFloor`) existe para que gramajes («500 GR») no se lean como precio: un producto real bajo 100 sin `$` ni columna propia se descarta en silencio.
- `ProductNameMatcher.assign` suma **+0.15** al score de los ítems ya marcados como comprados ([ReceiptServices.swift:378](CasiListo/Services/ReceiptServices.swift)), así que un par puede superar 1.0 y el orden global queda sesgado hacia lo ya comprado.
- `splitLeadingQuantity` reconstruye filas con el init sintético de `ReceiptTextLine` y **pierde la geometría**, así que el monto se juzga con el piso estricto.
- Multipágina: las líneas de todas las páginas se concatenan antes de parsear, así que el límite de header (14 líneas) y la detección de tienda (12) solo cubren la página 1, y `footerBoundary` corta en el primer TOTAL de toda la concatenación.
- Un descuento que llega con `pendingName != nil` se descarta entero (deliberado: evita productos fantasma).
- Cualquier salida temprana después de `ReceiptImageStore.save` debe borrar el JPEG o deja un huérfano en `Application Support/Receipts`.

**Tests y arnés**
- Launch arguments: `-ui-testing-reset` (siembra el fixture de 363 productos + lista activa), `-ui-testing-reset-empty` (primer arranque sin lista). Ambos hacen `return` **antes** de todo el bootstrap, y el borrado ocurre **una sola vez por lanzamiento** (`ContentView.didResetForUITests`): el `.task` se reejecuta cada vez que la pestaña Compra reaparece, así que sin esa marca volver desde otra pestaña borraba lo creado mientras tanto y ningún test multi-pestaña era fiable.
- Las variables del arnés de capturas deben exportarse con prefijo **`TEST_RUNNER_`** (xcodebuild lo quita al reenviarlas): `TEST_RUNNER_SCREENSHOT_DIR`, `_APPEARANCE`, `_TEXT_SIZE`. Sin prefijo caen a `/tmp` en silencio.
- `capture()` escribe con `try?` ([ScreenshotCaptureTests.swift:311](CasiListoUITests/ScreenshotCaptureTests.swift)): si el directorio destino no existe, **no se genera ninguna imagen y la suite igual da verde**. `capture-screenshots.sh` hace `mkdir -p` antes de cada variante, así que esto solo muerde al invocar `xcodebuild` a mano con un `TEST_RUNNER_SCREENSHOT_DIR` inexistente. Crea la carpeta primero, y no leas «tests en verde» como «hay capturas».
- La apariencia se fuerza **dos veces**: launch argument para la jerarquía de la app + `xcrun simctl ui <udid> appearance` para los sheets, que se presentan fuera de ella.
- `ScreenshotCaptureTests` asserta el literal `"355 pendientes"`: agregar o quitar un producto sugerido lo rompe.
- Los UI tests tocan **labels en español** («Añadir», «Archivar comprados», «Añadir boleta y archivar») además de los 9 `accessibilityIdentifier` que usan (de los 12 que declara la app). Varios identificadores se interpolan con datos de usuario: `category-section-\(category.name)`, `list-card-\(list.title)`.
- `CasiListoUITestsLaunchTests` lanza sin argumentos y **no resetea el estado**: se contamina con corridas previas.
- Dos tests dependen de reloj real (`graceDuration` + `Task.sleep`) y `CasiListoTests` muta `UserDefaults.standard` con el scheme en modo paralelizable.
- Agregar una boleta de regresión: añade el `static let` en [ReceiptFixtures.swift](CasiListoTests/ReceiptFixtures.swift) y mételo en `static let all`. Los productos se comparan **posicionalmente con `zip`**; las repeticiones de nombre son intencionales.

**Release**
- `CURRENT_PROJECT_VERSION` sigue en 1 en el pbxproj, pero el release ya no lo usa: lo sobrescribe en la línea de comandos con `github.run_number`, o con el input `build_number` del dispatch. No hace falta tocar el pbxproj para publicar.
- `release-testflight.yml` escribe la key de ASC **antes** del archive y pasa `-authenticationKeyPath/-ID/-IssuerID` a archive y export, que es lo que `-allowProvisioningUpdates` necesita para emitir el perfil de distribución. Sigue sin importar un certificado propio a un keychain: depende por completo del signing automático. Confirma en Actions antes de asumir que corre en verde.
- `ITSAppUsesNonExemptEncryption` está declarado en `false` en el [Info.plist](CasiListo/Info.plist) parcial de la app (no hay red ni criptografía propia). Si algún día se añade cifrado propio hay que revisarlo.
- Editar cualquier `PrivacyInfo.xcprivacy` rompe CI si dejan de calzar los greps de [validate-privacy-manifests.sh](ci/validate-privacy-manifests.sh) (`NSPrivacyTracking => false` en ambos, `CA92.1` en la app, `1C8F.1` en ambos).
- `CFBundleURLTypes` vive en el [Info.plist](CasiListo/Info.plist) **parcial** a propósito: `GENERATE_INFOPLIST_FILE = YES` los fusiona **solo en el target de la app**. El widget usa `GENERATE_INFOPLIST_FILE = NO` con un `CasiListoWidget/Info.plist` completo, donde los `INFOPLIST_KEY_*` no aplican.

---

## Docs desactualizados y trabajo en curso

- **[README.md](README.md) está al día** (mapa de archivos correcto, `MainTabView` como raíz, OCR/catálogo/plantillas/widget documentados, piso iOS 26 y solo iPhone). La advertencia anterior de que no era fiable ya no aplica.
- **[AUDITORIA_LANZAMIENTO_APP_STORE_2026-08-12.md](AUDITORIA_LANZAMIENTO_APP_STORE_2026-08-12.md) es un snapshot histórico mayormente resuelto** (20 hallazgos F-01..F-20). Cita `safeSave()`, `AppSettings.swift`, `GeofenceService.swift` y «Modo Compra», **ninguno existe**; toda la geolocalización fue eliminada (cero `CoreLocation` en el árbol). No uses sus números de línea. **F-09 está resuelto**: `AddEditItemSheet.hasExplicitCategorySelection` protege la elección manual. Sigue vigente **F-20** (el archive/upload de release nunca se validó). F-12, F-14, F-15 y F-19 no fueron reverificados.
- **[docs/VALIDACION_LANZAMIENTO.md](docs/VALIDACION_LANZAMIENTO.md)** es la referencia real y **viva** de secretos/variables de CI y del checklist manual; ya está commiteada. Trae el estado medido del sitio público con fecha: al 18-09-2026 lo único abierto ahí es que `http://casilisto.lat/` responde 200 en claro (falta *Always Use HTTPS* en el panel de Cloudflare; no se arregla redesplegando) y que el runtime iOS 26 no está instalado.
- **[docs/AUDITORIA_UI_UX_PRODUCCION_2026-09-14.md](docs/AUDITORIA_UI_UX_PRODUCCION_2026-09-14.md) es un snapshot del 14-09 con addendum de remediación al 18-09**: los 14 hallazgos CASI-101..114 salvo CASI-104 están cerrados y verificados en código o red (sitio publicado, historial lazy, cola del widget durable, arnés fuera del target de app, export/import asíncronos, layouts de accesibilidad, Archivar sin rol destructivo, un solo CTA de «Nueva lista», guía de gestos al final de Ajustes, `SpanishPluralization`). **Sigue abierto CASI-104**, que es el mismo hueco que F-20: Archive firmado, IPA, TestFlight, runtime iOS 26 real y recorrido físico de cámara/micrófono/widget. Sus números de línea son del corte; no los uses.
- **Trabajo reciente (auditoría de release)**: se cerraron los seis bloqueadores y los P1. Lo relevante para navegar el código hoy:
  - **Dinero**: `PriceField` en [ShoppingItem.swift](CasiListo/Models/ShoppingItem.swift) es el único punto que formatea y relee el campo de precio editable; parsea con `ReceiptAmount.value`. No volver a usar el formato de presentación como formato de edición: eso dividía por mil todo precio ≥ 1.000.
  - **Cantidades**: `ReceiptPurchaseService.unitCount` solo trata como multiplicador un entero desnudo. «500 g» es una magnitud, no 500 unidades.
  - **Catálogo**: `CatalogService.addToActiveList` lanza `CatalogError.noActiveList`; [CatalogView](CasiListo/Views/CatalogView.swift) crea la lista destino al primer «+» y muestra a cuál añade.
  - **Historial**: [ShoppingHistoryView](CasiListo/Views/ShoppingHistoryView.swift) permite borrar una compra (ítems + boleta). Agrupar en el detalle va por `category.name` vía `PurchasedItemGrouping`, nunca por identidad de objeto.
  - **Plataforma**: piso iOS 26, solo iPhone, cero `#available` en el árbol. `ci/capture-screenshots.sh --os <version>` filtra por runtime.
  - **Fototeca**: `ReceiptPhotoLibraryPicker` usa `PHPickerViewController`; el binario ya no declara `NSPhotoLibraryUsageDescription`.
