import { createHash } from "node:crypto";
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { siteConfig } from "../site.config.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const srcDir = resolve(root, "src");
const distDir = resolve(root, "dist");

console.log(`Compilando CasiListo Web -> ${siteConfig.siteUrl} (app ${siteConfig.appVersion}, política del ${siteConfig.policyLastUpdatedISO})`);

rmSync(distDir, { recursive: true, force: true });
mkdirSync(distDir, { recursive: true });

// Finder deja .DS_Store dentro de src/ y cpSync los copiaría al sitio publicado.
const skipFinderFiles = { recursive: true, filter: (path) => basename(path) !== ".DS_Store" };
cpSync(resolve(srcDir, "assets"), resolve(distDir, "assets"), skipFinderFiles);
cpSync(resolve(srcDir, "public"), distDir, skipFinderFiles);

// _headers sirve /assets/css/* como inmutable por un año, así que el nombre
// del CSS lleva el hash de su contenido: cada edición cambia la URL y llega
// a quien ya tenía la anterior en caché.
const cssSource = readFileSync(resolve(srcDir, "assets/css/main.css"));
const cssHash = createHash("sha256").update(cssSource).digest("hex").slice(0, 10);
const cssPath = `/assets/css/main.${cssHash}.css`;
rmSync(resolve(distDir, "assets/css/main.css"));
writeFileSync(resolve(distDir, cssPath.slice(1)), cssSource);

const pages = [
  { templateName: "index.html", outputSubpath: "index.html", canonicalPath: "/" },
  { templateName: "privacy.html", outputSubpath: "privacy/index.html", canonicalPath: "/privacy/" },
  { templateName: "support.html", outputSubpath: "support/index.html", canonicalPath: "/support/" }
];

const replacements = {
  "{{SITE_NAME}}": siteConfig.siteName,
  "{{SITE_URL}}": siteConfig.siteUrl,
  "{{CSS_PATH}}": cssPath,
  "{{TAGLINE}}": siteConfig.tagline,
  "{{DESCRIPTION}}": siteConfig.description,
  "{{APP_VERSION}}": siteConfig.appVersion,
  "{{MIN_IOS_VERSION}}": siteConfig.minIosVersion,
  "{{APP_GROUP_ID}}": siteConfig.appGroupId,
  "{{DEVELOPER_NAME}}": siteConfig.developerName,
  "{{DEVELOPER_COUNTRY}}": siteConfig.developerCountry,
  "{{DEDICATION}}": siteConfig.dedication,
  "{{SUPPORT_EMAIL}}": siteConfig.supportEmail,
  "{{CURRENT_YEAR}}": siteConfig.currentYear,
  "{{POLICY_EFFECTIVE_DATE}}": siteConfig.policyEffectiveDate,
  "{{POLICY_LAST_UPDATED}}": siteConfig.policyLastUpdated,
  "{{POLICY_LAST_UPDATED_ISO}}": siteConfig.policyLastUpdatedISO,
  "{{PERMISSION_CAMERA}}": siteConfig.permissions.camera,
  "{{PERMISSION_MICROPHONE}}": siteConfig.permissions.microphone
};

for (const page of pages) {
  let html = readFileSync(resolve(srcDir, page.templateName), "utf8");
  html = html.replaceAll("{{CANONICAL_URL}}", `${siteConfig.siteUrl}${page.canonicalPath}`);
  for (const [placeholder, value] of Object.entries(replacements)) {
    html = html.replaceAll(placeholder, value);
  }

  const unresolved = html.match(/\{\{[A-Z0-9_]+\}\}/g);
  if (unresolved) {
    throw new Error(`[build.mjs] Placeholders sin resolver en ${page.templateName}: ${[...new Set(unresolved)].join(", ")}`);
  }

  const outputPath = resolve(distDir, page.outputSubpath);
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, html, "utf8");
}

// robots.txt y sitemap.xml exigen URLs absolutas, por eso se generan aquí y
// no viven en src/public. lastmod es la fecha de la política, no la del build.
writeFileSync(resolve(distDir, "robots.txt"), `User-agent: *\nAllow: /\n\nSitemap: ${siteConfig.siteUrl}/sitemap.xml\n`);

const sitemapEntries = pages.map(({ canonicalPath }) => `  <url>
    <loc>${siteConfig.siteUrl}${canonicalPath}</loc>
    <lastmod>${siteConfig.policyLastUpdatedISO}</lastmod>
  </url>`).join("\n");
writeFileSync(resolve(distDir, "sitemap.xml"), `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sitemapEntries}
</urlset>
`);

console.log(`Listo: ${pages.length} páginas, CSS ${cssPath}, salida en dist/`);
