// build-version: /version answers which build is live without playing
// (openspec/changes/build-version). scripts/build-web.sh writes the record to
// build/web/version.json (scripts/build-version.mjs).

/** The version address: /version, with or without a trailing slash. */
export function isVersionPath(pathname) {
  return /^\/version\/?$/i.test(pathname);
}

const headers = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'access-control-allow-origin': '*',
  'x-content-type-options': 'nosniff',
};

/** The build record as JSON, never cached; 404 `{version: 'unknown'}` without one. */
export async function handleVersion(request, env) {
  if (!['GET', 'HEAD'].includes(request.method)) {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
  }
  let record = null;
  try {
    // Missing assets fall back to the SPA shell (HTML), so parse to be sure.
    const res = await env.ASSETS.fetch(new Request(new URL('/version.json', request.url)));
    if (res.ok) record = await res.json();
  } catch {
    record = null;
  }
  if (!record || typeof record.version !== 'string') {
    return new Response(JSON.stringify({ version: 'unknown' }), { status: 404, headers });
  }
  return new Response(JSON.stringify(record), { headers: { ...headers, 'x-build-version': record.version } });
}
