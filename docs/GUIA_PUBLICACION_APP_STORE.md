# Guía para publicar CasiListo en la App Store

**Escrita para hacerse sin conocimientos técnicos.** Si sabes usar el navegador, copiar y pegar, y conectar un cable a tu iPhone, puedes completar todo lo que falta.

---

## Cómo usar esta guía

- Léela **de arriba hacia abajo la primera vez**. El orden importa: cada etapa deja lista la siguiente.
- Cada etapa tiene la misma estructura:
  - **Qué es** → la explicación en palabras simples.
  - **Por qué importa** → qué pasa si no lo haces.
  - **Qué hacer** → los pasos, uno por uno.
  - **Cómo saber que funcionó** → la señal de que quedó bien.
  - **Si algo falla** → qué revisar.
- Al final hay un **checklist imprimible**, un **glosario** y una lista de **lo que ya está listo** (para que no lo toques sin necesidad).

> **Regla de oro:** nunca borres ni cambies archivos del proyecto "para probar". Todo lo que hay que hacer en esta guía se hace en páginas web (Apple, GitHub, Cloudflare) o en Xcode, no editando archivos.

---

## El mapa: qué falta, en 7 etapas

| # | Etapa                                                           | Dónde se hace | Quién        |
| - | --------------------------------------------------------------- | -------------- | ------------- |
| 0 | Tomar 3 decisiones (correo, titular, fecha)                     | Tu cabeza      | Solo tú      |
| 1 | Cerrar el candado de la web                                     | Cloudflare     | Tú           |
| 2 | ~~Crear la app en App Store Connect~~ **Ya está hecha** | Apple          | —            |
| 3 | Crear la "llave" y guardarla en GitHub                          | Apple + GitHub | Tú           |
| 4 | Subir la primera versión a TestFlight                          | GitHub         | Tú (un clic) |
| 5 | Probar en tu iPhone real                                        | Tu iPhone      | Tú           |
| 6 | Completar la ficha de la App Store                              | Apple          | Tú           |
| 7 | Enviar a revisión de Apple                                     | Apple          | Tú           |

**Todo lo demás ya está hecho.** La app compila, los tests pasan, la web legal está publicada y el robot que sube la app ya está escrito. Lo que falta es *usar* esas piezas.

---

## Antes de empezar: ten esto a mano

| Necesitas                              | Detalle                                                                                                                   | ¿Lo tienes? |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------ |
| Membresía del Apple Developer Program | Activa y pagada (99 USD al año). El equipo es**GKVPN3HBMN**. Sin esto no se puede publicar.                        | ☐           |
| Acceso de administrador al repositorio | https://github.com/Allopze/CasiListo — necesitas poder entrar a**Settings**.                                       | ☐           |
| Tu Mac con Xcode                       | Ya tienes Xcode 27.0 instalado. Sirve.                                                                                    | ☐           |
| Un iPhone con iOS 26 o superior        | **Y su cable.** Es obligatorio: hay cosas (cámara, micrófono, widget) que el simulador no puede probar de verdad. | ☐           |
| Boletas de supermercado reales         | De Jumbo y de Líder, idealmente algo arrugadas y con luz distinta. Se usan en las pruebas.                               | ☐           |
| Los datos de tu cuenta de Apple        | El mismo Apple ID con el que entras a App Store Connect.                                                                  | ☐           |

**Lo que NO necesitas:** no hay que programar, no hay que instalar fastlane, no hay que tocar el número de versión, no hay que crear certificados a mano, no hay que pagar nada extra.

---

## Etapa 0 — Tres decisiones que solo puedes tomar tú

Ninguna de estas las puede resolver un programa. Anótalas en un papel antes de seguir, porque las vas a necesitar en las etapas 1, 3 y 6.

### 1. El correo de soporte

- **Qué es:** la dirección de correo que verá cualquier persona que abra la página de soporte de la app, y la que Apple puede usar para contactarte.
- **Hoy está así:** `allopze@gmail.com` (el valor por defecto del sitio).
- **Decide:** ¿te sirve ese correo o prefieres uno dedicado, por ejemplo `soporte@casilisto.lat`? Si eliges uno dedicado, primero tienes que crearlo y comprobar que recibe correo.
- **Dónde se cambia:** en la Etapa 1, como variable de GitHub.

### 2. El titular del copyright

- **Qué es:** el nombre del dueño de los derechos que aparece en la ficha de la App Store, en la línea "© 2026 ...".
- **Hoy está propuesto así:** `2026 Alejandro López Zelaya`.
- **Decide:** ¿lo dejas como persona natural, o pones el nombre de una empresa si la app va a nombre de una?
- **Dónde se cambia:** en la Etapa 6, al llenar la ficha. El borrador está en `docs/APP_STORE_FICHA_ES_CL.md`.

### 3. La fecha de vigencia de la política de privacidad

- **Qué es:** desde qué día rigen las reglas de privacidad que publicaste.
- **Hoy está así:** `13 de septiembre de 2026`.
- **Decide:** ¿esa fecha es la correcta? Si cambias el contenido de la política, esta fecha debe cambiar también.
- **Dónde se cambia:** en la Etapa 1, como variable de GitHub. El formato es obligatorio: `13 de septiembre de 2026` (día + "de" + mes en minúscula + "de" + año). Si lo escribes distinto, el robot de publicación falla y te avisa.

