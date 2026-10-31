type JsonObject = Record<string, unknown>;

const corsHeaders = {
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
  Vary: 'Origin',
};
const maxBodyBytes = 2048;
const requestTimeoutMs = 12_000;

function response(
  status: number,
  payload: JsonObject,
  origin: string | null,
): Response {
  const allowedOrigin = Deno.env.get('APP_ORIGIN')?.trim();
  return new Response(status === 204 ? null : JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Access-Control-Allow-Origin': allowedOrigin
        ? origin === allowedOrigin
          ? allowedOrigin
          : ''
        : '*',
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    const entities: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    return entities[character];
  });
}

function normalizePhone(value: string): string {
  let digits = value.replace(/\D/g, '');
  if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  if (digits.length === 10) digits = `58${digits}`;
  return digits;
}

function isObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get('origin');
  if (request.method === 'OPTIONS') {
    const allowedOrigin = Deno.env.get('APP_ORIGIN')?.trim();
    return allowedOrigin && origin !== allowedOrigin
      ? new Response(null, { status: 403 })
      : response(204, {}, origin);
  }
  if (request.method !== 'POST') {
    return response(405, { ok: false, error: 'Utiliza el método POST.' }, origin);
  }

  const configuredOrigin = Deno.env.get('APP_ORIGIN')?.trim();
  if (configuredOrigin && origin && origin !== configuredOrigin) {
    return response(403, { ok: false, error: 'Origen no autorizado.' }, origin);
  }

  const authorization = request.headers.get('authorization')?.trim() ?? '';
  const tokenMatch = /^Bearer\s+(\S+)$/i.exec(authorization);
  if (!tokenMatch) {
    return response(401, { ok: false, error: 'Inicia sesión para continuar.' }, origin);
  }
  if (Number(request.headers.get('content-length') ?? 0) > maxBodyBytes) {
    return response(413, { ok: false, error: 'La solicitud es demasiado grande.' }, origin);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')?.trim() ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')?.trim() ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim() ?? '';
  const resendApiKey = Deno.env.get('RESEND_API_KEY')?.trim() ?? '';
  const fromEmail = Deno.env.get('RESEND_FROM_EMAIL')?.trim() ?? '';
  const webAppUrl = Deno.env.get('WEB_APP_URL')?.trim() || 'https://mano-ya.app';
  const androidApkUrl = Deno.env.get('ANDROID_APK_URL')?.trim();
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return response(503, {
      ok: false,
      error: 'El servicio de fichas no está configurado en Supabase.',
    }, origin);
  }
  if (!resendApiKey || !fromEmail) {
    return response(503, {
      ok: false,
      error: 'El envío de fichas por correo aún no está configurado.',
    }, origin);
  }

  let body: string;
  try {
    body = await request.text();
  } catch {
    return response(400, { ok: false, error: 'El cuerpo debe ser JSON válido.' }, origin);
  }
  if (new TextEncoder().encode(body).byteLength > maxBodyBytes) {
    return response(413, { ok: false, error: 'La solicitud es demasiado grande.' }, origin);
  }
  let input: unknown;
  try {
    input = JSON.parse(body);
  } catch {
    return response(400, { ok: false, error: 'El cuerpo debe ser JSON válido.' }, origin);
  }
  const workerId = isObject(input) ? input['worker_id'] : null;
  if (typeof workerId !== 'string' || !/^[0-9a-f-]{36}$/i.test(workerId)) {
    return response(400, { ok: false, error: 'La ficha solicitada no es válida.' }, origin);
  }

  try {
    const fetchWithTimeout = (input: string | URL, init: RequestInit) =>
      fetch(input, { ...init, signal: AbortSignal.timeout(requestTimeoutMs) });
    const authResponse = await fetchWithTimeout(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: anonKey, Authorization: `Bearer ${tokenMatch[1]}` },
    });
    if (!authResponse.ok) {
      return response(401, { ok: false, error: 'Tu sesión no es válida.' }, origin);
    }
    const user: unknown = await authResponse.json();
    if (!isObject(user) || typeof user['id'] !== 'string' || typeof user['email'] !== 'string') {
      return response(401, { ok: false, error: 'La cuenta no tiene un correo válido.' }, origin);
    }
    const metadata = user['user_metadata'];
    if (!isObject(metadata) || metadata['role'] !== 'client') {
      return response(403, {
        ok: false,
        error: 'Solo las cuentas cliente pueden solicitar una ficha.',
      }, origin);
    }

    const adminHeaders = {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    };
    const workerUrl = new URL('/rest/v1/workers', supabaseUrl);
    workerUrl.searchParams.set(
      'select',
      'profile_id,name,category,subcategory,city,phone,bio',
    );
    workerUrl.searchParams.set('id', `eq.${workerId}`);
    workerUrl.searchParams.set('limit', '1');
    const workerResponse = await fetchWithTimeout(workerUrl, { headers: adminHeaders });
    if (!workerResponse.ok) {
      console.error('No se pudo consultar la ficha de trabajador solicitada.');
      return response(503, { ok: false, error: 'No se pudo consultar la ficha.' }, origin);
    }
    const workerRows: unknown = await workerResponse.json();
    const worker = Array.isArray(workerRows) ? workerRows[0] : null;
    if (!isObject(worker) || typeof worker['profile_id'] !== 'string') {
      return response(404, { ok: false, error: 'El trabajador ya no está disponible.' }, origin);
    }

    const profileUrl = new URL('/rest/v1/profiles', supabaseUrl);
    profileUrl.searchParams.set(
      'select',
      'payout_method,payout_account_holder,payout_account_number,payout_bank_name',
    );
    profileUrl.searchParams.set('id', `eq.${worker['profile_id']}`);
    profileUrl.searchParams.set('limit', '1');
    const profileResponse = await fetchWithTimeout(profileUrl, { headers: adminHeaders });
    if (!profileResponse.ok) {
      console.error('No se pudieron consultar los datos privados de cobro.');
      return response(503, { ok: false, error: 'No se pudo preparar la ficha.' }, origin);
    }
    const profileRows: unknown = await profileResponse.json();
    const payout = Array.isArray(profileRows) ? profileRows[0] : null;
    const details = isObject(payout) ? payout : {};
    const phone = String(worker['phone'] ?? '');
    const whatsappNumber = normalizePhone(phone);
    const whatsappUrl = whatsappNumber ? `https://wa.me/${whatsappNumber}` : '';
    const appUrl = new URL(webAppUrl);
    if (appUrl.protocol !== 'https:') {
      return response(503, {
        ok: false,
        error: 'El enlace de Mano Ya debe utilizar HTTPS.',
      }, origin);
    }
    let apkLink = '';
    if (androidApkUrl) {
      const apkUrl = new URL(androidApkUrl);
      if (apkUrl.protocol !== 'https:') {
        return response(503, {
          ok: false,
          error: 'El enlace del APK debe utilizar HTTPS.',
        }, origin);
      }
      apkLink = `<p><a href="${escapeHtml(apkUrl.toString())}">Descargar la app Android</a></p>`;
    }

    const safe = (key: string) => escapeHtml(String(worker[key] ?? 'No indicado'));
    const payoutLines = [
      ['Método de pago', details['payout_method']],
      ['Titular', details['payout_account_holder']],
      ['Cuenta o teléfono', details['payout_account_number']],
      ['Banco', details['payout_bank_name']],
    ]
      .filter(([, value]) => typeof value === 'string' && value.trim())
      .map(([label, value]) => `<li><strong>${label}:</strong> ${escapeHtml(String(value))}</li>`)
      .join('');
    const whatsappLink = whatsappUrl
      ? `<p><a href="${whatsappUrl}">Abrir chat de WhatsApp</a></p>`
      : '<p>Este trabajador no ha publicado un número de WhatsApp.</p>';
    const html = `
      <h1>Ficha de ${safe('name')}</h1>
      <p><strong>Oficio:</strong> ${safe('category')} · ${safe('subcategory')}</p>
      <p><strong>Zona:</strong> ${safe('city')}</p>
      <p><strong>Teléfono:</strong> ${escapeHtml(phone || 'No indicado')}</p>
      <p><strong>Presentación:</strong> ${safe('bio')}</p>
      <h2>Datos de pago compartidos por el trabajador</h2>
      ${payoutLines ? `<ul>${payoutLines}</ul>` : '<p>No hay datos de pago configurados.</p>'}
      ${whatsappLink}
      <p><a href="${escapeHtml(appUrl.toString())}">Abrir Mano Ya</a></p>
      ${apkLink}
    `;

    const emailResponse = await fetchWithTimeout('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [user['email']],
        subject: `Ficha de ${String(worker['name'] ?? 'trabajador')} · Mano Ya`,
        html,
      }),
    });
    if (!emailResponse.ok) {
      console.error(`Resend rechazó el envío de la ficha (${emailResponse.status}).`);
      return response(502, {
        ok: false,
        error: 'No se pudo enviar la ficha por correo. Puedes continuar por WhatsApp.',
      }, origin);
    }
    return response(200, { ok: true }, origin);
  } catch (error) {
    console.error('Error interno al enviar la ficha de contacto.', error);
    return response(502, {
      ok: false,
      error: 'No se pudo enviar la ficha por correo. Puedes continuar por WhatsApp.',
    }, origin);
  }
});
