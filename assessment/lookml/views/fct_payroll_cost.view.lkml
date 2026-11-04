# One row per cost component: a valid earning line OR an employer contribution.
# Built in Dataform by stacking (UNION ALL) the two facts at a common grain, so that
# gross payroll, employer cost and fully loaded cost are plain filtered SUMs and can
# be broken down by any dimension without fan-out.

view: fct_payroll_cost {
  sql_table_name: gold.fct_payroll_cost ;;

  dimension: cost_component_id {
    primary_key: yes
    hidden: yes
    type: string
    sql: ${TABLE}.cost_component_id ;;
  }

  dimension: department_id {
    hidden: yes
    type: string
    sql: ${TABLE}.department_id ;;
  }

  # Individual employee key: only for HR and Finance. Managers can count employees
  # (measure below) but cannot group by person.
  dimension: employee_id {
    hidden: yes
    type: string
    sql: ${TABLE}.employee_id ;;
    required_access_grants: [can_see_individual_pay]
  }

  dimension: cost_category {
    label: "Cost Category"
    description: "EARNINGS (part of gross payroll) or EMPLOYER_CONTRIBUTION (part of employer cost)."
    type: string
    sql: ${TABLE}.cost_category ;;
  }

  dimension: cost_type {
    label: "Cost Type"
    description: "Earnings: REGULAR, OVERTIME, PTO, BONUS. Employer contributions: FICA, HEALTH_INSURANCE, RETIREMENT_MATCH."
    type: string
    sql: ${TABLE}.cost_type ;;
  }

  dimension: pay_run_id {
    label: "Pay Run"
    description: "Biweekly pay run, e.g. PR-20260918 (paid on 18 Sep 2026)."
    type: string
    sql: ${TABLE}.pay_run_id ;;
  }

  dimension_group: pay {
    label: "Pay"
    description: "Pay date of the pay run. Payroll is reported in the month of the pay date."
    type: time
    timeframes: [raw, date, month, quarter, year, fiscal_month_num, fiscal_quarter, fiscal_quarter_of_year, fiscal_year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.pay_date ;;
  }

  dimension: hours {
    hidden: yes
    type: number
    sql: ${TABLE}.hours ;;
  }

  dimension: amount_usd {
    hidden: yes
    type: number
    sql: ${TABLE}.amount_usd ;;
  }

  measure: gross_payroll {
    label: "Gross Payroll"
    description: "Sum of valid earning lines."
    type: sum
    sql: ${amount_usd} ;;
    filters: [cost_category: "EARNINGS"]
    value_format_name: usd_compact
    drill_fields: [drill_cost*]
  }

  measure: employer_cost {
    label: "Employer Cost"
    description: "Sum of employer contributions (FICA, health insurance, retirement match)."
    type: sum
    sql: ${amount_usd} ;;
    filters: [cost_category: "EMPLOYER_CONTRIBUTION"]
    value_format_name: usd_compact
    drill_fields: [drill_cost*]
  }

  measure: total_cost {
    label: "Fully Loaded Payroll Cost"
    description: "Gross payroll + employer cost."
    type: sum
    sql: ${amount_usd} ;;
    value_format_name: usd_compact
    drill_fields: [drill_cost*]
  }

  measure: overtime_cost {
    label: "Overtime Cost"
    type: sum
    sql: ${amount_usd} ;;
    filters: [cost_type: "OVERTIME"]
    value_format_name: usd_compact
    drill_fields: [drill_cost*]
  }

  measure: overtime_hours {
    label: "Overtime Hours"
    type: sum
    sql: ${hours} ;;
    filters: [cost_type: "OVERTIME"]
    value_format_name: decimal_0
  }

  measure: overtime_pct {
    label: "Overtime %"
    description: "Overtime earnings / gross payroll."
    type: number
    sql: SAFE_DIVIDE(${overtime_cost}, ${gross_payroll}) ;;
    value_format_name: percent_1
  }

  measure: paid_employee_count {
    label: "Employees Paid"
    description: "Distinct employees with at least one cost line in the selection."
    type: count_distinct
    sql: ${TABLE}.employee_id ;;
  }

  set: drill_cost {
    fields: [dim_department.department_name, pay_month, pay_run_id, cost_type, gross_payroll, employer_cost, total_cost]
  }
}
