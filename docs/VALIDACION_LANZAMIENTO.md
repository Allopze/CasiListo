# Validación de lanzamiento de CasiListo 1.0

Este documento contiene la lista de comprobaciones y procedimientos operativos necesarios para completar el lanzamiento de **CasiListo 1.0** en Apple App Store.

---

## 1. Configuración de Infraestructura y CI/CD (GitHub Actions)

### Cloudflare Pages (Sitio de Privacidad y Soporte)
- [ ] En GitHub (Settings → Secrets and variables → Actions):
  - **Variables de repositorio**:
    - `PUBLIC_SUPPORT_EMAIL`: Correo real de atención y soporte (ej. `soporte@casilisto.app`).
    - `PUBLIC_POLICY_EFFECTIVE_DATE`: Fecha de vigencia (ej. `12 de agosto de 2026`).
  - **Secretos de repositorio**:
    - `CLOUDFLARE_ACCOUNT_ID`: ID de cuenta de Cloudflare.
    - `CLOUDFLARE_API_TOKEN`: Token con permisos de Cloudflare Pages.
- [ ] Ejecutar el workflow **Deploy privacy site** (`deploy-privacy.yml`) y comprobar:
  - `https://casilisto-privacy.pages.dev/privacy/`
  - `https://casilisto-privacy.pages.dev/support/`

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
  - **Privacy Policy URL**: `https://casilisto-privacy.pages.dev/privacy/`
  - **Support URL**: `https://casilisto-privacy.pages.dev/support/`
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

---

## 5. Matriz de Accesibilidad y UI

- [ ] **Dynamic Type**: Probar en tamaño AX5 (máximo de accesibilidad) comprobando que no haya truncamiento de botones o textos.
- [ ] **VoiceOver**: Recorrido completo de navegación (Compra, Catálogo, Historial, Ajustes y sheets modales).
- [ ] **Voice Control y Switch Control**: Validar que todos los botones y acciones sean accionables.
- [ ] **Ajustes de Visión**: Probar con *Reducir transparencia*, *Aumentar contraste* y *Reducir movimiento* activados.
- [ ] **Dispositivos y Temas**: Validar en modo Claro y Oscuro en iPhone compacto (SE) y iPhone Pro Max.
- [ ] **Piso de iOS**: correr la suite y el arnés (`ci/capture-screenshots.sh --os 26.0`) contra un runtime iOS 26 real, no solo contra el más reciente.