---

## Etapa 1 — Cerrar el candado de la web

### Qué es

Tu web legal (`https://casilisto.lat`) ya está publicada y funciona. Pero hay un detalle abierto: si alguien escribe la dirección **sin** la "s" de https (`http://casilisto.lat`), la página se muestra igual, sin cifrado. Apple revisa esto y es un descuido que conviene cerrar antes de enviar la app.

### Por qué importa

- La app abre esta web desde sus Ajustes. Un enlace que viaja sin cifrado es exactamente lo que Apple espera que no hagas cuando declaras que tu app no recopila datos.
- Es un ajuste de **un interruptor** en Cloudflare. No se arregla tocando el código ni volviendo a publicar la web.

### Qué hacer

1. Entra a https://dash.cloudflare.com e inicia sesión.
2. Haz clic en el dominio **casilisto.lat**.
3. En el menú de la izquierda, entra a **SSL/TLS**.
4. Entra a **Edge Certificates**.
5. Busca la opción **Always Use HTTPS** y actívala (el interruptor debe quedar en azul/encendido).
6. **Opcional pero recomendado:** en el mismo panel de Cloudflare, revisa las variables del sitio. Si decidiste cambiar el correo de soporte o la fecha de vigencia en la Etapa 0, ahora es el momento de cargarlas en GitHub:
   1. Ve a https://github.com/Allopze/CasiListo/settings/secrets/actions
   2. Pestaña **Variables** → **New repository variable**
   3. Crea las que necesites:
      - Nombre `PUBLIC_SUPPORT_EMAIL` → valor: tu correo de soporte real.
      - Nombre `PUBLIC_POLICY_EFFECTIVE_DATE` → valor: la fecha, con el formato exacto `13 de septiembre de 2026`.
      - Nombre `PUBLIC_SITE_URL` → valor: `https://casilisto.lat` (créala solo si no existe).
   4. Luego ve a la pestaña **Actions**, elige el workflow **Deploy privacy site** y pulsa **Run workflow**. Eso vuelve a publicar la web con los valores nuevos.

> **Si no cambias nada:** la web ya está publicada con el correo y la fecha por defecto, así que puedes saltarte el paso 6 entero y seguir.

### Cómo saber que funcionó

- Escribe en el navegador `http://casilisto.lat` (a propósito, sin la "s"). Debe **saltar sola** a `https://casilisto.lat`. Si se queda en `http://`, el interruptor no quedó activado.
- Abre `https://casilisto.lat/privacy/` y `https://casilisto.lat/support/`: ambas deben cargar.

### Si algo falla

- Si `http://` sigue funcionando: espera unos minutos (Cloudflare tarda en aplicar cambios de zona) y vuelve a probar. Si persiste, revisa que activaste el interruptor en el dominio correcto, no en otra cuenta.
- Si la web deja de cargar después de redesplegar: entra a la pestaña **Actions** de GitHub, abre la corrida de **Deploy privacy site** y mira en qué paso se puso rojo. Si el correo tenía un error de escritura, el robot falla a propósito y te lo dice en el mensaje.

---

## Etapa 2 — Confirmar la app en App Store Connect ✅ YA ESTÁ HECHA

### Qué es

App Store Connect es la página web de Apple donde viven las apps: su ficha, sus versiones y sus pruebas.

**La app ya está creada.** Verificado el 24 de septiembre de 2026:

| Dato      | Valor                                                             |
| --------- | ----------------------------------------------------------------- |
| Nombre    | CasiListo                                                         |
| Bundle ID | `com.allopze.CasiListo`                                         |
| Estado    | **Prepare for Submission** (En preparación para el envío) |

Ese estado es el correcto: es un borrador esperando que lo llenes con la ficha.

### Por qué importa

Sin la app creada no hay dónde subir la compilación ni dónde escribir la ficha. Ya está resuelto, así que **no hay que crear nada**.

### Qué hacer

**Nada. Salta directo a la Etapa 3.**

Solo si quieres comprobarlo con tus propios ojos:

1. Entra a https://appstoreconnect.apple.com → **Apps**.
2. Haz clic en **CasiListo**.
3. Menú lateral → **General → App Information**.
4. Confirma que el **Bundle ID** dice `com.allopze.CasiListo` y que el estado es **Prepare for Submission**.

> **El Bundle ID se muestra con un formato parecido a `XC com allopze CasiListo - com.allopze.CasiListo`.** La parte antes del guion es solo el nombre del identificador dentro de tu cuenta de desarrollador; lo que importa es lo que va **después** del guion: `com.allopze.CasiListo`. Si coincide, es tu app.

> **Si no ves el menú lateral:** agranda la ventana del navegador o reduce el zoom con `Cmd` + `-`. El menú se esconde cuando la ventana es angosta.

