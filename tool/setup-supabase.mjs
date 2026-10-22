// =====================================================================
// Mano Ya · Configuración automática del proyecto Supabase
// ---------------------------------------------------------------------
// Usa un Personal Access Token (PAT) de Supabase para:
//   1. Leer las claves API (publishable/anon y secret/service role).
//   2. Escribirlas en `.env` del proyecto Flutter.
//   3. Habilitar el proveedor de Google en Auth (MFA/TOTP ya se activa
//      con el script SQL de este repositorio).
//   4. Verificar que las tablas, buckets y cron estén listos.
//
// Uso:
//   $env:SUPABASE_ACCESS_TOKEN = "sbp_..."   # o passarlo por parametro
//   node tool/setup-supabase.mjs --project-ref waxypsqomsljcljdqwra
// =====================================================================

import fs from 'node:fs';
import path from 'node:path';

const API = 'https://api.supabase.com/v1';

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const projectRef = arg('project-ref', process.env.SUPABASE_PROJECT_REF);
const token = arg('token', process.env.SUPABASE_ACCESS_TOKEN);
const googleClientId = arg('google-client-id', process.env.GOOGLE_CLIENT_ID);
const googleClientSecret = arg('google-client-secret', process.env.GOOGLE_CLIENT_SECRET);

const root = path.resolve(process.cwd());
const envPath = path.join(root, '.env');

if (!projectRef) {
  console.error('Falta --project-ref (por ejemplo waxypsqomsljcljdqwra).');
  process.exit(1);
}
if (!token) {
  console.error('Falta el token: define SUPABASE_ACCESS_TOKEN o usa --token.');
  console.error('Se crea en https://supabase.com/dashboard/account/tokens');
  process.exit(1);
}

async function api(method, endpoint, body) {
  const res = await fetch(`${API}${endpoint}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { ok: res.ok, status: res.status, data };
}

// ---------------------------------------------------------------------
// 1. Claves API del proyecto
// ---------------------------------------------------------------------
console.log('1) Leyendo las claves API del proyecto...');
const keysRes = await api('GET', `/projects/${projectRef}/api-keys`);
if (!keysRes.ok) {
  console.error('   ERROR:', keysRes.status, JSON.stringify(keysRes.data));
  process.exit(1);
}
const keys = Array.isArray(keysRes.data) ? keysRes.data : [];
for (const k of keys) {
  console.log(`   - ${k.name}: ${String(k.api_key).slice(0, 12)}... (${k.type})`);
}
const publishable = keys.find(k => k.type === 'publishable');
const secret = keys.find(k => k.type === 'secret');
const anonLegacy = keys.find(k => k.type === 'anon');
const serviceLegacy = keys.find(k => k.type === 'service_role');

const anonKey = publishable?.api_key || anonLegacy?.api_key || '';
const serviceKey = secret?.api_key || serviceLegacy?.api_key || '';

if (!anonKey) {
  console.error('   No se encontro la clave publica (publishable/anon).');
  process.exit(1);
}
console.log(`   Clave publica: ${anonKey.slice(0, 12)}...`);
console.log(`   Clave de servicio: ${serviceKey ? serviceKey.slice(0, 12) + '...' : '(no encontrada)'}`);

// ---------------------------------------------------------------------
// 2. Escribir el .env
// ---------------------------------------------------------------------
console.log('\n2) Actualizando .env...');
const projectUrl = `https://${projectRef}.supabase.co`;
const envLines = fs.existsSync(envPath)
  ? fs.readFileSync(envPath, 'utf8').split(/\r?\n/)
  : [];

function setEnv(key, value) {
  const line = `${key}=${value}`;
  const idx = envLines.findIndex(l => l.startsWith(`${key}=`));
  if (idx >= 0) envLines[idx] = line;
  else envLines.push(line);
}

setEnv('SUPABASE_URL', projectUrl);
setEnv('SUPABASE_ANON_KEY', anonKey);
if (serviceKey) setEnv('SUPABASE_SERVICE_ROLE_KEY', serviceKey);
if (googleClientId) setEnv('GOOGLE_CLIENT_ID', googleClientId);
if (googleClientSecret) setEnv('GOOGLE_SERVER_CLIENT_ID', googleClientSecret);

fs.writeFileSync(envPath, envLines.filter((l, i, a) => !(l === '' && a[i - 1] === '')).join('\n') + '\n');
console.log(`   .env actualizado con SUPABASE_URL=${projectUrl}`);

// ---------------------------------------------------------------------
// 3. Proveedor de Google en Auth
// ---------------------------------------------------------------------
if (googleClientId && googleClientSecret) {
  console.log('\n3) Habilitando el proveedor de Google en Auth...');
  const authRes = await api('PATCH', `/projects/${projectRef}/config/auth`, {
    GOTRUE_EXTERNAL_GOOGLE_ENABLED: 'true',
    GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: googleClientId,
    GOTRUE_EXTERNAL_GOOGLE_SECRET: googleClientSecret,
    GOTRUE_EXTERNAL_GOOGLE_SKIP_NONCE_CHECK: 'false',
  });
  console.log(authRes.ok ? '   Google habilitado.' : `   ERROR: ${authRes.status} ${JSON.stringify(authRes.data)}`);
} else {
  console.log('\n3) Proveedor de Google: OMITIDO (faltan los client IDs de Google Cloud).');
}

// ---------------------------------------------------------------------
// 4. Configuracion de Auth recomendada
// ---------------------------------------------------------------------
console.log('\n4) Ajustando la configuracion de Auth...');
const authCfg = await api('PATCH', `/projects/${projectRef}/config/auth`, {
  GOTRUE_SITE_URL: arg('site-url', 'https://mano-ya.app'),
  GOTRUE_URI_ALLOW_LIST: arg('site-url', 'https://mano-ya.app'),
  GOTRUE_MAILER_AUTOCONFIRM: 'true',
  GOTRUE_PASSWORD_MIN_LENGTH: '8',
});
console.log(authCfg.ok ? '   Configuracion aplicada.' : `   ERROR: ${authCfg.status} ${JSON.stringify(authCfg.data)}`);

// ---------------------------------------------------------------------
// 5. Estado final
// ---------------------------------------------------------------------
console.log('\n5) Estado del proyecto:');
for (const endpoint of ['/status', '/config/auth']) {
  const r = await api('GET', `/projects/${projectRef}${endpoint}`);
  if (r.ok) {
    const d = r.data || {};
    const resumen = endpoint === '/status'
      ? { database: d.database?.status, auth: d.auth?.status, storage: d.storage?.status }
      : { google: d.GOTRUE_EXTERNAL_GOOGLE_ENABLED, mfa: d.GOTRUE_MFA_TOTP_ENABLED ?? '(no expuesto por la API)' };
    console.log(`   ${endpoint}: ${JSON.stringify(resumen)}`);
  } else {
    console.log(`   ${endpoint}: no disponible (${r.status})`);
  }
}

console.log('\nListo. Revisa el .env y continua con n8n y Google Cloud.');
