# Validación de lanzamiento de CasiListo 1.0

Este documento contiene la lista de comprobaciones y procedimientos operativos necesarios para completar el lanzamiento de **CasiListo 1.0** en Apple App Store.

---

## 1. Configuración de Infraestructura y CI/CD (GitHub Actions)

### Cloudflare Workers (Sitio de Privacidad y Soporte)
- [ ] En GitHub (Settings → Secrets and variables → Actions):
  - **Variables de repositorio**:
      - `PUBLIC_SITE_URL`: `https://casilisto.lat`.
      - `PUBLIC_SUPPORT_EMAIL`: Correo real de atención y soporte (ej. `soporte@casilisto.app`).
    - `PUBLIC_POLICY_EFFECTIVE_DATE`: Fecha de vigencia (ej. `12 de agosto de 2026`).
  - **Secretos de repositorio**:
    - `CLOUDFLARE_ACCOUNT_ID`: ID de cuenta de Cloudflare.
    - `CLOUDFLARE_API_TOKEN`: Token con **Workers Scripts: Edit** (plantilla *Edit Cloudflare Workers*). Un token de Cloudflare Pages autentica pero no puede publicar este sitio.
- [ ] Ejecutar el workflow **Deploy privacy site** (`deploy-privacy.yml`) y comprobar:
  - `https://casilisto.lat/privacy/`
  - `https://casilisto.lat/support/`
  - `https://casilisto.lat/robots.txt`, `https://casilisto.lat/sitemap.xml` y una ruta inexistente (`404` legible).
  - HTTP → HTTPS, `www` → dominio raíz y HSTS desde Cloudflare, una vez verificados todos los subdominios.

  La comprobación repetible de la salida pública está en
  [`ci/validate-public-site.sh`](../ci/validate-public-site.sh). Define
  `PUBLIC_WWW_URL` y, si corresponde, `PUBLIC_OLD_SITE_URL` para incluir las
  redirecciones de hostname configuradas en Cloudflare.

> Las redirecciones entre hostnames (`www`, dominio antiguo y raíz) son configuración de zona/Bulk Redirects de Cloudflare; no se simulan en `_redirects` de Pages.

**Estado medido el 18 de septiembre de 2026** con `ci/validate-public-site.sh` contra `https://casilisto.lat`, ya desplegado como Worker de assets:

- ✅ `/`, `/privacy/`, `/support/`, `/robots.txt` y `/sitemap.xml` responden **200**.
- ✅ Una ruta inexistente responde **404 con cuerpo legible**: la `404.html` del repo ya está desplegada.
- ✅ `Strict-Transport-Security: max-age=31536000`, `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options` y `Referrer-Policy` presentes. El script exige las tres primeras, así que un despliegue que pierda `_headers` lo hace fallar.
- ❌ `http://casilisto.lat/` responde **200 en claro** en vez de 301/308. Es el único hallazgo abierto y es ajuste de zona (*Always Use HTTPS* en el panel de Cloudflare), no del repo: redesplegar no lo arregla.
- ⚠️ `www.casilisto.lat` no resuelve; si no se va a usar, deja `PUBLIC_WWW_URL` sin definir en vez de configurar la redirección.

Con `PUBLIC_WWW_URL` sin definir, el script termina en el ❌ del HTTP en claro; cuando *Always Use HTTPS* quede activo debe llegar a «Validación pública completada».

Desde este entorno no se pudo cambiar la configuración de la zona ni inspeccionar los secretos remotos de GitHub: no hay `gh` ni credenciales locales de Cloudflare. La validación del sitio publicado confirma que el redirect HTTP sigue pendiente.

### App Store Connect API (TestFlight y Release)
- [ ] Crear API Key en App Store Connect (Users and Access → Integrations → App Store Connect API) con rol *App Manager* o *Developer*.
- [ ] En GitHub Actions Secrets, configurar:
  - `ASC_KEY_ID`: Key ID de 10 caracteres.
  - `ASC_ISSUER_ID`: UUID del Issuer.
  - `ASC_PRIVATE_KEY`: Contenido completo del archivo `.p8`.

No hay credenciales de App Store Connect ni `gh` en este entorno, por lo que el workflow de TestFlight no se pudo disparar y no se modificó App Store Connect.

---

## 2. App Store Connect (Ficha y Metadata)

