// Path/body params are attacker-controlled strings. Passing a non-numeric
// value straight to a parameterized query against an integer column makes
// Postgres throw a type-cast error (22P02) that isn't a constraint violation,
// so it isn't mapped to a clean 4xx by the generic error handler -- it falls
// through as a 500. Validate at the boundary instead.
export function parsePositiveInt(value: unknown): number | null {
  if (typeof value !== 'string' || !/^\d+$/.test(value)) return null;
  const n = Number(value);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
}
