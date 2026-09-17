import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { siteConfig } from "../site.config.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const distDir = resolve(__dirname, "..", "dist");

let failures = 0;

function assert(condition, message) {
  if (!condition) {
    failures++;
    console.error(`FALLA  ${message}`);
  }
}

if (!existsSync(distDir)) {
  console.error("No existe dist/: corre `npm run build` antes de `npm test`.");
  process.exit(1);
}

// 1. Salida del build ---------------------------------------------------------

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

const distFiles = walk(distDir).map((f) => f.slice(distDir.length + 1));
for (const required of ["index.html", "privacy/index.html", "support/index.html", "404.html", "robots.txt", "sitemap.xml", "_headers", "assets/icons/favicon.svg", "assets/images/appicon-240.png", "assets/images/appicon-512.png", "assets/images/apple-touch-icon.png"]) {
  assert(distFiles.includes(required), `falta dist/${required}`);
}
assert(!distFiles.some((f) => f.endsWith(".DS_Store")), "dist/ contiene .DS_Store");

const cssFiles = distFiles.filter((f) => /^assets\/css\/main\.[0-9a-f]{10}\.css$/.test(f));
assert(cssFiles.length === 1, `esperaba exactamente un assets/css/main.<hash>.css, hay ${cssFiles.length}`);
assert(!distFiles.includes("assets/css/main.css"), "dist/ conserva main.css sin hash (se cachearía un año sin poder actualizarse)");

const robots = readFileSync(resolve(distDir, "robots.txt"), "utf8");
assert(robots.includes(`Sitemap: ${siteConfig.siteUrl}/sitemap.xml`), "robots.txt no declara el sitemap con URL absoluta");

const notFound = readFileSync(resolve(distDir, "404.html"), "utf8");
assert(notFound.includes("No encontramos esa página"), "404.html no ofrece un mensaje legible");
assert(notFound.includes('href="/"'), "404.html no ofrece una vuelta a la portada");
assert(!notFound.includes("casilisto-privacy.pages.dev"), "404.html conserva el dominio antiguo");

const sitemap = readFileSync(resolve(distDir, "sitemap.xml"), "utf8");
for (const path of ["/", "/privacy/", "/support/"]) {
  assert(sitemap.includes(`<loc>${siteConfig.siteUrl}${path}</loc>`), `sitemap.xml no lista ${path}`);
}
assert(sitemap.includes(`<lastmod>${siteConfig.policyLastUpdatedISO}</lastmod>`), "sitemap.xml no usa la fecha de la política como lastmod");
assert(!sitemap.includes("casilisto-privacy.pages.dev"), "sitemap.xml conserva el dominio antiguo");

// 2. Páginas ------------------------------------------------------------------

const pages = {
  "index.html": "/",
  "privacy/index.html": "/privacy/",
  "support/index.html": "/support/"
};

const titles = new Set();

