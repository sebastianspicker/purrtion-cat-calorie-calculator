/** Calendar dates are strict `YYYY-MM-DD` strings, parsed as UTC midnight (ENGINE.md §2). */
const MS_PER_DAY = 86_400_000;
export function isISODate(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [y, m, d] = value.split('-').map(Number) as [number, number, number];
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}
export function parseISODate(value: string): number {
  if (!isISODate(value)) throw new RangeError(`Expected a valid YYYY-MM-DD date, got ${JSON.stringify(value)}`);
  return Date.parse(`${value}T00:00:00Z`);
}
/** days(a, b) = (b − a) / 86 400 000 */
export function daysBetween(from: string, to: string): number {
  return (parseISODate(to) - parseISODate(from)) / MS_PER_DAY;
}
/** Today's date in the user's local time zone; the UI passes this as `asOf`. */
export function todayLocalISO(now: Date = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}
