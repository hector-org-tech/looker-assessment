# One row per active full-time / part-time employee per month end.

view: fct_workforce_month_end {
  sql_table_name: gold.fct_workforce_month_end ;;

  dimension: snapshot_key {
    primary_key: yes
    hidden: yes
    type: string
    sql: CONCAT(${TABLE}.employee_id, '|', CAST(${TABLE}.month_end_date AS STRING)) ;;
  }

  dimension: employee_id {
    hidden: yes
    type: string
    sql: ${TABLE}.employee_id ;;
  }

  dimension: department_id {
    hidden: yes
    type: string
    sql: ${TABLE}.department_id ;;
  }

  dimension_group: snapshot {
    label: "Month End"
    description: "Last day of the month on which the employee was counted."
    type: time
    timeframes: [date, month, quarter, year, fiscal_quarter, fiscal_year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.month_end_date ;;
  }

  # Semi-additive: counts people on the LAST month end of each result row.
  measure: headcount {
    label: "Headcount (end of period)"
    description: "Distinct employees active on the last month end in the selection."
    type: number
    sql: (SELECT COUNT(DISTINCT x.e) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_end_date AS m, ${TABLE}.employee_id AS e))) AS x
          WHERE x.m = (SELECT MAX(y.m) FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_end_date AS m, ${TABLE}.employee_id AS e))) AS y)) ;;
    value_format_name: decimal_0
    drill_fields: [employee_list*]
  }

  measure: employee_months {
    label: "Employee-Months"
    description: "Number of (employee, month end) rows. Use for averages, not as a headcount."
    type: count
  }

  set: employee_list {
    fields: [snapshot_month, dim_department.department_name, dim_employee.full_name, dim_employee.job_title, dim_employee.employment_type, dim_employee.hire_date]
  }
}
