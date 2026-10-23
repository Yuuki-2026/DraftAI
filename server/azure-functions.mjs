import { app } from '@azure/functions';
import { createHash } from 'node:crypto';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { ServiceError, executeAi, validateFiles, validateTransform } from './service.mjs';

const defaultTimeZone = 'America/Lima';
const adminAppName = 'draftai-azure-api';
const minuteRequests = new Map();

function setting(name, fallback = '') {
  return (process.env[name] ?? fallback).trim();
}

function integerSetting(name, fallback, minimum, maximum) {
  const value = Number(setting(name, String(fallback)));
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new ServiceError(503, 'La configuración del servidor no es válida.', 'server_configuration');
  }
  return value;
}

function currentDay() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: setting('AI_QUOTA_TIME_ZONE', defaultTimeZone),
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const part = (type) => parts.find((item) => item.type === type)?.value;
  return part('year') + '-' + part('month') + '-' + part('day');
}

function uidDocumentId(uid) {
  return createHash('sha256').update(uid).digest('hex');
}

function firebaseServices() {
  let firebaseApp = getApps().find((item) => item.name === adminAppName);
  if (!firebaseApp) {
    const projectId = setting('FIREBASE_PROJECT_ID');
    const credentialJson = setting('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!projectId || !credentialJson) {
      throw new ServiceError(503, 'La autenticación del servidor aún no está configurada.', 'server_configuration');
    }
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(credentialJson);
    } catch (_) {
      throw new ServiceError(503, 'La autenticación del servidor aún no está configurada.', 'server_configuration');
    }
    firebaseApp = initializeApp({
      credential: cert(serviceAccount),
      projectId,
    }, adminAppName);
  }
  return {
    auth: getAuth(firebaseApp),
    firestore: getFirestore(firebaseApp),
  };
}

class FirestoreUsage {
  constructor(firestore) {
    this.firestore = firestore;
    this.userCollection = firestore.collection('draftai_ai_usage');
    this.globalReference = firestore.collection('draftai_system').doc('provider_usage');
  }

