// =====================================================================
// Mano Ya · Edge Function `notify-report`
// ---------------------------------------------------------------------
// Recibe un reporte (desde n8n o desde la app) y envia un correo al
// equipo de soporte con el detalle.
//
// Formatos aceptados en el cuerpo:
//   { "reporte": { ... } }    -> reporte envuelto
//   { ...campos planos... }   -> payload directo de la app o del trigger
//
// Cabecera obligatoria en todas las peticiones:
//   x-webhook-secret: <valor de N8N_WEBHOOK_SECRET>
//
// Variables de entorno (Supabase -> Edge Functions -> Secrets):
//   RESEND_API_KEY        clave de la API de Resend (obligatoria)
//   SUPPORT_EMAIL         correo de soporte que recibe los reportes
//   N8N_WEBHOOK_SECRET    secreto compartido con n8n (obligatoria)
//   RESEND_FROM_EMAIL     remitente del correo (opcional)
//   WEBHOOK_SECRET_HEADER nombre de la cabecera del secreto (opcional)
//
// Despliegue:
//   supabase functions deploy notify-report --no-verify-jwt
// =====================================================================

type JsonRecord = Record<string, unknown>;

interface ReportData {
  id: string;
  category: string;
  categoryLabel: string;
  severity: string;
  reason: string;
  details: string;
  reporterName: string;
  reporterEmail: string;
  reporterId: string;
  targetName: string;
  targetId: string;
  jobId: string;
  createdAt: string;
}

const CATEGORY_LABELS: Record<string, string> = {
  calidad: 'Calidad del servicio',
  pago: 'Problema de pago',
  conducta: 'Conducta inappropriada',
  no_show: 'No se presento',
  datos: 'Datos incorrectos',
  otro: 'Otro motivo',
};

const VALID_CATEGORIES = Object.keys(CATEGORY_LABELS);
const VALID_SEVERITIES = ['baja', 'normal', 'alta'];

const DEFAULT_SUPPORT_EMAIL = 'soporte@manoya.app';
const DEFAULT_FROM_EMAIL = 'Mano Ya <reportes@manoya.app>';
const RESEND_ENDPOINT = 'https://api.resend.com/emails';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-webhook-secret',
  'Access-Control-Max-Age': '86400',
};

function respond(status: number, payload: JsonRecord): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

/// Devuelve el primer valor no vacio entre las claves indicadas.
function pickString(source: JsonRecord, keys: string[]): string {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === 'string' && value.trim() !== '') return value.trim();
    if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  }
  return '';
}

/// Extrae el reporte del cuerpo, bien envuelto o bien plano.
function extractReport(body: JsonRecord): JsonRecord {
  const nested = body['reporte'];
  if (nested && typeof nested === 'object' && !Array.isArray(nested)) {
    return nested as JsonRecord;
  }
  return body;
}

