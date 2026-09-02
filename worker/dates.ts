const DATE = /^\d{4}-\d{2}-\d{2}$/;

export function isDate(value: unknown): value is string {
  return typeof value === 'string' && DATE.test(value);
}

export function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export function dateOr(value: unknown): string {
  return isDate(value) ? value : today();
}

export function daysAgo(days: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}
