import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const supportEmail = process.env.PUBLIC_SUPPORT_EMAIL?.trim();
if (!supportEmail) {
  throw new Error("PUBLIC_SUPPORT_EMAIL es obligatorio. No se publicará un correo de soporte ficticio.");
}
if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(supportEmail)) {
  throw new Error("PUBLIC_SUPPORT_EMAIL no tiene un formato de correo válido.");
}

const root = resolve(import.meta.dirname, "..");
const source = resolve(root, "src");
const destination = resolve(root, "dist");
rmSync(destination, { recursive: true, force: true });
mkdirSync(destination, { recursive: true });
cpSync(resolve(source, "assets"), resolve(destination, "assets"), { recursive: true });

const effectiveDate = process.env.PUBLIC_POLICY_EFFECTIVE_DATE?.trim() || "12 de agosto de 2026";
for (const page of ["privacy", "support"]) {
  const template = readFileSync(resolve(source, `${page}.html`), "utf8");
  const html = template
    .replaceAll("{{SUPPORT_EMAIL}}", supportEmail)
    .replaceAll("{{EFFECTIVE_DATE}}", effectiveDate);
  const pageDirectory = resolve(destination, page);
  mkdirSync(pageDirectory, { recursive: true });
  writeFileSync(resolve(pageDirectory, "index.html"), html, "utf8");
}

if (!existsSync(resolve(destination, "privacy", "index.html"))) {
  throw new Error("No se pudo generar la política de privacidad.");
}
