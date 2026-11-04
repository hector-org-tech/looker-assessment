# One current row per employee. Fields are grouped in three sets so each explore
# can expose exactly what its audience may see:
#   safe_attributes : cannot identify a person on their own
#   identity        : who the person is
#   pay_rates       : individual pay (HR and Finance only, enforced by access grant)

view: dim_employee {
  sql_table_name: gold.dim_employee ;;

  # --- identity ---------------------------------------------------------------
  dimension: employee_id {
    primary_key: yes
    label: "Employee ID"
    type: string
    sql: ${TABLE}.employee_id ;;
  }

  dimension: full_name {
    label: "Employee Name"
    type: string
    sql: ${TABLE}.full_name ;;
  }

  dimension: email {
    label: "Email"
    type: string
    sql: ${TABLE}.email ;;
  }

  dimension: job_title {
    label: "Job Title"
    description: "Kept with identity fields: some titles are held by one person (e.g. Controller), so title + pay = that person's pay."
    type: string
    sql: ${TABLE}.job_title ;;
  }

  # --- safe attributes ----------------------------------------------------------
  dimension: employment_type {
    label: "Employment Type"
    description: "FULL_TIME, PART_TIME or CONTRACTOR. Contractors are not counted in headcount."
    type: string
    sql: ${TABLE}.employment_type ;;
  }

  dimension: flsa_status {
    label: "FLSA Status"
    description: "EXEMPT (salaried, no overtime) or NON_EXEMPT (hourly, overtime eligible)."
    type: string
    sql: ${TABLE}.flsa_status ;;
  }

  dimension: location_state {
    label: "Work State"
    type: string
    sql: ${TABLE}.location_state ;;
  }

  dimension_group: hire {
    label: "Hire"
    type: time
    timeframes: [date, month, year, fiscal_year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.hire_date ;;
  }

  dimension_group: termination {
    label: "Termination"
    type: time
    timeframes: [date, month, year, fiscal_year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.termination_date ;;
  }

  dimension: termination_reason {
    label: "Termination Reason"
    type: string
    sql: ${TABLE}.termination_reason ;;
  }

  dimension: tenure_band {
    label: "Tenure Band"
    description: "Years since hire (as of termination date for leavers, today otherwise)."
    type: tier
    tiers: [1, 2, 5, 10]
    style: integer
    sql: DATE_DIFF(COALESCE(${TABLE}.termination_date, CURRENT_DATE()), ${TABLE}.hire_date, DAY) / 365.25 ;;
  }

  # --- individual pay (HR & Finance only) ----------------------------------------
  dimension: annual_salary_usd {
    label: "Annual Salary"
    description: "CONFIDENTIAL. Salaried (exempt) employees only."
    type: number
    sql: ${TABLE}.annual_salary_usd ;;
    value_format_name: usd_0
    required_access_grants: [can_see_individual_pay]
  }

  dimension: hourly_rate_usd {
    label: "Hourly Rate"
    description: "CONFIDENTIAL. Hourly (non-exempt) employees and contractors."
    type: number
    sql: ${TABLE}.hourly_rate_usd ;;
    value_format_name: usd
    required_access_grants: [can_see_individual_pay]
  }

  # No salary MEASURE (average, sum...) is defined on purpose: an average over a
  # filtered group of one is that person's salary. Leadership uses the anonymised
  # agg_salary_by_job_title explore instead.

  measure: employee_count {
    label: "Employees"
    type: count_distinct
    sql: ${TABLE}.employee_id ;;
  }

  set: safe_attributes {
    fields: [employment_type, flsa_status, location_state, hire_date, hire_month, hire_year, hire_fiscal_year,
             termination_date, termination_month, termination_year, termination_fiscal_year,
             termination_reason, tenure_band, employee_count]
  }
  set: identity {
    fields: [employee_id, full_name, email, job_title]
  }
  set: pay_rates {
    fields: [annual_salary_usd, hourly_rate_usd]
  }
}
