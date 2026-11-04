-- BigQuery SQL behind the four answers in README.md.
-- All of them read the gold layer, i.e. the same table the Looker explore
-- `department_monthly` (and the dashboard) uses, so the README and the dashboard
-- cannot disagree.

-- Q1 Fully loaded payroll cost in FY2026
SELECT
  fiscal_year,
  ROUND(SUM(gross_payroll_usd), 2)                       AS gross_payroll_usd,
  ROUND(SUM(employer_cost_usd), 2)                       AS employer_cost_usd,
  ROUND(SUM(gross_payroll_usd + employer_cost_usd), 2)   AS fully_loaded_cost_usd
FROM ${ref("agg_department_monthly")}
WHERE fiscal_year = 'FY2026'
GROUP BY fiscal_year;

-- Q2 Overtime % by department in Q1 FY2027 (July to September 2026)
SELECT
  d.department_name,
  ROUND(SUM(a.overtime_earnings_usd), 2)                                  AS overtime_usd,
  ROUND(SUM(a.gross_payroll_usd), 2)                                      AS gross_payroll_usd,
  ROUND(100 * SUM(a.overtime_earnings_usd) / SUM(a.gross_payroll_usd), 2) AS overtime_pct
FROM ${ref("agg_department_monthly")} AS a
JOIN ${ref("dim_department")} AS d USING (department_id)
WHERE a.fiscal_quarter = 'FY2027-Q1'
GROUP BY d.department_name
ORDER BY overtime_pct DESC;

-- Q3 Voluntary turnover rate in FY2026
SELECT
  SUM(voluntary_terminations)                                               AS voluntary_terminations,
  SUM(headcount_month_end) / COUNT(DISTINCT month_start_date)               AS avg_month_end_headcount,
  ROUND(100 * SUM(voluntary_terminations)
        / (SUM(headcount_month_end) / COUNT(DISTINCT month_start_date)), 2) AS voluntary_turnover_pct
FROM ${ref("agg_department_monthly")}
WHERE fiscal_year = 'FY2026';

-- Q4 Headcount on September 30, 2026
SELECT
  month_end_date,
  SUM(headcount_month_end)            AS headcount,
  SUM(full_time_headcount_month_end)  AS full_time,
  SUM(part_time_headcount_month_end)  AS part_time
FROM ${ref("agg_department_monthly")}
WHERE month_end_date = DATE '2026-09-30'
GROUP BY month_end_date;