> ### ⚠️ No borres esta app
>
> Es tentador pensar que "hay que empezar de cero", pero borrarla sería un error grave. Apple advierte que al eliminar una app:
>
> - **Pierdes la propiedad del nombre.** Otra persona podría quedarse con "CasiListo" y tú ya no podrías recuperarlo.
> - **El SKU no se puede reutilizar** en tu organización.
> - **Si alguna vez se subió una compilación, el Bundle ID `com.allopze.CasiListo` queda inutilizable para siempre.** Ese identificador está escrito en todo el proyecto: quemarlo dejaría la app sin poder publicarse con la configuración actual.
>
> Todo lo que necesitas cambiar (nombre, subtítulo, categorías, descripción, URLs) **es editable** dentro de la ficha. No hay ningún motivo para borrar y volver a crear.
>
> **Si aun así tuvieras que borrarla** (por ejemplo, un registro duplicado con otro Bundle ID), estos son los requisitos de Apple: ser **Account Holder o Admin**, que la app **no** esté en estado Ready for Review / Waiting for Review / In Review / Metadata Rejected / Rejected, y haberla quitado de venta en todos los países. Los pasos son: **Pricing and Availability → Availability → Edit → deseleccionar todos los territorios**, y después **General → App Information → Additional Information → Remove App**.

### Cómo saber que funcionó

- La app **CasiListo** aparece en la lista de **Apps** con estado **Prepare for Submission**.
- El Bundle ID es `com.allopze.CasiListo`.

### Si algo falla

- **No aparece ninguna app en la lista:** entonces sí habría que crearla. El formulario es **Apps → + → New App**, con Platform iOS, nombre `CasiListo`, idioma Spanish (Chile), Bundle ID `com.allopze.CasiListo` y SKU `CASILISTO001`.
- **El Bundle ID no aparece en la lista desplegable:** el identificador no está registrado en tu cuenta de desarrollador. Se crea en https://developer.apple.com/account → **Certificates, Identifiers & Profiles → Identifiers → + → App IDs → App**, descripción "CasiListo" y Bundle ID `com.allopze.CasiListo`.

---

## Etapa 3 — Crear la llave para que GitHub pueda subir la app

### Qué es

Esta es la parte que más asusta y la más simple en realidad.

Tu app no se sube a mano desde tu Mac: la sube un robot que vive en GitHub (lo configuramos en la Etapa 4). Para que Apple acepte archivos de ese robot, hay que darle una **llave de acceso** (Apple la llama "App Store Connect API Key").

Son tres datos:

| Dato                  | Qué es                                        | Ejemplo de forma                                         |
| --------------------- | ---------------------------------------------- | -------------------------------------------------------- |
| **Key ID**      | El nombre de la llave                          | `2X9ABCD3EF` (10 caracteres)                           |
| **Issuer ID**   | El identificador de tu cuenta de desarrollador | Un texto largo con guiones (UUID)                        |
| **Private Key** | El archivo de la llave en sí                  | Un archivo`.p8` que se descarga **una sola vez** |

### Por qué importa

Sin estos tres datos, el robot de GitHub se niega a empezar (lo comprueba a propósito antes de gastar tiempo compilando). Es el bloqueador técnico principal que queda.

### Qué hacer — Parte A: crear la llave en Apple

1. Entra a https://appstoreconnect.apple.com
2. Ve a **Users and Access** (Usuarios y acceso).
3. Entra a la pestaña **Integrations** (Integraciones).
4. En la lista de la izquierda elige **App Store Connect API** → **Team Keys** (Llaves de equipo).
5. Haz clic en **+** para generar una llave nueva.
6. **Name:** `GitHub Actions`.
7. **Access/Role:** elige **App Manager**.
8. Pulsa **Generate** (Generar).
9. **MUY IMPORTANTE:** aparece un botón **Download** para descargar el archivo `.p8`. **Solo puedes descargarlo una vez.** Descárgalo y guárdalo en un lugar seguro (por ejemplo, en tu carpeta de Documentos, no en Descargas). Si lo pierdes, tendrás que crear otra llave y repetir esta etapa.
10. **Anota en un papel** dos datos que aparecen en esa misma pantalla:
    - El **Key ID** (el código de 10 caracteres que acompaña a la llave que creaste).
    - El **Issuer ID** (aparece arriba de la tabla de llaves, es un texto largo con guiones; es el mismo para todas tus llaves).

### Qué hacer — Parte B: guardar los tres datos en GitHub

1. Abre en una aplicación de texto el archivo `.p8` que descargaste (con TextEdit, en modo texto plano). Verás algo así:

   ```text
   -----BEGIN PRIVATE KEY-----
   MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
   ...muchas líneas más...
   -----END PRIVATE KEY-----
   ```
2. **Selecciona todo el contenido y cópialo** (incluidas las líneas `BEGIN` y `END`).
3. Ve a https://github.com/Allopze/CasiListo/settings/secrets/actions
4. Pestaña **Secrets** (Secretos) → **New repository secret**. Crea los tres, uno por uno:

   | Nombre exacto del secreto | Qué pegas                                                                   |
   | ------------------------- | ---------------------------------------------------------------------------- |
   | `ASC_KEY_ID`            | El Key ID de 10 caracteres                                                   |
   | `ASC_ISSUER_ID`         | El Issuer ID largo con guiones                                               |
   | `ASC_PRIVATE_KEY`       | **Todo** el contenido del archivo `.p8`, con las líneas BEGIN y END |
5. Después de crear cada uno, GitHub no te dejará volver a verlo (solo reemplazarlo). Es normal.

> **Ojo con los espacios:** al pegar el contenido del `.p8`, no agregues espacios ni líneas vacías al principio o al final. Copia y pega tal cual.

