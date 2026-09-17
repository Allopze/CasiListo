/**
 * Configuración central de CasiListo Web.
 *
 * Cada valor puede sobreescribirse con una variable de entorno PUBLIC_* en el
 * proveedor de despliegue. Las validaciones viven aquí y solo aquí: build.mjs
 * confía en lo que exporta este módulo.
 */

const env = (name) => process.env[name]?.trim() || "";

const supportEmail = env("PUBLIC_SUPPORT_EMAIL") || "allopze@gmail.com";
if (supportEmail.includes("ejemplo") || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(supportEmail)) {
  throw new Error(`[site.config.mjs] Correo de soporte inválido: "${supportEmail}". Define PUBLIC_SUPPORT_EMAIL con un correo real.`);
}

// El valor por defecto es el mismo dominio que la app tiene compilado en
// AppSupportLinks.swift: si cambian uno sin el otro, los enlaces desde Ajustes
// dejan de apuntar aquí.
const siteUrl = (env("PUBLIC_SITE_URL") || "https://casilisto.lat").replace(/\/$/, "");
if (!/^https:\/\/[^\s/]+$/.test(siteUrl)) {
  throw new Error(`[site.config.mjs] PUBLIC_SITE_URL debe ser un origen https absoluto sin ruta (recibido: "${siteUrl}").`);
}

// Fecha en español para el texto legal; el sitemap necesita la misma fecha en ISO.
const policyLastUpdated = env("PUBLIC_POLICY_LAST_UPDATED") || "13 de septiembre de 2026";
const policyEffectiveDate = env("PUBLIC_POLICY_EFFECTIVE_DATE") || policyLastUpdated;

const monthNumbers = {
  enero: "01", febrero: "02", marzo: "03", abril: "04", mayo: "05", junio: "06",
  julio: "07", agosto: "08", septiembre: "09", octubre: "10", noviembre: "11", diciembre: "12"
};

function toISODate(spanishDate) {
  const match = /^(\d{1,2}) de ([a-záéíóú]+) de (\d{4})$/i.exec(spanishDate);
  const month = match && monthNumbers[match[2].toLowerCase()];
  if (!month) {
    throw new Error(`[site.config.mjs] Fecha no reconocida: "${spanishDate}". Usa el formato "13 de septiembre de 2026".`);
  }
  return `${match[3]}-${month}-${match[1].padStart(2, "0")}`;
}

export const siteConfig = {
  siteName: "CasiListo",
  tagline: "Casi listo para ir al súper.",
  description: "CasiListo es una app de listas de compras para iPhone pensada para el supermercado chileno: fotografía la boleta, registra precios y guarda todo en tu teléfono.",
  appVersion: env("PUBLIC_APP_VERSION") || "1.0",
  minIosVersion: "iOS 26.0",
  appGroupId: "group.com.allopze.CasiListo",

  developerName: "Alejandro López Zelaya",
  developerCountry: "Chile",
  dedication: "Desarrollada por Alejandro López Zelaya para su padre, Casimiro López Díaz.",

  supportEmail,
  siteUrl,

  currentYear: String(new Date().getFullYear()),
  policyEffectiveDate,
  policyLastUpdated,
  policyLastUpdatedISO: toISODate(policyLastUpdated),

  // Textos literales de INFOPLIST_KEY_NS*UsageDescription en project.pbxproj.
  permissions: {
    camera: "CasiListo usa la cámara para fotografiar boletas y registrar productos y precios.",
    microphone: "CasiListo usa el micrófono para guardar notas de voz en productos de tu lista."
  }
};

export default siteConfig;
