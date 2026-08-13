# Validación de lanzamiento de CasiListo 1.0

Este documento deja explícitas las comprobaciones que deben completarse antes de marcar los hallazgos de la auditoría como resueltos.

## App Store Connect

- [ ] Crear el correo real de soporte y configurar `PUBLIC_SUPPORT_EMAIL` como variable de GitHub Actions.
- [ ] Ejecutar el workflow **Deploy privacy site** y comprobar `https://casilisto-privacy.pages.dev/privacy/` y `https://casilisto-privacy.pages.dev/support/`.
- [ ] Registrar esas mismas URLs como Privacy Policy URL y Support URL en App Store Connect.
- [ ] Completar metadata, capturas y la sección App Privacy a partir del archive final y una captura de tráfico sin analítica.

## Archive y privacidad

- [ ] Ejecutar el workflow **iOS verification** con Xcode 26 o posterior.
- [ ] Revisar el `.xcresult` y los snapshots de manifest publicados como artefactos por CI.
- [ ] Abrir el archive Release en Xcode Organizer y generar manualmente el Privacy Report; Xcode no expone esa generación mediante `xcodebuild`.
- [ ] Confirmar que no hay tracking, dominios de tracking ni datos transmitidos fuera del dispositivo.
- [ ] Verificar que los reason codes de `UserDefaults` siguen vigentes antes de subir la build.

## Pruebas manuales

- [ ] Abrir `casilisto://list` con app cerrada y abierta; una URL desconocida no debe alterar la pantalla.
- [ ] Tocar el widget con App Group vacío y con un snapshot corrupto.
- [ ] En dispositivo físico: permitir, denegar y revocar micrófono; probar interrupción y cambio de ruta de audio.
- [ ] Abrir un CSV con comillas, comas, saltos de línea y fórmulas en Numbers, Excel y Google Sheets.
- [ ] Medir 1.000, 5.000 y 10.000 ítems en dispositivo físico con Time Profiler y los puntos de interés `Recalcular lista`, `Aplicar filtros` y `Exportar CSV`.
- [ ] Confirmar que ninguna interacción principal mantiene más de 100 ms de trabajo en el hilo principal.

## Matriz de accesibilidad

- [ ] iPhone compacto, iPhone grande y iPad; claro y oscuro; texto máximo.
- [ ] VoiceOver, Voice Control, Switch Control y teclado.
- [ ] Reducir transparencia, Aumentar contraste y Reducir movimiento.
- [ ] No publicar Accessibility Nutrition Labels hasta completar esta matriz.