### Cómo saber que funcionó

- En https://github.com/Allopze/CasiListo/settings/secrets/actions ves los tres secretos listados con nombres `ASC_KEY_ID`, `ASC_ISSUER_ID` y `ASC_PRIVATE_KEY` (GitHub muestra la fecha de actualización, no el valor).

### Si algo falla

- **No encuentras "Integrations":** tu Apple ID no tiene permiso de administrador en el equipo de desarrollo. Necesitas el rol **Account Holder** o **Admin**.
- **El botón Download no aparece o ya cerraste la página:** la llave no se puede recuperar. Genera una nueva y repite la Parte A. Después borra la llave vieja (botón de revocar) para no dejar accesos abiertos.
- **No encuentras Settings en GitHub:** no tienes permisos de administrador en el repositorio. Pídelos.

---

## Etapa 4 — Subir la primera versión a TestFlight

### Qué es

TestFlight es el "ensayo general" de Apple: una versión de la app que se instala en tu iPhone **como si viniera de la App Store**, pero antes de que nadie más pueda verla. Es obligatorio pasar por aquí antes de enviar la app a revisión.

El robot que hace el trabajo se llama **Release to TestFlight** y ya está escrito y configurado. Tú solo lo aprietas.

### Por qué importa

- Es la única forma de comprobar que la app **firmada de verdad** funciona en un iPhone de verdad.
- Nunca se ha ejecutado. Es el mayor desconocido del proyecto: hasta que corra en verde, nadie sabe si el proceso de publicación está realmente completo.

### Qué hacer

1. Entra a https://github.com/Allopze/CasiListo/actions
2. En la lista de la izquierda, haz clic en **Release to TestFlight**.
3. A la derecha, pulsa el botón **Run workflow**.
4. Se abre un pequeño formulario:
   - **Use workflow from:** `main`.
   - **Build number:** déjalo **vacío**. El robot se inventa un número nuevo cada vez automáticamente (y eso es justo lo que Apple necesita para no rechazar una subida repetida).
5. Pulsa el botón verde **Run workflow**.
6. Aparecerá una corrida nueva en la lista. Haz clic en ella para ver el progreso. Verás una lista de pasos que se van poniendo en verde:
   1. **Select Xcode 26** — prepara el ordenador de GitHub.
   2. **Validate Xcode, secrets and version** — revisa que los tres secretos de la Etapa 3 existan.
   3. **Prepare App Store Connect key** — escribe la llave.
   4. **Archive Release** — compila y firma la app.
   5. **Export IPA** — empaqueta el archivo que se sube a Apple.
   6. **Upload to TestFlight** — lo envía a Apple.
   7. **Remove App Store Connect key** — borra la llave del ordenador por seguridad (siempre corre, incluso si algo falló antes).

### Cómo saber que funcionó

1. En GitHub: la corrida termina con un **círculo verde** y el texto "Success". Si algún paso se queda rojo, la app no se subió.
2. En Apple: entra a https://appstoreconnect.apple.com → **My Apps** → **CasiListo** → pestaña **TestFlight**. Debe aparecer una compilación nueva. Al principio dice **"Processing"** (procesando); cuando termina, cambia a **"Ready to Submit"** o queda disponible para probar. Si el procesamiento termina en error, Apple te manda un correo explicando por qué.

### Si algo falla

| Síntoma en el paso rojo                                    | Qué significa                                                      | Qué hacer                                                                                                                                  |
| ----------------------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Falla en "Validate Xcode, secrets and version"              | Uno de los tres secretos está vacío o mal escrito                 | Repite la Etapa 3 y revisa los nombres exactos                                                                                              |
| Falla en "Archive Release" mencionando firma o provisioning | La llave no tiene permiso suficiente                                | Verifica que la llave se creó con rol**App Manager**                                                                                 |
| Falla en "Upload to TestFlight"                             | Suele ser un problema de la llave                                   | Revisa que`ASC_PRIVATE_KEY` tenga el contenido **completo**, con las líneas BEGIN y END                                            |
| Apple rechaza la compilación después de subirla           | Puede ser un número de compilación repetido o un dato de la ficha | En la corrida siguiente, escribe en**Build number** un número mayor al último que hayas subido (por ejemplo, el doble del anterior) |

> **Truco:** en la página de la corrida, cada paso se puede desplegar para leer el detalle. Busca la primera línea que diga `error:` — ahí está la causa real. Si no entiendes el mensaje, cópialo y pásaselo a alguien técnico junto con el enlace de la corrida.

---

## Etapa 5 — Probar en tu iPhone real

### Qué es

Esta es la parte que **no se puede saltar ni simular**. Hay funciones que solo se comportan de verdad en un teléfono: la cámara, el micrófono, el widget y las interrupciones (una llamada entrante mientras grabas una nota de voz).

Nada de esto se ha probado todavía. El iPhone que estaba emparejado a la Mac figura como "no disponible" desde el 18 de septiembre de 2026, así que esta etapa está **completamente pendiente**.

### Por qué importa

- Si la cámara falla al leer una boleta real, es lo primero que va a notar cualquier usuario. Y es la función estrella de la app.
- Apple puede rechazar la app si algo prometido en la descripción no funciona.

### Paso previo: instalar la app desde TestFlight