  async reserveUser(uid, limit, day) {
    const reference = this.userCollection.doc(uidDocumentId(uid));
    await this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const data = snapshot.data();
      const used = data?.day === day ? Number(data.used ?? 0) : 0;
      if (!Number.isSafeInteger(used) || used < 0) {
        throw new ServiceError(503, 'No se pudo verificar el límite de uso.', 'quota_unavailable');
      }
      if (used >= limit) {
        throw new ServiceError(429, 'Alcanzaste el límite diario. Vuelve mañana.', 'daily_limit');
      }
      transaction.set(reference, {
        day,
        used: used + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    let refunded = false;
    return async () => {
      if (refunded) return;
      refunded = true;
      await this.firestore.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        const data = snapshot.data();
        if (data?.day !== day || !Number.isSafeInteger(data.used) || data.used <= 0) return;
        transaction.set(reference, {
          day,
          used: data.used - 1,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    };
  }

  async reserveProvider(limit, day) {
    await this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(this.globalReference);
      const data = snapshot.data();
      const calls = data?.day === day ? Number(data.calls ?? 0) : 0;
      if (!Number.isSafeInteger(calls) || calls < 0) {
        throw new ServiceError(503, 'No se pudo verificar el consumo del servidor.', 'budget_unavailable');
      }
      if (calls >= limit) {
        throw new ServiceError(429, 'El servidor alcanzó su límite global por hoy.', 'global_limit');
      }
      transaction.set(this.globalReference, {
        day,
        calls: calls + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  async snapshot(uid, day, userLimit) {
    const userReference = this.userCollection.doc(uidDocumentId(uid));
    const userSnapshot = await userReference.get();
    const userData = userSnapshot.data();
    const used = userData?.day === day ? Number(userData.used ?? 0) : 0;
    return {
      used,
      remaining: Math.max(0, userLimit - used),
      limit: userLimit,
    };
  }
}

function rateLimit(uid) {
  const now = Date.now();
  const bucket = Math.floor(now / 60_000);
  const key = uidDocumentId(uid) + ':' + bucket;
  const used = minuteRequests.get(key) ?? 0;
  if (used >= 4) {
    throw new ServiceError(429, 'Espera un minuto antes de reintentar.', 'rate_limit');
  }
  minuteRequests.set(key, used + 1);
  if (minuteRequests.size > 1000) {
    for (const [entry] of minuteRequests) {
      if (!entry.endsWith(':' + bucket)) minuteRequests.delete(entry);
    }
  }
}

function response(status, value) {
  return {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
    jsonBody: value,
  };
}

async function authenticatedUser(request, auth) {
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer ([^\s]+)$/.exec(header);
  if (!match) {
    throw new ServiceError(401, 'Inicia sesión con Google para usar la IA.', 'auth_required');
  }
  let decoded;
  try {
    decoded = await auth.verifyIdToken(match[1]);
  } catch (_) {
    throw new ServiceError(401, 'La sesión de Google venció. Vuelve a iniciar sesión.', 'auth_required');
  }
  if (decoded.firebase?.sign_in_provider !== 'google.com') {
    throw new ServiceError(403, 'La IA de DraftAI está disponible para cuentas de Google.', 'google_account_required');
  }
  return decoded;
}

async function readJson(request, maximumBytes) {
  const declaredLength = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new ServiceError(413, 'El contenido supera el tamaño permitido.', 'input_too_large');
  }
  const raw = await request.text();
  if (Buffer.byteLength(raw, 'utf8') > maximumBytes) {
    throw new ServiceError(413, 'El contenido supera el tamaño permitido.', 'input_too_large');
  }
  try {
    return JSON.parse(raw);
  } catch (_) {
    throw new ServiceError(400, 'El contenido enviado no es JSON válido.', 'invalid_input');
  }
}

async function handleRequest(request) {
  let refund = null;
  try {
    const path = new URL(request.url).pathname.replace(/^\/api/, '').replace(/\/+$/, '');
    const method = request.method.toUpperCase();
    const isStatus = method === 'GET' && path === '/v1/status';
    const isTransform = method === 'POST' && path === '/v1/transform';
    const isAnalyze = method === 'POST' && path === '/v1/analyze';
    if (!isStatus && !isTransform && !isAnalyze) {
      throw new ServiceError(404, 'Acción no disponible.', 'not_found');
    }

    const { auth, firestore } = firebaseServices();
    const user = await authenticatedUser(request, auth);
    const usage = new FirestoreUsage(firestore);
    const day = currentDay();
    const userLimit = integerSetting('AI_DAILY_LIMIT', 30, 1, 1000);
    const globalLimit = integerSetting('AI_GLOBAL_DAILY_LIMIT', 900, 1, 100_000);
    const model = setting('AI_MODEL');
    const visionModel = setting('AI_VISION_MODEL');
    if (isStatus) {
      if (!setting('AI_API_KEY') || !model) {
        throw new ServiceError(503, 'El servicio de IA aún no está configurado.', 'provider_configuration');
      }
      const current = await usage.snapshot(user.uid, day, userLimit);
      return response(200, {
        pro: false,
        vision: Boolean(visionModel),
        model,
        ...current,
      });
    }

    rateLimit(user.uid);
    const contentType = request.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().startsWith('application/json')) {
      throw new ServiceError(415, 'El contenido enviado no es JSON.', 'invalid_input');
    }
    const body = await readJson(request, isAnalyze ? 15_000_000 : 60_000);
    if (isTransform) validateTransform(body);
    if (isAnalyze) validateFiles(body);
    if (!setting('AI_API_KEY') || !model) {
      throw new ServiceError(503, 'El servicio de IA aún no está configurado.', 'provider_configuration');
    }
    if (isAnalyze && !visionModel) {
      throw new ServiceError(503, 'El servidor no tiene un modelo de imágenes configurado.', 'provider_configuration');
    }

    refund = await usage.reserveUser(user.uid, userLimit, day);
    const config = {
      key: setting('AI_API_KEY'),
      model,
      visionModel,
      url: 'https://api.openai.com/v1/chat/completions',
      reserveProvider: () => usage.reserveProvider(globalLimit, day),
      signal: request.signal,
    };
    const result = await executeAi(isTransform ? '/v1/transform' : '/v1/analyze', body, config);
    refund = null;
    return response(200, result);
  } catch (error) {
    if (refund) {
      try {
        await refund();
      } catch (_) {
        // Keep the original request error; the quota document can be reconciled by support.
      }
    }
    if (error instanceof ServiceError) {
      return response(error.status, { error: error.message, code: error.code });
    }
    return response(502, {
      error: 'No se pudo completar la solicitud. Tus apuntes se conservan.',
      code: 'provider_unavailable',
    });
  }
}

app.http('draftaiApi', {
  methods: ['GET', 'POST'],
  authLevel: 'anonymous',
  route: 'v1/{action}',
  handler: async (request) => handleRequest(request),
});
