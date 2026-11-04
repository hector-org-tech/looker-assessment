view: fct_terminations {
  sql_table_name: gold.fct_terminations ;;

  dimension: employee_id {
    primary_key: yes
    hidden: yes
    type: string
    sql: ${TABLE}.employee_id ;;
  }

  dimension: department_id {
    hidden: yes
    type: string
    sql: ${TABLE}.department_id ;;
  }

  dimension_group: termination {
    label: "Termination"
    type: time
    timeframes: [date, month, quarter, year, fiscal_quarter, fiscal_year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.termination_date ;;
  }

  dimension: termination_reason {
    label: "Reason"
    description: "VOLUNTARY (resignation), INVOLUNTARY or RETIREMENT."
    type: string
    sql: ${TABLE}.termination_reason ;;
  }

  dimension: is_voluntary {
    label: "Is Voluntary"
    type: yesno
    sql: ${TABLE}.is_voluntary ;;
  }

  dimension: tenure_years {
    label: "Tenure at Exit (years)"
    type: number
    sql: ${TABLE}.tenure_years ;;
    value_format_name: decimal_1
  }

  measure: leavers {
    label: "Leavers"
    type: count
    drill_fields: [leaver_list*]
  }

  measure: voluntary_leavers {
    label: "Voluntary Leavers"
    type: count
    filters: [is_voluntary: "yes"]
    drill_fields: [leaver_list*]
  }

  measure: average_tenure_at_exit {
    label: "Average Tenure at Exit (years)"
    type: average
    sql: ${tenure_years} ;;
    value_format_name: decimal_1
  }

  set: leaver_list {
    fields: [termination_date, dim_department.department_name, dim_employee.full_name, dim_employee.job_title, termination_reason, tenure_years]
  }
}