1. En tu iPhone, abre la **App Store**, busca **TestFlight** e instálala (es gratis, de Apple).
2. En un navegador, entra a https://appstoreconnect.apple.com → **My Apps** → **CasiListo** → **TestFlight**.
3. En la sección **Internal Testing**, crea un grupo (por ejemplo "Interno") y **añádete a ti mismo** como probador usando tu Apple ID.
4. Acepta la invitación (te llega por correo o aparece dentro de la app TestFlight).
5. Instala **CasiListo** desde TestFlight. Ahora la tienes en el teléfono, con la misma firma que tendrá la versión publicada.

### Las pruebas, una por una

Marca cada casilla solo cuando la hayas hecho **en el teléfono**, no en el simulador.

#### 1. Cámara y lectura de boletas

- ☐ Abre la app, crea una lista, agrega un par de productos.
- ☐ Al cerrar la compra, elige **escanear la boleta** con la cámara.
- ☐ Usa una boleta **real de Jumbo**. Debe reconocer productos y precios y mostrártelos para revisar antes de guardar.
- ☐ Repite con una boleta **real de Líder**.
- ☐ Repite con una boleta **arrugada** y con **poca luz**.
- ☐ **Deniega** el permiso de cámara cuando la app lo pida y comprueba que la app te ofrece la alternativa (elegir la foto desde tus imágenes) en vez de quedarse pegada.
- ☐ Luego ve a **Ajustes del iPhone → CasiListo → Cámara** y **revoca** el permiso con la app ya instalada. Vuelve a abrir la app: no debe romperse.

#### 2. Micrófono y notas de voz

- ☐ En un producto de la lista, agrega una **nota de voz**.
- ☐ Prueba **permitir**, luego **denegar** y luego **revocar** el micrófono en **Ajustes del iPhone → CasiListo → Micrófono**.
- ☐ Graba con la app y **recibe una llamada entrante** en medio de la grabación: la nota no debe quedar corrupta.
- ☐ Conecta **audífonos o Bluetooth** y vuelve a grabar.
- ☐ Verifica que la grabación **corta a los 30 segundos** como máximo.

#### 3. Widget

- ☐ En la pantalla de inicio del iPhone, mantén presionado un espacio vacío → **+** → busca **CasiListo** → agrega el widget en tamaño **pequeño** y luego **mediano**.
- ☐ Prueba el widget con la **lista vacía**.
- ☐ Prueba con la lista **con productos pendientes**.
- ☐ Toca el widget y marca un producto como comprado desde ahí. Luego abre la app: el cambio debe estar reflejado.
- ☐ Agrega también el widget a la **pantalla de bloqueo**.

#### 4. Enlace directo (casilisto://)

- ☐ Abre **Safari** y escribe en la barra de direcciones: `casilisto://list` → debe abrir CasiListo en la lista.
- ☐ Repite con la app **completamente cerrada** (deslizándola hacia arriba en el selector de apps).
- ☐ Escribe una dirección **inventada** (por ejemplo `casilisto://nada`): la app no debe romperse ni cambiar de pantalla.

#### 5. Exportar historial (CSV)

- ☐ Desde el historial, exporta el archivo CSV.
- ☐ Ábrelo en **Apple Numbers**, en **Microsoft Excel** y en **Google Sheets**.
- ☐ Si puedes, hazlo con un producto que tenga **comillas, comas o saltos de línea** en el nombre o la nota, para confirmar que el archivo no se desarma.

#### 6. Rendimiento con muchos datos

- ☐ Carga alrededor de **1.000 productos** en una lista (puedes importar desde un archivo JSON o agregarlos rápido).
- ☐ Recorre la app: debe responder sin tirones.
- ☐ Repite con **5.000 productos**.
- ☐ Si algo se siente lento o se congela, **anota exactamente qué pantalla y qué acción** lo provoca. Eso es información valiosa.

#### 7. Accesibilidad

Estas pruebas se hacen desde **Ajustes del iPhone → Accesibilidad**:

- ☐ **Texto grande (Dynamic Type):** entra a *Pantalla y tamaño de texto → Texto más grande* y llévalo al **máximo**. Abre la app y recorre todas las pantallas: ningún botón ni texto debe quedar cortado o fuera de la pantalla.
- ☐ **VoiceOver:** actívalo en *VoiceOver*. Con los dedos, recorre Compra, Catálogo, Historial y Ajustes. Debe poder leerse todo y llegar a todos los botones.
- ☐ **Control por voz y Control por interruptor:** actívalos y comprueba que puedes accionar los botones principales.
- ☐ **Visión:** activa *Reducir transparencia*, *Aumentar contraste* y *Reducir movimiento* (uno por uno). La app debe verse bien y no parpadear ni animarse de más.
- ☐ **Modo claro y oscuro:** cambia entre ambos en **Ajustes → Pantalla y brillo**. Hazlo también en un iPhone pequeño (tipo SE) y en uno grande (Pro Max), si tienes acceso a ambos.

> **No declares funciones de accesibilidad en la ficha de la App Store hasta que esta lista esté completa.** Apple puede rechazar la app si declaras cosas que no se cumplen.

### Cómo saber que funcionó

- ☐ Todas las casillas anteriores marcadas, **sin excepciones anotadas**.
- Si encontraste un problema, no lo dejes pasar: es mil veces más barato arreglarlo antes de enviar que después de un rechazo.

