view: dim_department {
  sql_table_name: gold.dim_department ;;

  dimension: department_id {
    primary_key: yes
    label: "Department ID"
    description: "Technical department code (D01-D08)."
    type: string
    sql: ${TABLE}.department_id ;;
  }

  dimension: department_name {
    label: "Department"
    description: "Department name. In payroll cost it is the cost center charged on the payroll line; in headcount it is the employee's home department on that date."
    type: string
    sql: ${TABLE}.department_name ;;
    drill_fields: [division, department_name]
  }

  dimension: division {
    label: "Division"
    description: "Group of departments: Administration, Programs, Advancement, Operations."
    type: string
    sql: ${TABLE}.division ;;
    drill_fields: [department_name]
  }

  dimension: cost_center {
    label: "Cost Center"
    type: string
    sql: ${TABLE}.cost_center ;;
  }

  dimension: manager_name {
    label: "Department Manager"
    type: string
    sql: ${TABLE}.manager_name ;;
  }

  dimension: manager_employee_id {
    hidden: yes
    type: string
    sql: ${TABLE}.manager_employee_id ;;
  }
}
