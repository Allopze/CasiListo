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
- [x] Ejecutar el workflow **Deploy privacy site** (`deploy-privacy.yml`) y comprobar:
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

### App Store Connect API (TestFlight y Release)
- [ ] Crear API Key en App Store Connect (Users and Access → Integrations → App Store Connect API) con rol *App Manager* o *Developer*.
- [ ] En GitHub Actions Secrets, configurar:
  - `ASC_KEY_ID`: Key ID de 10 caracteres.
  - `ASC_ISSUER_ID`: UUID del Issuer.
  - `ASC_PRIVATE_KEY`: Contenido completo del archivo `.p8`.

---

## 2. App Store Connect (Ficha y Metadata)

- [ ] Crear la aplicación en App Store Connect con Bundle ID `com.allopze.CasiListo`.
- [ ] Registrar URLs:
  - **Privacy Policy URL**: `https://casilisto.lat/privacy/`
  - **Support URL**: `https://casilisto.lat/support/`
- [ ] Completar sección **App Privacy (Nutrition Labels)**:
  - **Tracking**: Seleccionar *No, no rastreamos a los usuarios*.
  - **Data Collection**: Seleccionar *No recolectamos datos de esta app*.
  - **UserDefaults Reasons**: Confirmar `CA92.1` y `1C8F.1`.
- [ ] Generar y subir capturas de pantalla oficiales:
  - Ejecutar `ci/capture-screenshots.sh` para generar la matriz completa de pantallas.
  - Subir capturas para iPhone 6.9", 6.7", 6.5" y 5.5". **iPad no aplica**: `TARGETED_DEVICE_FAMILY = 1`.
- [ ] Completar ficha: Descripción, Subtítulo, Categorías (Productividad / Compras) y Keywords.

---

## 3. Archive y Validación del Binario

- [ ] Ejecutar el workflow **iOS verification** (`ios.yml`) con Xcode 26+.
- [ ] Revisar el `.xcresult` y que `ci/validate-privacy-manifests.sh` pase sin advertencias.
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

---

## 5. Matriz de Accesibilidad y UI

- [ ] **Dynamic Type**: Probar en tamaño AX5 (máximo de accesibilidad) comprobando que no haya truncamiento de botones o textos.
- [ ] **VoiceOver**: Recorrido completo de navegación (Compra, Catálogo, Historial, Ajustes y sheets modales).
- [ ] **Voice Control y Switch Control**: Validar que todos los botones y acciones sean accionables.
- [ ] **Ajustes de Visión**: Probar con *Reducir transparencia*, *Aumentar contraste* y *Reducir movimiento* activados.
- [ ] **Dispositivos y Temas**: Validar en modo Claro y Oscuro en iPhone compacto (SE) y iPhone Pro Max.
- [ ] **Piso de iOS**: correr la suite y el arnés (`ci/capture-screenshots.sh --os 26.0`) contra un runtime iOS 26 real, no solo contra el más reciente.
  Al 18 de septiembre de 2026 esta máquina solo tiene el runtime **iOS 27.0** (`xcrun simctl list runtimes`), así que el piso declarado sigue sin ejecutarse: hay que instalar el runtime 26.0 desde Xcode (Settings → Components) antes de marcar esta casilla.

> CI omite `CasiListoTests/FullLengthScreenshotTests` y `CasiListoUITests/ScreenshotCaptureTests` porque son diagnósticos visuales lentos. Ejecute la matriz de capturas reales con `ci/capture-screenshots.sh --full`; el diagnóstico opcional de longitud completa se ejecuta con `ci/capture-full-screenshots.sh` y exige revisar los hashes claro/oscuro antes del release.
