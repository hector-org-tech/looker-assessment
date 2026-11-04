# Leadership asked for "average salary by job title". This view reads a table that
# Dataform already aggregated and anonymised (k >= 5). There is no row per person
# anywhere in this explore, so no filter combination can reveal individual pay.

view: agg_salary_by_job_title {
  sql_table_name: gold.agg_salary_by_job_title ;;

  dimension: job_title {
    primary_key: yes
    label: "Job Title"
    type: string
    sql: ${TABLE}.job_title ;;
  }

  dimension: employee_count {
    label: "Employees in Title"
    description: "Active full-time employees holding the title."
    type: number
    sql: ${TABLE}.employee_count ;;
  }

  dimension: is_suppressed {
    label: "Suppressed (fewer than 5 people)"
    type: yesno
    sql: ${TABLE}.is_suppressed ;;
  }

  dimension: avg_annualized_pay_usd {
    label: "Average Annual Pay"
    description: "Annual salary, or hourly rate x 2,080 for full-time hourly staff. Rounded to the nearest $1,000. Hidden when fewer than 5 people hold the title."
    type: number
    sql: ${TABLE}.avg_annualized_pay_usd ;;
    value_format_name: usd_0
    html: {% if value == nil %}<span style="color:#6b7280;">suppressed (&lt;5 people)</span>{% else %}{{ rendered_value }}{% endif %} ;;
  }

  dimension: median_annualized_pay_usd {
    label: "Median Annual Pay"
    type: number
    sql: ${TABLE}.median_annualized_pay_usd ;;
    value_format_name: usd_0
    html: {% if value == nil %}<span style="color:#6b7280;">suppressed</span>{% else %}{{ rendered_value }}{% endif %} ;;
  }

  measure: employees {
    label: "Employees"
    type: sum
    sql: ${employee_count} ;;
  }
}
