# CasiListo Web

Las tres páginas que App Store Connect exige para publicar CasiListo: portada, política de privacidad y soporte. HTML y CSS a mano, sin dependencias; `npm run build` deja en `dist/` una carpeta estática lista para cualquier hosting.

Dominio en producción: `https://casilisto.lat`, servido por el Worker de solo assets `casilisto-privacy` (Cloudflare Workers, no Pages). Es el mismo que la app lleva compilado en [AppSupportLinks.swift](../CasiListo/Services/AppSupportLinks.swift); si cambia uno, cambia el otro y deja una redirección 301 desde el anterior.

## Comandos

Requiere Node 18 o superior (solo para compilar; el sitio publicado no ejecuta JavaScript).

```bash
npm run build   # genera dist/ (borra la anterior)
npm test        # valida dist/: hay que compilar antes
npm run dev     # sirve dist/ en http://localhost:3000
```

## Qué hace el build

- Interpola los `{{PLACEHOLDER}}` de `src/*.html` con [site.config.mjs](site.config.mjs) y falla si queda alguno sin resolver.
- Copia `src/assets/` y `src/public/` filtrando `.DS_Store`.
- Renombra `main.css` a `main.<hash>.css`: `_headers` lo sirve como inmutable por un año, así que el nombre tiene que cambiar con el contenido. Íconos e imágenes no llevan hash y se cachean un día.
- Genera `robots.txt` y `sitemap.xml` con URLs absolutas; `lastmod` es la fecha de la política, no la del build.

## Qué comprueba `npm test`

- Que canonical, `og:url` y `og:image` sean absolutas y coincidan con `PUBLIC_SITE_URL`.
- Que cada enlace interno (incluidos los `#fragmentos` entre páginas) exista en `dist/`.
- Un solo `<h1>` por página, sin saltos de nivel, `alt` y `width/height` en cada imagen, sin JavaScript, sin recursos de terceros, sin estilos inline.
- Que la política cite literalmente los textos de permisos de `site.config.mjs` y los rótulos de la app («Exportar mis datos», «Escanear boleta», etc.).
- Contraste WCAG calculado **leyendo los tokens del CSS publicado** (texto ≥ 7:1, secundario y enlaces ≥ 4.5:1, en claro y oscuro, sobre las tres superficies).
- Que toda clase definida en el CSS se use en alguna página y viceversa.

## Configuración

| Variable | Por defecto | Notas |
| --- | --- | --- |
| `PUBLIC_SITE_URL` | `https://casilisto.lat` | Origen https sin ruta; el build falla si no lo es |
| `PUBLIC_SUPPORT_EMAIL` | `allopze@gmail.com` | El build falla si contiene «ejemplo» o no es un correo |
| `PUBLIC_APP_VERSION` | `1.0` | Debe coincidir con `MARKETING_VERSION` del proyecto Xcode |
| `PUBLIC_POLICY_LAST_UPDATED` | `13 de septiembre de 2026` | Formato «D de mes de AAAA»; se convierte a ISO para el sitemap |
| `PUBLIC_POLICY_EFFECTIVE_DATE` | igual a la anterior | |

El deploy es `wrangler deploy` desde esta carpeta, con `wrangler.jsonc` apuntando a `dist/`; las variables anteriores se resuelven en el build, no en el panel. Cualquier otro hosting estático sirve igual: sube `dist/` a la raíz. Las cabeceras de seguridad viven en `src/public/_headers` (formato Cloudflare/Netlify); en Nginx hay que replicarlas con `add_header`.

## Estructura

```text
site.config.mjs        valores y validaciones (único lugar)
scripts/build.mjs      compila a dist/
scripts/test.mjs       valida dist/
scripts/dev.mjs        servidor estático local
src/index.html         portada
src/privacy.html       política de privacidad
src/support.html       soporte y preguntas frecuentes
src/assets/css/        main.css (tokens tomados de Theme.swift)
src/assets/icons/      favicon.svg
src/assets/images/     appicon-240 (portada), appicon-512 (Open Graph), apple-touch-icon (180)
src/public/404.html    página 404 legible
src/public/_headers    cabeceras de seguridad y caché (HSTS)
```

## Antes de publicar una versión nueva de la app

1. Si cambió algún `INFOPLIST_KEY_NS*UsageDescription` en `project.pbxproj`, copia el texto literal a `site.config.mjs`.
2. Si cambió qué guarda la app, dónde, o los rótulos de Ajustes/Historial, actualiza `privacy.html` (el test falla si desaparece un rótulo citado).
3. Sube `PUBLIC_APP_VERSION` y `PUBLIC_POLICY_LAST_UPDATED`.
4. `npm run build && npm test`.
5. Comprueba que la ficha en App Store Connect siga declarando *Tracking: No* y *Data Not Collected*.

Después de desplegar, ejecuta desde una red con DNS público:

```bash
PUBLIC_WWW_URL="https://www.casilisto.lat" \
PUBLIC_OLD_SITE_URL="https://casilisto-privacy.pages.dev" \
../ci/validate-public-site.sh
```

Las variables de hostname son opcionales; el script siempre comprueba las
rutas canónicas, HTTPS y las cabeceras de seguridad.

## Checklist para App Store Connect

- [ ] `/`, `/privacy/` y `/support/` responden 200 por https.
- [ ] Privacy Policy URL = `<dominio>/privacy/`; Support URL = `<dominio>/support/`.
- [ ] El botón de correo de soporte abre un correo al buzón real.
- [ ] Revisado en iPhone (390 y 430 px), claro y oscuro, y con zoom 200 % sin scroll horizontal.
- [ ] `npm test` en verde en el mismo commit que se publica.