- [ ] Crear la aplicación en App Store Connect con Bundle ID `com.allopze.CasiListo`.
- [ ] Registrar URLs:
  - **Privacy Policy URL**: `https://casilisto.lat/privacy/`
  - **Support URL**: `https://casilisto.lat/support/`
- [ ] Completar sección **App Privacy (Nutrition Labels)**:
  - Declarar *No tracking* y *No data collected* solo tras revisar el binario Release, dependencias integradas y Privacy Report de Xcode.
  - **UserDefaults Reasons**: Confirmar `CA92.1` y `1C8F.1`.
- [x] Generar y revisar localmente las cinco capturas principales con `ci/capture-screenshots.sh --devices "iPhone 18 Pro Max" --appearances light --text-sizes default --out build/app-store-screenshots`.
  - Los cinco PNG seleccionados están en `build/app-store-submission/`: menú de listas, lista activa, catálogo, captura de boleta e historial. La corrida guardó el `.xcresult` en `build/app-store-screenshots/_results/`.
  - El borrador local de nombre, subtítulo, descripción y palabras clave está en [`docs/APP_STORE_FICHA_ES_CL.md`](APP_STORE_FICHA_ES_CL.md); falta copiarlo y completar la ficha en App Store Connect.
  - **Pendiente:** subir las imágenes a App Store Connect una vez que el propietario confirme el contenido de la ficha.
  - Confirmar formato PNG/JPEG sin canal alfa y dimensiones vigentes antes de subir. Al 21 de septiembre de 2026, la captura de 6,9" de iPhone 18 Pro Max es 1320 × 2868; si no se suben capturas de 6,9", App Store Connect requiere el conjunto de 6,5". Una captura de 6,3" no sustituye esos tamaños requeridos. Subir entre 1 y 10 capturas por localización. **iPad no aplica**: `TARGETED_DEVICE_FAMILY = 1`.
  - Comprobar la tabla vigente de Apple antes de cargar los recursos: <https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications>.
- [ ] Completar ficha: Descripción, Subtítulo, Categorías (Productividad / Compras) y Keywords.

---

## 3. Archive y Validación del Binario

- [ ] Ejecutar el workflow **iOS verification** (`ios.yml`) con Xcode 26+.
- [ ] Revisar el `.xcresult` y que `ci/validate-privacy-manifests.sh` pase sin advertencias.

**Estado medido el 18 de septiembre de 2026** en local (Xcode 27, simulador iPhone 17 Pro con iOS 27.0), con los tres arneses visuales saltados igual que el CI:

- ✅ `xcodebuild test` termina en `** TEST SUCCEEDED **`: **230 pruebas**, ninguna falla.
- ✅ SwiftLint **0.65.1** —la versión que fija `ios.yml`— sobre los cinco directorios: **38 warnings, 0 errores**, así que el gate de lint pasa.
- ⚠️ Sigue sin producirse un `.xcresult` válido en local: esta corrida se hizo sin `-resultBundlePath` para evitar el aborto por bundle existente. El `.xcresult` del CI es el que vale como evidencia.

**Actualización del 21 de septiembre de 2026:** tras los cambios de compatibilidad, el conjunto que ejecuta CI (con los tres arneses visuales omitidos igual que en el workflow) volvió a pasar en iPhone 17 Pro con iOS 27.0: **228 aprobadas, 0 fallidas y 1 omitida por el propio test** (`testGenerateV1FixtureStore`). Xcode marcó el resultado `Passed`, sin advertencias de runtime; el `.xcresult` más reciente está en `build/ios27/CasiListoTests-post-ios26-fixes.xcresult`. El validador de manifiestos de privacidad pasó.

**Actualización del 21 de septiembre de 2026 — piso mínimo:** se instaló iOS 26.0 (build 23A343) y la misma suite pasó en iPhone 17 Pro: **228 aprobadas, 0 fallidas y 1 omitida** (`testGenerateV1FixtureStore`). El `.xcresult` está en `build/ios26/CasiListoTests-validated.xcresult`. Durante el primer intento se corrigieron dos fallos de liberación de objetos aislados por `MainActor` y el rollback en memoria de compras del widget. También se aisló la suite `UserDefaults` de los tests para limpiar datos persistentes entre ejecuciones. El resultado final está aprobado; XCTest aún informa una advertencia de jerarquía de `_UIReparentingView` en una prueba UI.

El SwiftLint 0.65.1 del workflow también pasó en los cinco directorios: **38 advertencias y cero errores**.

