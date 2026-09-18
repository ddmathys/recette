import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // firebase-admin (used server-side in src/lib/firebaseAdmin.ts) pulls in
  // @google-cloud/firestore's gRPC/protobuf stack, which loads some of its
  // own files at runtime via relative paths. Next's default serverless file
  // tracing doesn't always catch those, which crashed every request in
  // production with an opaque "Failed to load external module" — marking
  // the package external makes Next ship it from node_modules as-is
  // instead of tracing/bundling it.
  serverExternalPackages: ["firebase-admin"],
};

export default nextConfig;
