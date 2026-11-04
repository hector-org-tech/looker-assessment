# =============================================================================
# Workforce & Payroll Analytics
# Semantic layer on top of the Dataform gold layer (BigQuery dataset `gold`).
# =============================================================================

connection: "bigquery_workforce"

include: "/lookml/views/*.view.lkml"
include: "/lookml/dashboards/*.dashboard.lookml"

# Fiscal year runs July 1 - June 30 and is named after the year in which it ENDS.
# A negative offset moves the start of the fiscal year into the previous calendar
# year: with -6, Q1 of FY2026 starts in July 2025.
fiscal_month_offset: -6
week_start_day: monday

named_value_format: usd_compact {
  value_format: "[>=1000000]$0.00,,\"M\";[>=1000]$0.0,\"K\";$0"
}

# -----------------------------------------------------------------------------
# Caching: one datagroup tied to the end of the Dataform run
# -----------------------------------------------------------------------------
datagroup: dataform_gold_refresh {
  label: "Gold layer refreshed by Dataform"
  description: "Dataform appends a row to gold.etl_run_log as the LAST step of a run, after all tables are built and all assertions passed. Looker polls this query on the PDT maintenance schedule (default every 5 minutes); when the value changes, the cache is invalidated and aggregate tables are rebuilt."
  sql_trigger: SELECT MAX(run_finished_at) FROM gold.etl_run_log ;;
  max_cache_age: "24 hours"
}

persist_with: dataform_gold_refresh

# -----------------------------------------------------------------------------
# Security
# User attributes (set in Admin > User Attributes, ideally synced from the IdP):
#   department_scope : 'ALL' for HR, Finance and Leadership; the department_id
#                      (e.g. 'D04') for a department manager. Default 'NONE'
#                      so that a user nobody configured sees nothing.
#   pay_data_access  : 'yes' for HR and Finance only. Default 'no'.
# -----------------------------------------------------------------------------
access_grant: can_see_individual_pay {
  user_attribute: pay_data_access
  allowed_values: ["yes"]
}

# =============================================================================
# 1. Executive summary: one row per department per month (dashboard source)
# =============================================================================
explore: agg_department_monthly {
  label: "Workforce & Payroll – Monthly Summary"
  description: "Start here. Budget, payroll cost, overtime, headcount and turnover by department and month. All numbers already follow the official business definitions."
  view_label: "Workforce & Payroll"

  sql_always_where:
    {% if _user_attributes['department_scope'] == 'ALL' %} 1 = 1
    {% else %} ${agg_department_monthly.department_id} = {{ _user_attributes['department_scope'] | sql_quote }}
    {% endif %} ;;

  # many_to_one: each department-month row has exactly one department.
  # No fan-out is possible, so every SUM stays correct.
  join: dim_department {
    type: left_outer
    relationship: many_to_one
    sql_on: ${agg_department_monthly.department_id} = ${dim_department.department_id} ;;
  }
}