---

## Etapa 6 — Completar la ficha de la App Store

### Qué es

La "ficha" es la página de la app en la tienda: nombre, descripción, fotos, categoría, edad mínima y declaraciones de privacidad. **Ya está escrita** en el archivo `docs/APP_STORE_FICHA_ES_CL.md`. Aquí solo hay que copiarla a App Store Connect y decidir tres cosas.

### Por qué importa

Sin ficha completa, Apple no deja enviar la app a revisión. Y una ficha con datos incorrectos es motivo de rechazo.

### Qué hacer

1. Entra a https://appstoreconnect.apple.com → **My Apps** → **CasiListo**.
2. Entra a **App Information** (Información de la app) y completa:
   - **Nombre:** `CasiListo`.
   - **Subtítulo:** `Casi listo para ir al súper.`
   - **Categoría principal:** Productividad. **Categoría secundaria:** Compras.
   - **Copyright:** el titular que decidiste en la Etapa 0.
   - **Privacy Policy URL:** `https://casilisto.lat/privacy/`
3. Entra a la versión **1.0** y completa:
   - **Descripción:** copia el bloque de descripción del archivo `docs/APP_STORE_FICHA_ES_CL.md`.
   - **Palabras clave:** `lista,compras,supermercado,despensa,boleta,precios,catalogo,mercado,ahorro`
   - **URL de soporte:** `https://casilisto.lat/support/`
   - **Notas para App Review:** copia el bloque de notas del mismo archivo. Explica que no se necesita cuenta y que todo se procesa en el teléfono.
4. **Clasificación por edad:** entra a la sección correspondiente y **completa el cuestionario** que Apple muestra. No pongas una clasificación "a mano": responde las preguntas y deja que Apple calcule el resultado.
5. **App Privacy (privacidad):** completa esta sección con dos declaraciones:
   - **Tracking:** No (la app no rastrea al usuario).
   - **Data Collection:** **No se recopilan datos** (Data Not Collected).

   > **Antes de marcar esto:** haz la comprobación del punto 6 de aquí abajo. No es un trámite de fe: hay que verificarlo.
   >
6. **Genera el informe de privacidad del binario** (esto lo hace Xcode, no Apple):
   1. Abre **Xcode** en tu Mac.
   2. En el menú superior: **Window → Organizer**.
   3. Busca en la lista el archive de CasiListo (el que se generó al subir a TestFlight; si no aparece, ejecuta la Etapa 4 de nuevo desde tu Mac).
   4. Selecciónalo y pulsa **Generate Privacy Report**.
   5. Ábrelo y revisa que **no aparezcan** datos recopilados ni herramientas de terceros que rastreen. Si aparece algo inesperado, **no declares "No se recopilan datos"** y consulta con alguien técnico antes de seguir.
