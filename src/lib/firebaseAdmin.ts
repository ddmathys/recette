import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

/**
 * Server-only Firebase Admin init, used to write Firestore rate-limit
 * counters from API routes. Two credential sources:
 *  - Production (Vercel): FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL /
 *    FIREBASE_PRIVATE_KEY env vars (set in the Vercel project, never
 *    committed).
 *  - Local dev: falls back to serviceAccountKey.json at the repo root
 *    (gitignored — same file used by scripts/seed.ts).
 */
function getAdminApp(): App | null {
  if (getApps().length) return getApps()[0];

  // Never let a bad credential (malformed key, missing file, ...) crash the
  // whole route with an unhandled exception — routes must always get back
  // a usable (null) admin handle and produce a proper JSON error instead.
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

    if (projectId && clientEmail && privateKey) {
      return initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
    }

    // Local dev fallback only. Using fs.readFileSync (not require()) on
    // purpose: a require() of a relative JSON path gets statically picked
    // up by Next.js's serverless file tracer at build time even though this
    // branch never runs in prod (env vars are set there) — the file doesn't
    // exist in the deployed bundle (gitignored), and that mismatch crashed
    // every request in prod with an opaque "Failed to load external module"
    // before any of our try/catch could run. fs calls aren't traced the
    // same way, so a missing file here is just a normal, catchable error.
    const keyPath = join(process.cwd(), "serviceAccountKey.json");
    if (!existsSync(keyPath)) return null;
    const serviceAccount = JSON.parse(readFileSync(keyPath, "utf8"));
    return initializeApp({ credential: cert(serviceAccount) });
  } catch (e) {
    console.error("[firebaseAdmin] init failed:", e instanceof Error ? e.message : e);
    return null;
  }
}

const adminApp = getAdminApp();

export const adminDb = adminApp ? getFirestore(adminApp) : null;

// ID token verification deliberately does NOT use firebase-admin/auth's
// verifyIdToken: that module pulls in jwks-rsa, which depends on an
// ESM-only build of `jose`. Under Next's Turbopack production bundler that
// require()/ESM mismatch crashed *every* request to this route with an
// opaque "Failed to load external module" — see git history for the
// debugging trail. Verifying the token ourselves with `jose` directly
// (ESM-native, no CJS interop) against Google's public JWKS sidesteps the
// broken dependency entirely and is the standard way to verify Firebase ID
// tokens outside the Admin SDK.
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

/** Verifies the `Authorization: Bearer <idToken>` header. Returns the
 * caller's uid, or null if missing/invalid — routes decide what to do
 * with that (this project has no anonymous access by design). */
export async function requireUser(req: Request): Promise<string | null> {
  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  if (!projectId) return null;

  const header = req.headers.get("authorization") || req.headers.get("Authorization");
  const token = header?.match(/^Bearer (.+)$/)?.[1];
  if (!token) return null;

  try {
    const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}