function normalizeReport(raw: JsonRecord): ReportData {
  const category = pickString(raw, ['categoria', 'category']).toLowerCase();
  const severity = pickString(raw, ['severidad', 'severity']).toLowerCase();

  return {
    id: pickString(raw, ['id', 'reporte_id', 'report_id']),
    category,
    categoryLabel:
      pickString(raw, ['categoria_label', 'category_label']) ||
      CATEGORY_LABELS[category] ||
      category,
    severity: VALID_SEVERITIES.includes(severity) ? severity : 'normal',
    reason: pickString(raw, ['motivo', 'reason']),
    details: pickString(raw, ['detalle', 'details', 'descripcion']),
    reporterName: pickString(raw, ['reporta', 'reporter_name', 'reportante']),
    reporterEmail: pickString(raw, [
      'correo',
      'report_email',
      'reporter_email',
      'email',
    ]),
    reporterId: pickString(raw, ['reporta_id', 'reporter_id']),
    targetName: pickString(raw, ['reportado', 'target_name']),
    targetId: pickString(raw, ['reportado_id', 'target_user_id']),
    jobId: pickString(raw, ['servicio_id', 'job_id']),
    createdAt: pickString(raw, ['creado', 'created_at']),
  };
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function severityLabel(value: string): string {
  if (value === 'alta') return 'Alta';
  if (value === 'baja') return 'Baja';
  return 'Normal';
}

function buildEmailHtml(report: ReportData): string {
  const rows: Array<[string, string]> = [
    ['Identificador', report.id || 'sin id'],
    ['Categoria', report.categoryLabel],
    ['Severidad', severityLabel(report.severity)],
    ['Motivo', report.reason],
    ['Quien reporta', report.reporterName || 'sin nombre'],
    ['Correo de quien reporta', report.reporterEmail],
    ['Usuario reportado', report.targetName || 'sin especificar'],
    ['Servicio relacionado', report.jobId || 'sin relacionar'],
    ['Fecha del reporte', report.createdAt || 'sin fecha'],
  ];

  const rowsHtml = rows
    .map(
      ([label, value]) => `
        <tr>
          <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;color:#475569;font-size:14px;white-space:nowrap;">
            ${escapeHtml(label)}
          </td>
          <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;color:#0f172a;font-size:14px;">
            ${escapeHtml(value)}
          </td>
        </tr>`,
    )
    .join('');

  const detailsHtml = report.details
    ? `
      <div style="margin-top:20px;">
        <p style="margin:0 0 8px;color:#475569;font-size:13px;text-transform:uppercase;letter-spacing:.04em;">
          Detalle del reporte
        </p>
        <p style="margin:0;padding:14px 16px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;color:#0f172a;font-size:14px;line-height:1.5;white-space:pre-wrap;">
          ${escapeHtml(report.details)}
        </p>
      </div>`
    : '';

  return `<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Nuevo reporte de Mano Ya</title>
  </head>
  <body style="margin:0;padding:24px;background:#f1f5f9;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:14px;overflow:hidden;border:1px solid #e2e8f0;">
      <tr>
        <td style="padding:22px 24px;background:#2563eb;color:#ffffff;">
          <p style="margin:0;font-size:20px;font-weight:700;">Mano Ya</p>
          <p style="margin:4px 0 0;font-size:13px;opacity:.9;">Nuevo reporte recibido desde la app</p>
        </td>
      </tr>
      <tr>
        <td style="padding:24px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
            ${rowsHtml}
          </table>
          ${detailsHtml}
        </td>
      </tr>
      <tr>
        <td style="padding:16px 24px;background:#f8fafc;color:#64748b;font-size:12px;">
          Este correo se genero automaticamente desde la Edge Function <code>notify-report</code> de Supabase.
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildSubject(report: ReportData): string {
  const reason = report.reason.length > 80
    ? `${report.reason.slice(0, 77)}...`
    : report.reason;
  return `[Mano Ya] Reporte ${report.categoryLabel} - ${reason}`;
}

interface MailResult {
  sent: boolean;
  error: string;
}

async function sendEmail(report: ReportData): Promise<MailResult> {
  const apiKey = Deno.env.get('RESEND_API_KEY')?.trim() ?? '';
  if (!apiKey) {
    return {
      sent: false,
      error: 'Falta la variable RESEND_API_KEY en los secretos de la funcion.',
    };
  }

  const supportEmail = Deno.env.get('SUPPORT_EMAIL')?.trim() || DEFAULT_SUPPORT_EMAIL;
  const fromEmail = Deno.env.get('RESEND_FROM_EMAIL')?.trim() || DEFAULT_FROM_EMAIL;

  try {
    const response = await fetch(RESEND_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [supportEmail],
        subject: buildSubject(report),
        html: buildEmailHtml(report),
      }),
    });

    const raw = await response.text();
    if (!response.ok) {
      return {
        sent: false,
        error: `Resend respondio ${response.status}: ${raw.slice(0, 400)}`,
      };
    }

    return { sent: true, error: '' };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return { sent: false, error: `No se pudo contactar con Resend: ${message}` };
  }
}

async function checkSecret(
  request: Request,
): Promise<{ ok: boolean; error: string }> {
  const expected = Deno.env.get('N8N_WEBHOOK_SECRET')?.trim() ?? '';
  const headerName = (
    Deno.env.get('WEBHOOK_SECRET_HEADER')?.trim() || 'x-webhook-secret'
  ).toLowerCase();
  const provided = (request.headers.get(headerName) ?? '').trim();

  if (expected && provided && provided === expected) {
    return { ok: true, error: '' };
  }

  // La version web de la app no lleva el secreto (quedaria exposed en el
  // bundle publico), asi que se acepta tambien una sesion de usuario
  // valida. El navegador manda el token de acceso en la cabecera
  // `Authorization: Bearer <access_token>`.
  return checkUserSession(request);
}

/// Valida la sesion de Supabase del cliente que hace la peticion.
///
/// Se usa en la version web, donde el secreto compartido no puede viajar en
/// el bundle. La sesion si la valida el servidor de autenticacion de
/// Supabase, de modo que solo un usuario con cuenta activa puede reportar.
async function checkUserSession(
  request: Request,
): Promise<{ ok: boolean; error: string }> {
  const authHeader = (request.headers.get('authorization') ?? '').trim();
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return {
      ok: false,
      error: `Falta la cabecera ${'x-webhook-secret'} o un token de sesion valido.`,
    };
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    return { ok: false, error: 'El token de sesion viene vacio.' };
  }

  const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? '').trim();
  const anonKey = (Deno.env.get('SUPABASE_ANON_KEY') ?? '').trim();
  if (!supabaseUrl || !anonKey) {
    return {
      ok: false,
      error:
        'La funcion no tiene SUPABASE_URL ni SUPABASE_ANON_KEY en sus secretos, no se puede validar la sesion.',
    };
  }

  try {
    const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      return { ok: false, error: 'La sesion del usuario no es valida.' };
    }

    return { ok: true, error: '' };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      ok: false,
      error: `No se pudo validar la sesion del usuario: ${message}`,
    };
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (request.method !== 'POST') {
    return respond(405, {
      ok: false,
      error: 'Metodo no permitido. Usa POST.',
    });
  }

  const secret = await checkSecret(request);
  if (!secret.ok) {
    return respond(401, { ok: false, error: secret.error });
  }

  let body: JsonRecord;
  try {
    const parsed = await request.json();
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return respond(400, {
        ok: false,
        error: 'El cuerpo debe ser un objeto JSON.',
      });
    }
    body = parsed as JsonRecord;
  } catch {
    return respond(400, {
      ok: false,
      error: 'No se pudo leer el cuerpo de la peticion como JSON.',
    });
  }

  const report = normalizeReport(extractReport(body));

  if (!report.category) {
    return respond(400, {
      ok: false,
      error: 'Falta el campo obligatorio: categoria.',
    });
  }
  if (!VALID_CATEGORIES.includes(report.category)) {
    return respond(400, {
      ok: false,
      error: `Categoria invalida: ${report.category}. Valores validos: ${VALID_CATEGORIES.join(', ')}.`,
    });
  }
  if (!report.reason) {
    return respond(400, {
      ok: false,
      error: 'Falta el campo obligatorio: motivo.',
    });
  }
  if (!report.reporterEmail) {
    return respond(400, {
      ok: false,
      error: 'Falta el campo obligatorio: correo del reportante.',
    });
  }

  const mail = await sendEmail(report);

  return respond(200, {
    ok: true,
    id: report.id || null,
    enviado: mail.sent,
    categoria: report.category,
    severidad: report.severity,
    soporte: Deno.env.get('SUPPORT_EMAIL')?.trim() || DEFAULT_SUPPORT_EMAIL,
    ...(mail.sent ? {} : { error: mail.error }),
  });
});