7. **Capturas de pantalla:** súbelas en la sección **Screenshots** de la versión.
   - Las cinco imágenes ya están hechas, en tu Mac, en la carpeta:
     `/Users/allopze/dev/CasiListo/build/app-store-submission/`
     (para abrirla: abre la app **Terminal** y pega `open /Users/allopze/dev/CasiListo/build/app-store-submission` — se abre en el Finder).
   - Los archivos, en este orden, son:
     1. `01-menu-listas.png` — el menú de listas
     2. `02-lista-activa.png` — una lista en uso
     3. `03-catalogo.png` — el catálogo
     4. `04-captura-boleta.png` — la captura de boleta
     5. `05-historial.png` — el historial
   - **Ya están verificadas:** miden 1320 × 2868 (el tamaño exacto que Apple pide para iPhone 6,9") y **no tienen canal de transparencia**, que es lo que Apple rechaza. No hace falta convertirlas ni redimensionarlas.
   - Si la carpeta estuviera vacía o las imágenes no te convencieran, se pueden volver a generar. Abre Terminal, pega esto y pulsa Enter:
     ```bash
     cd /Users/allopze/dev/CasiListo && ci/capture-screenshots.sh --devices "iPhone 18 Pro Max" --appearances light --text-sizes default --out build/app-store-screenshots
     ```

     Después elige las cinco mejores de la carpeta `build/app-store-screenshots`.
   - **iPad no hace falta:** la app es solo para iPhone.

### Cómo saber que funcionó

- Todas las secciones de la versión 1.0 muestran un check verde, sin avisos pendientes.
- La sección **App Privacy** queda guardada como *No data collected* y *No tracking*.

### Si algo falla

- **"El nombre ya está en uso":** elige un nombre público distinto en la ficha (por ejemplo `CasiListo — Lista de compras`), aunque el nombre interno siga siendo CasiListo.
- **Las capturas son rechazadas:** revisa que subiste los cinco PNG de la carpeta correcta y que no las editaste después (si las abres y las vuelves a guardar con un editor, pueden adquirir transparencia). Vuelve a generarlas con el comando de arriba.
- **No encuentras el archive en Xcode:** el archive vive en el Mac donde se compiló. Si subiste la app desde GitHub, ese archive está en los servidores de GitHub, no en tu Mac. En ese caso puedes generar uno local: abre el proyecto `CasiListo.xcodeproj` en Xcode, selecciona el esquema **CasiListo**, elige **Any iOS Device** arriba, y usa el menú **Product → Archive**.

---

## Etapa 7 — Enviar a revisión de Apple

### Qué es

El momento final: le entregas la app y la ficha a Apple para que un revisor la pruebe y decida si la publica.

### Qué hacer

1. En App Store Connect, dentro de **CasiListo → versión 1.0**, selecciona la **compilación** que subiste (el número de build que creó el robot en la Etapa 4). Debe estar en estado "Ready to Submit".
2. Responde la pregunta de **Export Compliance** (cifrado): ya está declarado en la app que **no se usa cifrado no exento**, así que puedes responder que no. Si Apple muestra la pregunta, la respuesta es "No" / "La app no usa cifrado".
3. Revisa que no quede nada en rojo o con aviso en la página de la versión.
4. Pulsa **Add for Review** (Añadir para revisión) y luego **Submit** (Enviar).
5. Apple te enviará correos con el estado. Si el revisor encuentra un problema, te escribe en **App Store Connect → Resolution Center** explicando qué corregir.

### Cómo saber que funcionó

- El estado de la versión cambia a **"Waiting for Review"** (esperando revisión).
- Si pasa a **"In Review"**, Apple ya la está revisando.

### Si algo falla

- **La compilación no aparece para seleccionar:** todavía está procesándose, o quedó en error. Revisa la pestaña **TestFlight**.
- **Un aviso no te deja continuar:** pásate por la Etapa 6 y completa la sección que falte. Los avisos más comunes son la clasificación por edad y las capturas.
- **Apple rechaza la app:** lee con calma el mensaje del Resolution Center. Casi siempre indica exactamente qué pantalla o qué dato no le gustó. Arreglado eso, se sube una versión nueva (Etapa 4) y se vuelve a enviar.

---

## Detalles menores (no bloquean la publicación)

Estos puntos pueden esperar. No impiden publicar, pero conviene anotarlos:

- ☐ **Logo interno incompleto:** el archivo del logo (`AppLogo.imageset`) tiene solo la versión 1x; las versiones para pantallas de alta densidad (2x y 3x) están declaradas pero vacías. Afecta solo a un logo de marca dentro de la app, no al icono de la App Store (que ya está correcto y verificado).
- ☐ **No hay archivo de licencia (`LICENSE`)** en el repositorio. El README menciona que el proyecto es de uso personal/educativo. Si algún día lo compartes públicamente, conviene definir qué permite y qué no.
- ☐ **No hay registro de cambios (`CHANGELOG`)** ni notas de "qué probar" para TestFlight. Útil cuando lleguen las versiones 1.1, 1.2…
- ☐ **Enlace roto en `CLAUDE.md`:** apunta a un documento (`AUDITORIA_LANZAMIENTO_APP_STORE_2026-08-12.md`) que ya no existe en el repositorio. No afecta a la app.
- ☐ **El simulador de iOS 26 no está instalado en tu Mac.** Los tests pasan igual (se corrieron en iOS 26 y 27 el 21 de septiembre), pero si algún día quieres repetir la prueba del sistema mínimo, hay que instalarlo desde Xcode → Settings → Components.

---

## Apéndice A — Checklist imprimible

Marca solo cuando esté **hecho y verificado**, no cuando lo hayas intentado.

**Decisiones**

- ☐ Correo de soporte decidido
- ☐ Titular del copyright decidido
- ☐ Fecha de vigencia de la política decidida

**Web**

- ☐ "Always Use HTTPS" activado en Cloudflare
- ☐ `http://casilisto.lat` salta a `https://`
- ☐ `/privacy/` y `/support/` cargan

**App Store Connect**

- ✅ App creada con el Bundle ID `com.allopze.CasiListo` (estado "Prepare for Submission")
- ☐ Llave API creada (rol App Manager) y archivo `.p8` guardado a salvo
- ☐ Los tres secretos cargados en GitHub (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`)

**Subida**

- ☐ Workflow "Release to TestFlight" ejecutado con éxito (círculo verde)
- ☐ La compilación aparece y termina de procesarse en TestFlight

**Pruebas en el iPhone**

- ☐ Cámara con boletas reales (Jumbo, Líder, arrugada, poca luz)
- ☐ Permisos de cámara: permitir, denegar, revocar
- ☐ Micrófono: permitir, denegar, revocar, llamada entrante, audífonos, corte a 30 s
- ☐ Widget: pequeño, mediano, pantalla de bloqueo, vacío y con datos
- ☐ Enlace `casilisto://list` con la app abierta y cerrada; enlace inválido
- ☐ CSV abierto en Numbers, Excel y Google Sheets
- ☐ Rendimiento con 1.000 y 5.000 productos
- ☐ Texto al máximo sin cortes
- ☐ VoiceOver completo
- ☐ Control por voz y por interruptor
- ☐ Reducir transparencia, aumentar contraste, reducir movimiento
- ☐ Modo claro y oscuro en pantalla pequeña y grande

**Ficha**

- ☐ Descripción, subtítulo, categorías y palabras clave cargadas
- ☐ URLs de privacidad y soporte registradas
- ☐ Cuestionario de clasificación por edad completado
- ☐ Privacy Report generado y revisado
- ☐ App Privacy declarado (sin tracking, sin datos recopilados)
- ☐ Las 5 capturas subidas

**Envío**

- ☐ Compilación seleccionada en la versión 1.0
- ☐ Export Compliance respondido
- ☐ App enviada (estado "Waiting for Review")

---

## Apéndice B — Glosario para no técnicos

| Palabra                                  | Qué significa en simple                                                                                            |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **App Store Connect**              | La página web de Apple donde se administra tu app: su ficha, sus versiones y sus pruebas.                          |
| **TestFlight**                     | El "ensayo general" de Apple. Te deja instalar la app en tu iPhone antes de publicarla.                             |
| **Bundle ID**                      | El documento de identidad de la app. El de CasiListo es`com.allopze.CasiListo`. Nunca cambia.                     |
| **Build number**                   | El número de "intento" de subida. Cada vez que subes la app, ese número debe ser mayor. El robot lo calcula solo. |
| **Archive**                        | El paquete que Xcode produce al compilar para publicar. Es la materia prima de la subida.                           |
| **IPA**                            | El archivo final que se envía a Apple. Es el equivalente a un`.zip` de la app firmada.                           |
| **Firma (signing)**                | El sello digital que dice que la app es tuya y no fue alterada. Se hace automáticamente.                           |
| **Provisioning / perfil**          | El permiso que Apple emite para que tu app pueda instalarse en dispositivos. También es automático.               |
| **API Key (.p8)**                  | La "llave" que le da permiso a GitHub para subir la app en tu nombre. Se descarga una sola vez.                     |
| **Issuer ID**                      | El identificador de tu cuenta de desarrollador. Es el mismo para todas tus llaves.                                  |
| **Workflow / Actions**             | Un robot que vive en GitHub y ejecuta tareas largas por ti (compilar, firmar, subir).                               |
| **Secret**                         | Un dato privado guardado en GitHub (como una contraseña). Se escribe una vez y no se puede volver a leer.          |
| **Privacy Manifest**               | Un archivo dentro de la app que declara qué datos toca. CasiListo ya los tiene y están validados.                 |
| **Privacy Report**                 | El informe que Xcode genera del binario para confirmar que la app no recopila datos.                                |
| **Nutrition Labels / App Privacy** | Las "etiquetas de alimento" de la privacidad: la lista de qué datos toma tu app.                                   |
| **App Review**                     | El equipo de Apple que prueba la app antes de publicarla.                                                           |
| **Resolution Center**              | El buzón dentro de App Store Connect donde Apple te escribe si rechaza la app.                                     |
| **Deployment target**              | La versión mínima de iOS que puede instalar la app. CasiListo pide**iOS 26**.                               |
| **Entitlement**                    | Un permiso especial de iOS, como compartir datos entre la app y su widget. CasiListo usa uno (App Group).           |
| **App Group**                      | La carpeta compartida entre la app y el widget para que ambos vean la misma lista.                                  |
| **Cloudflare**                     | La empresa que sirve tu web legal (`casilisto.lat`) y donde está el interruptor del candado https.               |

---

## Apéndice C — Lo que ya está listo (no lo toques)

Para que no pierdas tiempo revisando cosas que ya están resueltas:

- ✅ **La app ya existe en App Store Connect:** nombre `CasiListo`, Bundle ID `com.allopze.CasiListo`, estado "Prepare for Submission" (verificado el 24-09-2026). No hay que crearla ni borrarla.
- ✅ **Identidad de la app:** Bundle ID `com.allopze.CasiListo`, equipo de desarrollo `GKVPN3HBMN`, firma automática. Sin datos de ejemplo ni pendientes.
- ✅ **Icono de la App Store:** el icono mide 1024 × 1024, **no tiene transparencia** (verificado) y tiene variantes para modo oscuro y tintado.
- ✅ **Las 5 capturas:** miden 1320 × 2868, **sin transparencia** (verificado), listas para subir.
- ✅ **Privacidad:** la app y el widget incluyen su manifiesto de privacidad, validado automáticamente. La declaración de cifrado ya está puesta en "no usa cifrado".
- ✅ **Web legal:** publicada y funcionando en `https://casilisto.lat` con política de privacidad y soporte. El correo de soporte es real.
- ✅ **Tests:** la suite pasa (228 aprobadas, 0 fallidas) tanto en iOS 26 como en iOS 27.
- ✅ **Número de versión:** no hay que tocarlo. El robot calcula el número de compilación solo.
- ✅ **El robot de publicación:** el workflow "Release to TestFlight" ya está escrito y hace todo el proceso (compilar, firmar, empaquetar y subir) de una sola pasada.
- ✅ **La ficha redactada:** el texto de descripción, subtítulo y palabras clave ya está escrito en `docs/APP_STORE_FICHA_ES_CL.md`.

---

## Apéndice D — Documentos relacionados

| Documento                              | Para qué sirve                                                                                                    |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `docs/VALIDACION_LANZAMIENTO.md`     | El checklist técnico original, con fechas de lo ya medido. Es la referencia "oficial" del estado del lanzamiento. |
| `docs/APP_STORE_FICHA_ES_CL.md`      | El texto exacto de la ficha para copiar y pegar.                                                                   |
| `privacy-site/README.md`             | Cómo se publica y actualiza la web legal.                                                                         |
| `docs/GUIA_PUBLICACION_APP_STORE.md` | Este documento.                                                                                                    |