**Actualización del 21 de septiembre de 2026:** se limpió el CSS que ya no usa ninguna página y se retiraron dos clases HTML sin estilo. `npm run build && npm test` pasa localmente. Aún falta publicar ese cambio en Cloudflare y confirmar que el workflow remoto termine correctamente.

La suite de captura de interfaz pasó en iPhone 18 Pro Max con el runtime iOS 27.0. Se modificó el arnés para guardar los PNG como adjuntos de XCTest y exportarlos desde un `.xcresult`; la suite se ejecuta serialmente para evitar una falla intermitente al presentar la hoja «Nueva lista». El resultado y las cinco capturas seleccionadas se conservaron bajo `build/` (ignorado por Git).

- [ ] En Xcode: **Product → Archive** con configuración *Release*.
- [ ] En Xcode Organizer:
  - Seleccionar el archive y hacer clic en **Generate Privacy Report** para verificar que no aparezcan APIs no declaradas ni SDKs de terceros con tracking.
  - Validar la firma y los entitlements de App Group (`group.com.allopze.CasiListo`).

---

## 4. Pruebas Manuales en Dispositivo Físico

- [ ] **Deep Linking**:
  - Abrir `casilisto://list` desde Safari o Notas con la app cerrada y abierta; una URL desconocida no debe alterar la pantalla.
- [ ] **WidgetKit**:
  - Tocar el widget en pantalla de inicio con lista vacía, lista con datos y tras marcar/desmarcar productos.
- [ ] **Permisos de Audio y Micrófono**:
  - Permitir, denegar y revocar micrófono en Ajustes; probar interrupciones por llamada entrante y cambio de ruta de audio (auriculares/Bluetooth).
- [ ] **OCR de Boletas con Cámara**:
  - Escanear boletas reales de Jumbo y Líder (papel térmico, arrugadas y con distintas condiciones de luz).
- [ ] **Exportación CSV**:
  - Abrir archivo exportado con comillas, comas, saltos de línea y fórmulas en **Apple Numbers**, **Microsoft Excel** y **Google Sheets**.
- [ ] **Rendimiento / Profiling**:
  - Cargar 1.000 y 5.000 ítems en dispositivo y verificar con Time Profiler que ninguna interacción bloquee más de 100 ms el hilo principal.
  - El JSON contiene listas, productos, categorías y catálogo; el CSV contiene historial. Fotos de boletas y notas de voz quedan fuera y dependen del respaldo del dispositivo.

No se pudieron completar estas pruebas manuales: el iPhone 17 Pro Max emparejado con esta máquina figura como **no disponible** (última conexión 18 de septiembre de 2026). El simulador no sustituye la prueba de cámara, audio, widget ni interrupciones reales.

---

## 5. Matriz de Accesibilidad y UI

- [ ] **Dynamic Type**: Probar en tamaño AX5 (máximo de accesibilidad) comprobando que no haya truncamiento de botones o textos.
- [ ] **VoiceOver**: Recorrido completo de navegación (Compra, Catálogo, Historial, Ajustes y sheets modales).
- [ ] **Voice Control y Switch Control**: Validar que todos los botones y acciones sean accionables.
- [ ] **Ajustes de Visión**: Probar con *Reducir transparencia*, *Aumentar contraste* y *Reducir movimiento* activados.
- [ ] **Dispositivos y Temas**: Validar en modo Claro y Oscuro en iPhone compacto (SE) y iPhone Pro Max.
- [x] **Piso de iOS — suite CI**: validada en iPhone 17 Pro con iOS 26.0 y 27.0; conservar los `.xcresult` indicados arriba.
- [ ] **Piso de iOS — arnés visual**: ejecutar `ci/capture-screenshots.sh --devices "iPhone 17 Pro" --os 26.0 --appearances light --text-sizes default` si se necesita confirmar las capturas en el runtime mínimo. La matriz de capturas de lanzamiento ya pasó en iOS 27.0.

> CI omite `CasiListoTests/FullLengthScreenshotTests`, `CasiListoUITests/ScreenshotCaptureTests` y `CasiListoUITests/VideoTourTests` porque son diagnósticos visuales lentos que no asertan nada; el último solo graba envuelto en `ci/record-app-tour.sh`. Ejecute la matriz de capturas reales con `ci/capture-screenshots.sh --full`; el diagnóstico opcional de longitud completa se ejecuta con `ci/capture-full-screenshots.sh` y exige revisar los hashes claro/oscuro antes del release.