# =============================================================================
# 2. Payroll cost detail: earning lines and employer contributions
# =============================================================================
explore: fct_payroll_cost {
  label: "Payroll Cost – Detail"
  description: "Every valid earning line and every employer contribution. Use it to drill below the monthly summary (by pay run, earning type or contribution type)."
  view_label: "Payroll Cost"

  sql_always_where:
    {% if _user_attributes['department_scope'] == 'ALL' %} 1 = 1
    {% else %} ${fct_payroll_cost.department_id} = {{ _user_attributes['department_scope'] | sql_quote }}
    {% endif %} ;;

  join: dim_department {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_payroll_cost.department_id} = ${dim_department.department_id} ;;
  }

  # Non-identifying employee attributes: safe for managers.
  join: dim_employee {
    view_label: "Employee Attributes"
    type: left_outer
    relationship: many_to_one
    # Raw column references on purpose: fct_payroll_cost.employee_id is a restricted
    # field, and a join must not depend on a field the user may not be granted.
    sql_on: fct_payroll_cost.employee_id = dim_employee.employee_id ;;
    fields: [dim_employee.safe_attributes*]
  }

  # Who the person is + their pay rate. Same table joined a second time, and the
  # whole join requires the pay grant: a manager can see that Family Services paid
  # $31K of overtime, never which person earned it.
  join: employee_identity {
    from: dim_employee
    view_label: "Employee (HR & Finance only)"
    type: left_outer
    relationship: many_to_one
    sql_on: fct_payroll_cost.employee_id = employee_identity.employee_id ;;
    required_access_grants: [can_see_individual_pay]
    fields: [employee_identity.identity*, employee_identity.pay_rates*]
  }

  # Budget is at department-month grain, so from the cost table's point of view the
  # join is many_to_one. Because fct_budget_monthly has a primary key, Looker applies
  # symmetric aggregates (SUM DISTINCT on the key) and the budget is not multiplied by
  # the number of cost lines.
  join: fct_budget_monthly {
    view_label: "Budget"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_payroll_cost.department_id} = ${fct_budget_monthly.department_id}
      AND DATE_TRUNC(${fct_payroll_cost.pay_raw}, MONTH) = ${fct_budget_monthly.budget_month} ;;
  }

  # Aggregate awareness: ad-hoc questions at month x department x cost type
  # (the vast majority) hit this small table instead of the 25K-row fact.
  aggregate_table: monthly_cost_by_department_type {
    query: {
      dimensions: [
        fct_payroll_cost.pay_month,
        fct_payroll_cost.pay_fiscal_quarter,
        fct_payroll_cost.pay_fiscal_year,
        dim_department.division,
        dim_department.department_name,
        fct_payroll_cost.cost_category,
        fct_payroll_cost.cost_type
      ]
      measures: [
        fct_payroll_cost.gross_payroll,
        fct_payroll_cost.employer_cost,
        fct_payroll_cost.total_cost,
        fct_payroll_cost.overtime_cost,
        fct_payroll_cost.overtime_hours
      ]
    }
    materialization: {
      datagroup_trigger: dataform_gold_refresh
    }
  }
}

# =============================================================================
# 3. Headcount: one row per active employee per month end
# =============================================================================
explore: fct_workforce_month_end {
  label: "Headcount – Month-end Snapshot"
  description: "Who was on staff (full-time and part-time) on the last day of each month, in which department. No pay data."
  view_label: "Headcount"

  sql_always_where:
    {% if _user_attributes['department_scope'] == 'ALL' %} 1 = 1
    {% else %} ${fct_workforce_month_end.department_id} = {{ _user_attributes['department_scope'] | sql_quote }}
    {% endif %} ;;

  join: dim_department {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_workforce_month_end.department_id} = ${dim_department.department_id} ;;
  }

  join: dim_employee {
    view_label: "Employee"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_workforce_month_end.employee_id} = ${dim_employee.employee_id} ;;
    fields: [dim_employee.safe_attributes*, dim_employee.identity*]
  }
}

# =============================================================================
# 4. Terminations
# =============================================================================
explore: fct_terminations {
  label: "Terminations"
  description: "One row per employee who left. Use with the headcount explore for turnover analysis."
  view_label: "Terminations"

  sql_always_where:
    {% if _user_attributes['department_scope'] == 'ALL' %} 1 = 1
    {% else %} ${fct_terminations.department_id} = {{ _user_attributes['department_scope'] | sql_quote }}
    {% endif %} ;;

  join: dim_department {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_terminations.department_id} = ${dim_department.department_id} ;;
  }

  join: dim_employee {
    view_label: "Employee"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_terminations.employee_id} = ${dim_employee.employee_id} ;;
    fields: [dim_employee.safe_attributes*, dim_employee.identity*]
  }
}

# =============================================================================
# 5. Average pay by job title (anonymised, for leadership)
# =============================================================================
explore: agg_salary_by_job_title {
  label: "Pay by Job Title (anonymised)"
  description: "Average and median annualised pay of active full-time staff by job title. Titles with fewer than 5 people are suppressed. There is deliberately no department or location field, so the numbers cannot be narrowed down to one person."
}
