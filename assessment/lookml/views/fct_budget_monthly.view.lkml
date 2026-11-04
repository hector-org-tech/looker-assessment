view: fct_budget_monthly {
  sql_table_name: gold.fct_budget_monthly ;;

  # The primary key is what lets Looker de-duplicate budget rows (symmetric
  # aggregates) when this view is joined many_to_one to the cost lines.
  dimension: budget_key {
    primary_key: yes
    hidden: yes
    type: string
    sql: ${TABLE}.budget_key ;;
  }

  dimension: department_id {
    hidden: yes
    type: string
    sql: ${TABLE}.department_id ;;
  }

  dimension: budget_month {
    hidden: yes
    type: date
    convert_tz: no
    sql: ${TABLE}.month_start_date ;;
  }

  measure: budgeted_gross_payroll {
    label: "Budgeted Gross Payroll"
    description: "Monthly budget of the departments and months that have cost in the result."
    type: sum
    sql: ${TABLE}.budgeted_gross_payroll_usd ;;
    value_format_name: usd_compact
  }

  # Only valid inside the fct_payroll_cost explore (references its gross payroll).
  measure: budget_variance_pct {
    label: "Budget Variance %"
    description: "(Actual gross payroll / budget) - 1. Do not filter on cost type when reading this."
    type: number
    sql: SAFE_DIVIDE(${fct_payroll_cost.gross_payroll}, ${budgeted_gross_payroll}) - 1 ;;
    value_format_name: percent_1
  }
}
