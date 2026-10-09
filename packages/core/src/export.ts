import type { CalculateOptions, Plan } from './models.js';
import { calculatePlan } from './calculation.js';
import { parsePlan } from './validation.js';
/** Always writes schema v2, with explicit nulls for empty nullable fields. */
export function planToJSON(plan: unknown): string { return JSON.stringify(parsePlan(plan), null, 2) + '\n'; }
function csv(value: string | number): string {
  let text = String(value);
  // Prevent a cat/food name from becoming a spreadsheet formula when the CSV is opened.
  if (/^[=+@\-\t\r\n]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}
export function planToCSV(input: unknown, options: CalculateOptions): string {
  const plan: Plan = parsePlan(input), result = calculatePlan(plan, options);
  const rows: (string | number)[][] = [['Cat', 'Weight (kg)', 'Goal', 'Target (kcal/day)', 'Fixed meals (g/day)', 'Fixed meals (kcal/day)',
    'Extras (kcal/day)', 'Balance food', 'Balance food calculated (g/day)', 'Balance food rounded (g/day)', 'Calories after rounding',
    'Estimate status', 'Estimate start (kcal/day)', 'Estimate range (kcal/day)', 'Warnings']];
  for (const cat of plan.cats) {
    const r = result.cats.find(item => item.id === cat.id)!, e = r.estimate;
    rows.push([cat.name, cat.weightKg, cat.goal, cat.targetKcal, r.fixedGrams, r.fixedKcal, cat.extraKcal,
      plan.foods.find(f => f.id === cat.balanceFoodId)!.name, r.balanceGramsExact.toFixed(4), r.balanceGramsRounded,
      r.roundedDailyKcal.toFixed(2), e.status, e.startKcal === null ? '' : e.startKcal.toFixed(0),
      e.lowKcal === null || e.highKcal === null ? '' : `${e.lowKcal.toFixed(0)}–${e.highKcal.toFixed(0)}`, r.warnings.join('; ')]);
  }
  return rows.map(row => row.map(csv).join(',')).join('\r\n') + '\r\n';
}