for (const [file, canonicalPath] of Object.entries(pages)) {
  const html = readFileSync(resolve(distDir, file), "utf8");
  const where = `${file}:`;

  assert(html.startsWith("<!DOCTYPE html>"), `${where} sin DOCTYPE`);
  assert(html.includes('<html lang="es-CL">'), `${where} sin lang="es-CL"`);
  assert(html.includes('<meta charset="utf-8">'), `${where} sin charset`);
  assert(html.includes('<meta name="viewport" content="width=device-width, initial-scale=1">'), `${where} sin viewport`);

  const title = html.match(/<title>(.+?)<\/title>/)?.[1];
  assert(title, `${where} sin <title>`);
  assert(!titles.has(title), `${where} <title> repetido: "${title}"`);
  titles.add(title);

  assert(/<meta name="description" content=".{40,}">/.test(html), `${where} meta description ausente o demasiado corta`);
  assert(html.includes(`<link rel="canonical" href="${siteConfig.siteUrl}${canonicalPath}">`), `${where} canonical no es absoluta o no coincide con la ruta`);
  assert(html.includes(`<meta property="og:url" content="${siteConfig.siteUrl}${canonicalPath}">`), `${where} og:url no es absoluta`);
  assert(html.includes(`<meta property="og:image" content="${siteConfig.siteUrl}/assets/images/appicon-512.png">`), `${where} og:image no es absoluta`);
  assert(!html.includes("casilisto-privacy.pages.dev"), `${where} conserva referencias al dominio antiguo`);
  assert(html.includes(`<link rel="stylesheet" href="/${cssFiles[0]}">`), `${where} no enlaza el CSS con hash`);

  assert(html.includes('class="skip-link"'), `${where} sin skip link`);
  assert(html.includes("<header") && html.includes("<main") && html.includes("<footer") && html.includes("<nav"), `${where} faltan landmarks`);
  assert((html.match(/<h1[^>]*>/g) ?? []).length === 1, `${where} debe tener exactamente un <h1>`);

  // Jerarquía de encabezados sin saltos (h1 -> h2 -> h3).
  const levels = [...html.matchAll(/<h([1-6])[^>]*>/g)].map((m) => Number(m[1]));
  for (let i = 1; i < levels.length; i++) {
    assert(levels[i] <= levels[i - 1] + 1, `${where} salto de encabezado h${levels[i - 1]} -> h${levels[i]}`);
  }

  for (const img of html.matchAll(/<img\b[^>]*>/g)) {
    assert(/\balt="/.test(img[0]), `${where} <img> sin alt: ${img[0]}`);
    assert(/\bwidth="\d+"/.test(img[0]) && /\bheight="\d+"/.test(img[0]), `${where} <img> sin width/height: ${img[0]}`);
  }

  assert(!/\{\{[A-Z0-9_]+\}\}/.test(html), `${where} placeholder sin interpolar`);
  assert(!/TODO|FIXME|ejemplo\.cl|undefined|NaN/.test(html), `${where} contiene texto de borrador (TODO/FIXME/ejemplo.cl/undefined/NaN)`);
  assert(!/<script(?![^>]*type="application\/ld\+json")/i.test(html), `${where} contiene JavaScript ejecutable`);
  assert(!/googletagmanager\.com|google-analytics\.com|fonts\.googleapis\.com|cdn\./i.test(html), `${where} carga recursos de terceros`);
  assert(!/\sstyle="/.test(html), `${where} usa estilos inline`);
  assert(!/<!--\s*(Sección|Tarjeta|Encabezado)/.test(html), `${where} conserva comentarios de plantilla`);

  // Enlaces internos y correos.
  for (const [, href] of html.matchAll(/<a\b[^>]*href="([^"]+)"/g)) {
    if (href.startsWith("#")) {
      assert(html.includes(`id="${href.slice(1)}"`), `${where} ancla ${href} sin destino`);
    } else if (href.startsWith("/")) {
      const [path, fragment] = href.split("#");
      const target = path.endsWith("/") ? `${path}index.html` : path;
      const targetFile = resolve(distDir, target.slice(1));
      assert(existsSync(targetFile), `${where} enlace interno ${href} no existe en dist/`);
      if (fragment && existsSync(targetFile)) {
        assert(readFileSync(targetFile, "utf8").includes(`id="${fragment}"`), `${where} enlace ${href} apunta a un id inexistente`);
      }
    } else if (href.startsWith("mailto:")) {
      assert(href.startsWith(`mailto:${siteConfig.supportEmail}`), `${where} mailto no usa el correo configurado: ${href}`);
    } else {
      assert(href.startsWith("https://") && /rel="noopener"/.test(html.slice(html.indexOf(href), html.indexOf(href) + 200)), `${where} enlace externo sin https o sin rel="noopener": ${href}`);
    }
  }
}

// 3. Coherencia con la app ----------------------------------------------------

const privacy = readFileSync(resolve(distDir, "privacy/index.html"), "utf8");
const home = readFileSync(resolve(distDir, "index.html"), "utf8");
assert(home.includes('"operatingSystem": "iOS 26.0"'), "index.html: JSON-LD no declara el sistema operativo como iOS 26.0");
assert(!home.includes('"operatingSystem": "iOS iOS'), "index.html: JSON-LD duplica el prefijo iOS");
assert(privacy.includes(siteConfig.permissions.camera), "privacy: el texto del permiso de cámara no coincide con site.config");
assert(privacy.includes(siteConfig.permissions.microphone), "privacy: el texto del permiso de micrófono no coincide con site.config");
assert(privacy.includes(siteConfig.appGroupId), "privacy: no cita el App Group configurado");
assert(privacy.includes("iCloud"), "privacy: no explica qué pasa con el respaldo de iCloud");
assert(privacy.includes("no incluye las fotos de boletas ni las notas de voz"), "privacy: no aclara la exclusión de archivos multimedia del JSON");
assert(privacy.includes("dependen del respaldo del dispositivo"), "privacy: no explica cómo conservar fotos y notas de voz");
assert(!/exportar\s+todo/i.test(privacy), "privacy: el resumen promete exportar todo");
assert(!/copia\s+completa(?:\s+en\s+JSON)?/i.test(privacy), "privacy: llama completa a una exportación que excluye multimedia");
for (const label of ["Exportar mis datos", "Exportar CSV", "Borrar todos mis datos guardados", "Grabar nota de voz", "Escanear boleta"]) {
  assert(privacy.includes(label), `privacy: no cita el texto literal de la app «${label}»`);
}

// 4. Tokens y contraste, leídos del CSS publicado -----------------------------

const css = readFileSync(resolve(distDir, cssFiles[0]), "utf8");
const lightBlock = css.slice(0, css.indexOf("@media (prefers-color-scheme: dark)"));
const darkBlock = css.slice(css.indexOf("@media (prefers-color-scheme: dark)"), css.indexOf("@media (prefers-reduced-motion"));

function token(block, name) {
  const value = block.match(new RegExp(`${name}:\\s*(#[0-9A-Fa-f]{6})`))?.[1];
  assert(value, `CSS: no encuentro el token ${name} como color hex`);
  return value ?? "#000000";
}

function luminance(hex) {
  const channel = (i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
}

function contrast(a, b) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

function assertContrast(label, fg, bg, minimum) {
  const ratio = contrast(fg, bg);
  assert(ratio >= minimum, `${label}: ${fg} sobre ${bg} da ${ratio.toFixed(2)}:1, mínimo ${minimum}:1`);
}

const light = {
  text: token(lightBlock, "--cl-text"),
  secondary: token(lightBlock, "--cl-text-secondary"),
  accentText: token(lightBlock, "--cl-accent-text"),
  accentInk: token(lightBlock, "--cl-accent-ink"),
  accentFill: token(lightBlock, "--cl-accent-fill"),
  bg: token(lightBlock, "--cl-bg"),
  card: token(lightBlock, "--cl-card"),
  cardSubtle: token(lightBlock, "--cl-card-subtle")
};
const dark = {
  text: token(darkBlock, "--cl-text"),
  secondary: token(darkBlock, "--cl-text-secondary"),
  accentText: token(darkBlock, "--cl-accent-text"),
  bg: token(darkBlock, "--cl-bg"),
  card: token(darkBlock, "--cl-card"),
  cardSubtle: token(darkBlock, "--cl-card-subtle")
};

for (const surface of ["bg", "card", "cardSubtle"]) {
  assertContrast(`claro, texto sobre ${surface}`, light.text, light[surface], 7);
  assertContrast(`claro, texto secundario sobre ${surface}`, light.secondary, light[surface], 4.5);
  assertContrast(`claro, enlaces sobre ${surface}`, light.accentText, light[surface], 4.5);
  assertContrast(`oscuro, texto sobre ${surface}`, dark.text, dark[surface], 7);
  assertContrast(`oscuro, texto secundario sobre ${surface}`, dark.secondary, dark[surface], 4.5);
  assertContrast(`oscuro, enlaces sobre ${surface}`, dark.accentText, dark[surface], 4.5);
}
assertContrast("botón primario", light.accentInk, light.accentFill, 4.5);

assert(css.includes("prefers-reduced-motion: reduce"), "CSS: sin bloque prefers-reduced-motion");
assert(css.includes(":focus-visible"), "CSS: sin estilo de foco visible");
assert(/--cl-touch:\s*44px/.test(css), "CSS: el objetivo táctil ya no es 44px");
assert(!/backdrop-filter/.test(css), "CSS: backdrop-filter sobre un fondo opaco no hace nada");
assert(!/!important/.test(css.replace(/@media \(prefers-reduced-motion: reduce\)[^}]*}[^}]*}/, "")), "CSS: !important fuera del bloque de reduced-motion");

// Todas las clases del CSS se usan en alguna página, y viceversa.
const allHtml = Object.keys(pages).map((f) => readFileSync(resolve(distDir, f), "utf8")).join("\n");
const usedClasses = new Set(allHtml.match(/class="([^"]+)"/g)?.flatMap((m) => m.slice(7, -1).split(/\s+/)) ?? []);
const definedClasses = new Set(css.replace(/\/\*[\s\S]*?\*\//g, "").match(/\.[a-z][a-z0-9-]*/g)?.map((c) => c.slice(1)) ?? []);
for (const cls of definedClasses) {
  assert(usedClasses.has(cls), `CSS: la clase .${cls} no se usa en ninguna página`);
}
for (const cls of usedClasses) {
  assert(definedClasses.has(cls), `HTML: la clase .${cls} no existe en el CSS`);
}

// ---------------------------------------------------------------------------

if (failures > 0) {
  console.error(`\n${failures} fallo(s).`);
  process.exit(1);
}
console.log("OK: dist/ pasa todas las verificaciones.");
