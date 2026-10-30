const termsVersion = '1.0-2026';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}

function getClientIp(request: Request): string | null {
  const candidate =
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  if (!candidate) return null;

  if (candidate.includes(':')) {
    try {
      return new URL(`http://[${candidate}]/`).hostname.slice(1, -1);
    } catch {
      return null;
    }
  }

  const octets = candidate.split('.');
  if (
    octets.length !== 4 ||
    octets.some(
      (octet) =>
        !/^\d{1,3}$/.test(octet) ||
        Number(octet) > 255,
    )
  ) {
    return null;
  }
  return candidate;
}

async function findAcceptance(
  supabaseUrl: string,
  headers: Headers,
  userId: string,
): Promise<string | null> {
  const url = new URL('/rest/v1/terms_acceptances', supabaseUrl);
  url.searchParams.set('select', 'accepted_at');
  url.searchParams.set('user_id', `eq.${userId}`);
  url.searchParams.set('terms_version', `eq.${termsVersion}`);
  url.searchParams.set('limit', '1');
  const result = await fetch(url, { headers });
  if (!result.ok) {
    throw new Error('No se pudo consultar la aceptación existente.');
  }

  const rows: unknown = await result.json();
  const first = Array.isArray(rows) ? rows[0] : null;
  const acceptedAt =
    first && typeof first === 'object'
      ? (first as Record<string, unknown>)['accepted_at']
      : null;
  return typeof acceptedAt === 'string' ? acceptedAt : null;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'Método no permitido.' });
  }

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!authorization?.startsWith('Bearer ') || !supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse(503, { error: 'No se pudo validar la sesión.' });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse(400, { error: 'El cuerpo debe ser JSON válido.' });
  }
  if (
    !payload ||
    typeof payload !== 'object' ||
    Array.isArray(payload) ||
    (payload as Record<string, unknown>)['accepted'] !== true ||
    (payload as Record<string, unknown>)['terms_version'] !== termsVersion
  ) {
    return jsonResponse(400, { error: 'La aceptación del acuerdo es obligatoria.' });
  }

  try {
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: anonKey, Authorization: authorization },
    });
    if (!userResponse.ok) {
      return jsonResponse(401, { error: 'La sesión no es válida.' });
    }

    const user: unknown = await userResponse.json();
    if (
      !user ||
      typeof user !== 'object' ||
      typeof (user as Record<string, unknown>)['id'] !== 'string'
    ) {
      return jsonResponse(401, { error: 'La sesión no es válida.' });
    }

    const headers = new Headers({
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=ignore-duplicates,return=representation',
    });
    const userId = (user as Record<string, string>)['id'];
    const existingAcceptance = await findAcceptance(
      supabaseUrl,
      headers,
      userId,
    );
    if (existingAcceptance) {
      return jsonResponse(200, {
        ok: true,
        terms_version: termsVersion,
        accepted_at: existingAcceptance,
      });
    }

    const insertUrl = new URL('/rest/v1/terms_acceptances', supabaseUrl);
    insertUrl.searchParams.set('on_conflict', 'user_id,terms_version');
    const insertResponse = await fetch(
      insertUrl,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({
          user_id: userId,
          terms_version: termsVersion,
          ip_address: getClientIp(request),
          user_agent: request.headers.get('user-agent') ?? '',
        }),
      },
    );
    if (!insertResponse.ok) {
      console.error('No se pudo guardar la aceptación de términos.');
      return jsonResponse(503, {
        error: 'No se pudo guardar tu aceptación. Inténtalo de nuevo.',
      });
    }

    const rows: unknown = await insertResponse.json();
    const first = Array.isArray(rows) ? rows[0] : null;
    const insertedAt =
      first && typeof first === 'object'
        ? (first as Record<string, unknown>)['accepted_at']
        : null;
    const acceptedAt =
      typeof insertedAt === 'string'
        ? insertedAt
        : await findAcceptance(supabaseUrl, headers, userId);
    if (typeof acceptedAt !== 'string') {
      console.error('La aceptación guardada no devolvió fecha.');
      return jsonResponse(503, {
        error: 'No se pudo confirmar el registro de aceptación.',
      });
    }

    return jsonResponse(200, {
      ok: true,
      terms_version: termsVersion,
      accepted_at: acceptedAt,
    });
  } catch (error) {
    console.error('Error interno al registrar la aceptación de términos.', error);
    return jsonResponse(502, {
      error: 'No se pudo registrar la aceptación. Inténtalo de nuevo.',
    });
  }
});
