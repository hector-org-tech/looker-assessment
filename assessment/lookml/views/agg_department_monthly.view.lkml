# One row per department per calendar month. Built by Dataform
# (definitions/gold/agg_department_monthly.sqlx). Every metric was computed at its
# own grain before the join, so all SUM measures here are exact.

view: agg_department_monthly {
  sql_table_name: gold.agg_department_monthly ;;

  # ---------------------------------------------------------------------------
  # Parameter: which period the KPI tiles compare against
  # ---------------------------------------------------------------------------
  parameter: comparison_period {
    label: "Compare With"
    description: "Period used by the 'comparison' measures. 'Same period last year' works for any selection. 'Previous quarter' is only meaningful when you select whole fiscal quarters."
    type: unquoted
    allowed_value: { label: "Same period last year" value: "prior_year" }
    allowed_value: { label: "Previous quarter"      value: "prior_quarter" }
    default_value: "prior_year"
  }

  # ---------------------------------------------------------------------------
  # Keys (hidden)
  # ---------------------------------------------------------------------------
  dimension: department_month_key {
    primary_key: yes
    hidden: yes
    type: string
    sql: ${TABLE}.department_month_key ;;
  }

  dimension: department_id {
    hidden: yes
    type: string
    sql: ${TABLE}.department_id ;;
  }

  # ---------------------------------------------------------------------------
  # Time
  # ---------------------------------------------------------------------------
  dimension_group: period {
    label: "Payroll"
    description: "Calendar month in which the payroll was PAID (pay date). Fiscal timeframes follow the July-June fiscal year."
    type: time
    timeframes: [raw, month, month_name, quarter, year, fiscal_month_num, fiscal_quarter, fiscal_quarter_of_year, fiscal_year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.month_start_date ;;
  }

  dimension: fiscal_year {
    group_label: "Fiscal Calendar"
    label: "Fiscal Year"
    description: "July to June, named after the year it ends. FY2026 = July 2025 to June 2026."
    type: string
    sql: ${TABLE}.fiscal_year ;;
  }

  dimension: fiscal_quarter {
    group_label: "Fiscal Calendar"
    label: "Fiscal Quarter"
    description: "FY2027-Q1 = July to September 2026."
    type: string
    sql: ${TABLE}.fiscal_quarter ;;
  }

  dimension: fiscal_period {
    group_label: "Fiscal Calendar"
    label: "Fiscal Period (1-12)"
    description: "1 = July ... 12 = June."
    type: number
    sql: ${TABLE}.fiscal_period ;;
  }

  dimension: month_end_date {
    hidden: yes
    type: date
    convert_tz: no
    sql: ${TABLE}.month_end_date ;;
  }

  dimension: pay_runs_in_month {
    group_label: "Fiscal Calendar"
    label: "Pay Runs in Month"
    description: "Payroll is biweekly: most months have 2 pay dates, two months a year have 3. Months with 3 pay runs look about 50% more expensive than budget."
    type: number
    sql: ${TABLE}.pay_runs_in_month ;;
    html:
      {% if value == 3 %}<span title="3 pay runs this month">{{ rendered_value }} &#9873;</span>
      {% else %}{{ rendered_value }}{% endif %} ;;
  }

  # ---------------------------------------------------------------------------
  # Payroll cost
  # ---------------------------------------------------------------------------
  measure: gross_payroll {
    group_label: "Payroll Cost"
    label: "Gross Payroll"
    description: "Sum of all valid earning lines (regular, overtime, PTO, bonus), assigned to the month of the pay date and to the cost center charged on the line. Voided lines, duplicates and test accounts are excluded."
    type: sum
    sql: ${TABLE}.gross_payroll_usd ;;
    value_format_name: usd_compact
    drill_fields: [drill_department_cost*]
    link: {
      label: "See cost lines for this department"
      url: "/explore/workforce_payroll/fct_payroll_cost?fields=dim_department.department_name,fct_payroll_cost.pay_month,fct_payroll_cost.cost_type,fct_payroll_cost.total_cost&f[dim_department.department_name]={{ dim_department.department_name._value | url_encode }}&sorts=fct_payroll_cost.pay_month+desc"
    }
  }

  measure: regular_earnings {
    group_label: "Payroll Cost"
    label: "Regular Earnings"
    type: sum
    sql: ${TABLE}.regular_earnings_usd ;;
    value_format_name: usd_compact
  }

  measure: overtime_cost {
    group_label: "Overtime"
    label: "Overtime Cost"
    description: "Earnings with earning type OVERTIME."
    type: sum
    sql: ${TABLE}.overtime_earnings_usd ;;
    value_format_name: usd_compact
    drill_fields: [drill_department_overtime*]
  }

  measure: overtime_hours {
    group_label: "Overtime"
    label: "Overtime Hours"
    type: sum
    sql: ${TABLE}.overtime_hours ;;
    value_format_name: decimal_0
  }

  measure: pto_earnings {
    group_label: "Payroll Cost"
    label: "PTO Earnings"
    type: sum
    sql: ${TABLE}.pto_earnings_usd ;;
    value_format_name: usd_compact
  }

  measure: bonus_earnings {
    group_label: "Payroll Cost"
    label: "Bonus Earnings"
    type: sum
    sql: ${TABLE}.bonus_earnings_usd ;;
    value_format_name: usd_compact
  }

  measure: employer_cost {
    group_label: "Payroll Cost"
    label: "Employer Cost"
    description: "Employer contributions paid on top of gross pay: FICA, health insurance and retirement match, for the pay runs paid in the period."
    type: sum
    sql: ${TABLE}.employer_cost_usd ;;
    value_format_name: usd_compact
    drill_fields: [drill_department_cost*]
  }

  measure: fica_cost {
    group_label: "Payroll Cost"
    label: "Employer FICA"
    type: sum
    sql: ${TABLE}.fica_usd ;;
    value_format_name: usd_compact
  }

  measure: health_insurance_cost {
    group_label: "Payroll Cost"
    label: "Employer Health Insurance"
    type: sum
    sql: ${TABLE}.health_insurance_usd ;;
    value_format_name: usd_compact
  }

  measure: retirement_match_cost {
    group_label: "Payroll Cost"
    label: "Employer Retirement Match"
    type: sum
    sql: ${TABLE}.retirement_match_usd ;;
    value_format_name: usd_compact
  }

  measure: fully_loaded_cost {
    group_label: "Payroll Cost"
    label: "Fully Loaded Payroll Cost"
    description: "Gross payroll + employer cost: what the payroll really costs the organisation."
    type: number
    sql: ${gross_payroll} + ${employer_cost} ;;
    value_format_name: usd_compact
    drill_fields: [drill_department_cost*]
  }

  measure: overtime_pct {
    group_label: "Overtime"
    label: "Overtime %"
    description: "Overtime earnings / gross payroll."
    type: number
    sql: SAFE_DIVIDE(${overtime_cost}, ${gross_payroll}) ;;
    value_format_name: percent_1
    drill_fields: [drill_department_overtime*]
  }

  # ---------------------------------------------------------------------------
  # Budget
  # ---------------------------------------------------------------------------
  measure: budgeted_gross_payroll {
    group_label: "Budget"
    label: "Budgeted Gross Payroll"
    type: sum
    sql: ${TABLE}.budgeted_gross_payroll_usd ;;
    value_format_name: usd_compact
  }

  measure: budget_variance_usd {
    group_label: "Budget"
    label: "Budget Variance ($)"
    description: "Actual gross payroll - budgeted gross payroll. Positive = over budget."
    type: number
    sql: ${gross_payroll} - ${budgeted_gross_payroll} ;;
    value_format_name: usd_compact
    drill_fields: [drill_department_budget*]
  }

  measure: extra_pay_run_months {
    group_label: "Budget"
    label: "Months with 3 Pay Runs"
    description: "Number of months in the selection that had 3 biweekly pay runs instead of 2. Explains spikes against a flat monthly budget."
    type: count_distinct
    sql: CASE WHEN ${TABLE}.pay_runs_in_month >= 3 THEN ${TABLE}.month_start_date END ;;
  }

  measure: budget_variance_pct {
    group_label: "Budget"
    label: "Budget Variance %"
    description: "(Actual gross payroll / budgeted gross payroll) - 1. Green = at or under budget, amber = up to 2% over, red = more than 2% over."
    type: number
    sql: SAFE_DIVIDE(${gross_payroll}, ${budgeted_gross_payroll}) - 1 ;;
    value_format_name: percent_1
    drill_fields: [drill_department_budget*]
    # LIQUID 1: conditional colour. If the selection contains a 3-pay-run month
    # (only when that measure is in the query) we add a flag so nobody panics
    # about a +40% month that is really a calendar effect.
    html:
      {% if value == nil %}<span style="color:#6b7280;">no budget</span>
      {% elsif value > 0.02 %}<span style="color:#b42318; font-weight:600;">&#9650; {{ rendered_value }} over</span>
      {% elsif value > 0 %}<span style="color:#b54708; font-weight:600;">&#9650; {{ rendered_value }} over</span>
      {% else %}<span style="color:#067647; font-weight:600;">&#9660; {{ rendered_value | remove: '-' }} under</span>
      {% endif %}
      {% if extra_pay_run_months._in_query and extra_pay_run_months._value > 0 %}
        <br><span style="color:#6b7280; font-size:11px;">&#9873; includes {{ extra_pay_run_months._value }} month(s) with 3 pay runs</span>
      {% endif %} ;;
  }

  # CUSTOM VISUAL ELEMENT: an inline bullet bar (actual vs budget with a marker at
  # 100%). Native Looker bar charts cannot draw a per-row target marker with
  # threshold colours, and a custom JS visualization would need hosting and a
  # deployment process. This is plain HTML in LookML: versioned with the model.
  measure: budget_bullet {
    group_label: "Budget"
    label: "Budget Usage"
    description: "Visual: actual gross payroll as a share of budget. The black line marks 100% of budget."
    type: number
    sql: SAFE_DIVIDE(${gross_payroll}, ${budgeted_gross_payroll}) ;;
    value_format_name: percent_0
    html:
      {% assign pct = value | times: 100.0 %}
      {% assign bar = pct | times: 0.8 %}{% if bar > 100 %}{% assign bar = 100 %}{% endif %}
      {% if pct > 102 %}{% assign colour = '#d92d20' %}{% elsif pct > 100 %}{% assign colour = '#f79009' %}{% else %}{% assign colour = '#12b76a' %}{% endif %}
      <div style="display:flex; align-items:center; gap:8px; min-width:220px;">
        <div style="position:relative; flex:1; height:14px; background:#f2f4f7; border-radius:3px;">
          <div style="position:absolute; left:0; top:0; height:14px; width:{{ bar }}%; background:{{ colour }}; border-radius:3px;"></div>
          <div style="position:absolute; left:80%; top:-3px; height:20px; border-left:2px solid #101828;"></div>
        </div>
        <span style="width:44px; text-align:right; font-variant-numeric:tabular-nums;">{{ rendered_value }}</span>
      </div> ;;
  }

  # ---------------------------------------------------------------------------
  # Headcount and turnover
  # ---------------------------------------------------------------------------
  # Headcount is SEMI-ADDITIVE: it adds up across departments but NOT across months
  # (a quarter's headcount is the headcount on its last day, not the sum of three
  # month-ends). The measure collects (month, headcount) pairs of the rows in each
  # result row and sums only the pairs of the latest month. It therefore answers
  # "headcount at the end of the period" whatever the grouping: month, quarter,
  # fiscal year, or no time dimension at all.
  # Safe here because this explore has no one_to_many joins (no fan-out).
  measure: headcount {
    group_label: "Workforce"
    label: "Headcount (end of period)"
    description: "Full-time and part-time employees active on the last day of the period (contractors excluded). Active = hired on or before that day and not terminated on or before that day."
    type: number
    sql: (SELECT SUM(x.hc) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.headcount_month_end AS hc))) AS x
          WHERE x.m = (SELECT MAX(y.m) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.headcount_month_end AS hc))) AS y)) ;;
    value_format_name: decimal_0
    drill_fields: [drill_department_workforce*]
    link: {
      label: "List the employees"
      url: "/explore/workforce_payroll/fct_workforce_month_end?fields=fct_workforce_month_end.snapshot_month,dim_employee.full_name,dim_employee.job_title,dim_department.department_name,dim_employee.employment_type,dim_employee.hire_date&f[dim_department.department_name]={{ dim_department.department_name._value | url_encode }}{% if period_month._in_query %}&f[fct_workforce_month_end.snapshot_month]={{ period_month._value | url_encode }}{% endif %}"
    }
  }

  measure: budgeted_headcount {
    group_label: "Budget"
    label: "Budgeted Headcount (end of period)"
    type: number
    sql: (SELECT SUM(x.hc) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.budgeted_headcount AS hc))) AS x
          WHERE x.m = (SELECT MAX(y.m) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.budgeted_headcount AS hc))) AS y)) ;;
    value_format_name: decimal_0
  }

  measure: average_headcount {
    group_label: "Workforce"
    label: "Average Month-end Headcount"
    description: "Average of the month-end headcounts in the period. Denominator of the turnover rate."
    type: number
    sql: SAFE_DIVIDE(SUM(${TABLE}.headcount_month_end), COUNT(DISTINCT ${TABLE}.month_start_date)) ;;
    value_format_name: decimal_1
  }

  measure: voluntary_terminations {
    group_label: "Workforce"
    label: "Voluntary Leavers"
    description: "Employees who resigned (termination reason VOLUNTARY) with a termination date in the period."
    type: sum
    sql: ${TABLE}.voluntary_terminations ;;
    value_format_name: decimal_0
    drill_fields: [drill_department_workforce*]
  }

  measure: total_terminations {
    group_label: "Workforce"
    label: "All Leavers"
    description: "Voluntary, involuntary and retirement."
    type: sum
    sql: ${TABLE}.total_terminations ;;
    value_format_name: decimal_0
  }

  measure: voluntary_turnover_rate {
    group_label: "Workforce"
    label: "Voluntary Turnover Rate"
    description: "Voluntary leavers in the period / average month-end headcount of the period. Not annualised: a quarter shows a quarterly rate."
    type: number
    sql: SAFE_DIVIDE(${voluntary_terminations}, ${average_headcount}) ;;
    value_format_name: percent_1
    drill_fields: [drill_department_workforce*]
  }

  # ---------------------------------------------------------------------------
  # Prior-period values (hidden building blocks)
  # A prior value is returned only when EVERY month of the selection has one, so a
  # partially available comparison never shows a misleading number.
  # ---------------------------------------------------------------------------
  measure: gross_payroll_prior_year {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.gross_payroll_usd_prior_year) = COUNT(*) THEN SUM(${TABLE}.gross_payroll_usd_prior_year) END ;;
  }
  measure: gross_payroll_prior_quarter {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.gross_payroll_usd_prior_quarter) = COUNT(*) THEN SUM(${TABLE}.gross_payroll_usd_prior_quarter) END ;;
  }
  measure: overtime_cost_prior_year {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.overtime_earnings_usd_prior_year) = COUNT(*) THEN SUM(${TABLE}.overtime_earnings_usd_prior_year) END ;;
  }
  measure: overtime_cost_prior_quarter {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.overtime_earnings_usd_prior_quarter) = COUNT(*) THEN SUM(${TABLE}.overtime_earnings_usd_prior_quarter) END ;;
  }
  measure: fully_loaded_cost_prior_year {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.fully_loaded_cost_usd_prior_year) = COUNT(*) THEN SUM(${TABLE}.fully_loaded_cost_usd_prior_year) END ;;
  }
  measure: fully_loaded_cost_prior_quarter {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.fully_loaded_cost_usd_prior_quarter) = COUNT(*) THEN SUM(${TABLE}.fully_loaded_cost_usd_prior_quarter) END ;;
  }
  measure: headcount_prior_year {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.headcount_month_end_prior_year) = COUNT(*) THEN
         (SELECT SUM(x.hc) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.headcount_month_end_prior_year AS hc))) AS x
          WHERE x.m = (SELECT MAX(y.m) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.headcount_month_end_prior_year AS hc))) AS y)) END ;;
  }
  measure: headcount_prior_quarter {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.headcount_month_end_prior_quarter) = COUNT(*) THEN
         (SELECT SUM(x.hc) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.headcount_month_end_prior_quarter AS hc))) AS x
          WHERE x.m = (SELECT MAX(y.m) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS m, ${TABLE}.headcount_month_end_prior_quarter AS hc))) AS y)) END ;;
  }
  measure: voluntary_turnover_rate_prior_year {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.headcount_month_end_prior_year) = COUNT(*) THEN
         SAFE_DIVIDE(SUM(${TABLE}.voluntary_terminations_prior_year),
                     SAFE_DIVIDE(SUM(${TABLE}.headcount_month_end_prior_year), COUNT(DISTINCT ${TABLE}.month_start_date))) END ;;
  }
  measure: voluntary_turnover_rate_prior_quarter {
    hidden: yes
    type: number
    sql: CASE WHEN COUNT(${TABLE}.headcount_month_end_prior_quarter) = COUNT(*) THEN
         SAFE_DIVIDE(SUM(${TABLE}.voluntary_terminations_prior_quarter),
                     SAFE_DIVIDE(SUM(${TABLE}.headcount_month_end_prior_quarter), COUNT(DISTINCT ${TABLE}.month_start_date))) END ;;
  }

  # ---------------------------------------------------------------------------
  # Comparison measures (LIQUID 2: label and SQL follow the Compare With parameter)
  # ---------------------------------------------------------------------------
  measure: gross_payroll_comparison {
    group_label: "Comparison"
    label: "Gross Payroll – {% if comparison_period._parameter_value == 'prior_quarter' %}Previous Quarter{% else %}Same Period Last Year{% endif %}"
    type: number
    sql: {% if comparison_period._parameter_value == 'prior_quarter' %}${gross_payroll_prior_quarter}{% else %}${gross_payroll_prior_year}{% endif %} ;;
    value_format_name: usd_compact
  }

  measure: fully_loaded_cost_comparison {
    group_label: "Comparison"
    label: "Fully Loaded Cost – {% if comparison_period._parameter_value == 'prior_quarter' %}Previous Quarter{% else %}Same Period Last Year{% endif %}"
    type: number
    sql: {% if comparison_period._parameter_value == 'prior_quarter' %}${fully_loaded_cost_prior_quarter}{% else %}${fully_loaded_cost_prior_year}{% endif %} ;;
    value_format_name: usd_compact
  }

  measure: overtime_cost_comparison {
    group_label: "Comparison"
    label: "Overtime Cost – {% if comparison_period._parameter_value == 'prior_quarter' %}Previous Quarter{% else %}Same Period Last Year{% endif %}"
    type: number
    sql: {% if comparison_period._parameter_value == 'prior_quarter' %}${overtime_cost_prior_quarter}{% else %}${overtime_cost_prior_year}{% endif %} ;;
    value_format_name: usd_compact
  }

  measure: overtime_pct_comparison {
    group_label: "Comparison"
    label: "Overtime % – {% if comparison_period._parameter_value == 'prior_quarter' %}Previous Quarter{% else %}Same Period Last Year{% endif %}"
    type: number
    sql: {% if comparison_period._parameter_value == 'prior_quarter' %}SAFE_DIVIDE(${overtime_cost_prior_quarter}, ${gross_payroll_prior_quarter})
         {% else %}SAFE_DIVIDE(${overtime_cost_prior_year}, ${gross_payroll_prior_year}){% endif %} ;;
    value_format_name: percent_1
  }

  measure: headcount_comparison {
    group_label: "Comparison"
    label: "Headcount – {% if comparison_period._parameter_value == 'prior_quarter' %}Previous Quarter{% else %}Same Period Last Year{% endif %}"
    type: number
    sql: {% if comparison_period._parameter_value == 'prior_quarter' %}${headcount_prior_quarter}{% else %}${headcount_prior_year}{% endif %} ;;
    value_format_name: decimal_0
  }

  measure: voluntary_turnover_rate_comparison {
    group_label: "Comparison"
    label: "Voluntary Turnover – {% if comparison_period._parameter_value == 'prior_quarter' %}Previous Quarter{% else %}Same Period Last Year{% endif %}"
    type: number
    sql: {% if comparison_period._parameter_value == 'prior_quarter' %}${voluntary_turnover_rate_prior_quarter}{% else %}${voluntary_turnover_rate_prior_year}{% endif %} ;;
    value_format_name: percent_1
  }

  measure: gross_payroll_change_pct {
    group_label: "Comparison"
    label: "Gross Payroll Change %"
    type: number
    sql: SAFE_DIVIDE(${gross_payroll}, ${gross_payroll_comparison}) - 1 ;;
    value_format_name: percent_1
  }

  # ---------------------------------------------------------------------------
  # Drill sets
  # ---------------------------------------------------------------------------
  set: drill_department_cost {
    fields: [dim_department.division, dim_department.department_name, period_month, gross_payroll, employer_cost, fully_loaded_cost]
  }
  set: drill_department_overtime {
    fields: [dim_department.division, dim_department.department_name, period_month, overtime_hours, overtime_cost, gross_payroll, overtime_pct]
  }
  set: drill_department_budget {
    fields: [dim_department.division, dim_department.department_name, period_month, pay_runs_in_month, gross_payroll, budgeted_gross_payroll, budget_variance_usd, budget_variance_pct]
  }
  set: drill_department_workforce {
    fields: [dim_department.division, dim_department.department_name, period_month, headcount, voluntary_terminations, total_terminations]
  }
}
