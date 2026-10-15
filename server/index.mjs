import {createServer} from 'node:http';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {ServiceError, DailyQuota, executeAi} from './service.mjs';

initializeApp({credential: applicationDefault(), projectId: process.env.FIREBASE_PROJECT_ID});
const quota = new DailyQuota();
const allowed = new Set((process.env.DEMO_PRO_UIDS ?? '').split(',').map(s => s.trim()).filter(Boolean));
const config = {key: process.env.AI_API_KEY, model: process.env.AI_MODEL, url: process.env.AI_UPSTREAM_URL};
const server = createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  let refund;
  try {
    if (req.method !== 'POST' || !['/v1/transform', '/v1/analyze'].includes(req.url)) throw new ServiceError(404, 'Ruta no disponible.');
    const token = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1];
    if (!token) throw new ServiceError(401, 'Autenticación requerida.');
    let user;
    try { user = await getAuth().verifyIdToken(token, true); }
    catch { throw new ServiceError(401, 'Sesión no válida.'); }
    const pro = allowed.has(user.uid);
    if (req.url === '/v1/analyze' && !pro) throw new ServiceError(403, 'OCR no habilitado para esta cuenta.');
    let total = 0; const chunks = [];
    for await (const chunk of req) {
      total += chunk.length;
      if (total > 36 * 1024 * 1024) throw new ServiceError(413, 'Lote demasiado grande.');
      chunks.push(chunk);
    }
    let body;
    try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
    catch { throw new ServiceError(400, 'JSON no válido.'); }
    refund = quota.reserve(user.uid, pro);
    const result = await executeAi(req.url, body, config);
    res.writeHead(200); res.end(JSON.stringify(result));
  } catch (error) {
    refund?.();
    res.writeHead(error instanceof ServiceError ? error.status : 502);
    res.end(JSON.stringify({error: error instanceof ServiceError ? error.message : 'No se pudo completar la solicitud.'}));
    // Deliberately do not log request bodies, credentials or provider responses.
  }
});
server.requestTimeout = 100000;
server.listen(Number(process.env.PORT ?? 8787), '127.0.0.1', () => console.log('DraftAI gateway listo. Publicar mediante un proxy HTTPS.'));
