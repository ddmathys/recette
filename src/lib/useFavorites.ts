"use client";

import { useSyncExternalStore } from "react";

const KEY = "tiroir-favs";

// Module-level cache + tiny pub/sub, read/written through useSyncExternalStore
// below. This is the React-recommended way to read an external mutable
// source (localStorage) without a hydration mismatch: getServerSnapshot
// always returns an empty set (matching the prerendered HTML, which can't
// know the visitor's localStorage), and React reconciles the real value in
// on the client right after hydration — no manual setState-in-effect needed,
// which also avoids the "cascading renders" lint rule on that pattern.
let cached: Set<string> | null = null;
const listeners = new Set<() => void>();
const EMPTY = new Set<string>();

function readFavs(): Set<string> {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? new Set(JSON.parse(raw)) : new Set();
  } catch {
    return new Set();
  }
}

function getSnapshot(): Set<string> {
  if (!cached) cached = readFavs();
  return cached;
}

function getServerSnapshot(): Set<string> {
  return EMPTY;
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function persist(next: Set<string>) {
  cached = next;
  try {
    localStorage.setItem(KEY, JSON.stringify(Array.from(next)));
  } catch {
    /* ignore */
  }
  for (const l of listeners) l();
}

export function useFavorites() {
  const favs = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  function toggle(id: string) {
    const next = new Set(favs);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    persist(next);
  }

  return { favs, toggle };
}
