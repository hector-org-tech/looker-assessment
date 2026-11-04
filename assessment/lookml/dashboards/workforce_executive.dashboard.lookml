- dashboard: workforce_executive
  title: "Workforce & Payroll – Executive Overview"
  description: "Monthly leadership review: are we within the payroll budget, where is overtime growing, is the workforce stable?"
  layout: newspaper
  preferred_viewer: dashboards-next
  crossfilter_enabled: true
  refresh: 1 day
  tile_size: 100

  filters:
  - name: fiscal_year
    title: "Fiscal Year"
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    ui_config: { type: dropdown_menu, display: inline }
    model: workforce_payroll
    explore: agg_department_monthly
    field: agg_department_monthly.fiscal_year

  - name: fiscal_quarter
    title: "Fiscal Quarter"
    type: field_filter
    default_value: "FY2027-Q1"
    allow_multiple_values: true
    required: false
    ui_config: { type: dropdown_menu, display: inline }
    model: workforce_payroll
    explore: agg_department_monthly
    field: agg_department_monthly.fiscal_quarter

  - name: division
    title: "Division"
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    ui_config: { type: tag_list, display: popover }
    model: workforce_payroll
    explore: agg_department_monthly
    field: dim_department.division

  - name: department
    title: "Department"
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    ui_config: { type: tag_list, display: popover }
    model: workforce_payroll
    explore: agg_department_monthly
    field: dim_department.department_name
    listens_to_filters: [division]

  - name: compare_with
    title: "Compare With"
    type: field_filter
    default_value: "prior_year"
    allow_multiple_values: false
    required: true
    ui_config: { type: button_toggles, display: inline }
    model: workforce_payroll
    explore: agg_department_monthly
    field: agg_department_monthly.comparison_period

  elements:

  # ---------------------------------------------------------------- row 1: KPIs
  - name: kpi_gross_vs_budget
    title: "Gross payroll vs budget"
    model: workforce_payroll
    explore: agg_department_monthly
    type: single_value
    fields: [agg_department_monthly.gross_payroll, agg_department_monthly.budgeted_gross_payroll]
    show_single_value_title: true
    single_value_title: "Gross payroll"
    show_comparison: true
    comparison_type: progress_percentage
    show_comparison_label: true
    comparison_label: "of budget"
    note_state: collapsed
    note_display: hover
    note_text: "Single value + progress bar: the first question is a yes/no ('are we within budget?'), and a share of budget is read in one glance. Details by department are in the Budget health table below."
    listen:
      fiscal_year: agg_department_monthly.fiscal_year
      fiscal_quarter: agg_department_monthly.fiscal_quarter
      division: dim_department.division
      department: dim_department.department_name
    row: 0
    col: 0
    width: 6
    height: 4

  - name: kpi_overtime_pct
    title: "Overtime % of gross payroll"
    model: workforce_payroll
    explore: agg_department_monthly
    type: single_value
    fields: [agg_department_monthly.overtime_pct, agg_department_monthly.overtime_pct_comparison]
    show_single_value_title: true
    single_value_title: "Overtime %"
    show_comparison: true
    comparison_type: change
    comparison_reverse_colors: true
    show_comparison_label: true
    note_state: collapsed
    note_display: hover
    note_text: "Single value with change vs the comparison period. Reverse colours: a higher overtime share is shown in red. The dollar amount is in the overtime charts below."
    listen:
      fiscal_year: agg_department_monthly.fiscal_year
      fiscal_quarter: agg_department_monthly.fiscal_quarter
      division: dim_department.division
      department: dim_department.department_name
      compare_with: agg_department_monthly.comparison_period
    row: 0
    col: 6
    width: 6
    height: 4

  - name: kpi_headcount
    title: "Headcount at end of period"
    model: workforce_payroll
    explore: agg_department_monthly
    type: single_value
    fields: [agg_department_monthly.headcount, agg_department_monthly.headcount_comparison]
    show_single_value_title: true
    single_value_title: "Headcount (FT + PT)"
    show_comparison: true
    comparison_type: change
    show_comparison_label: true
    note_state: collapsed
    note_display: hover
    note_text: "Single value with change: headcount is a stock, so it is shown at the end of the period, never summed across months. Contractors are excluded."
    listen:
      fiscal_year: agg_department_monthly.fiscal_year
      fiscal_quarter: agg_department_monthly.fiscal_quarter
      division: dim_department.division
      department: dim_department.department_name
      compare_with: agg_department_monthly.comparison_period
    row: 0
    col: 12
    width: 6
    height: 4

  - name: kpi_voluntary_turnover
    title: "Voluntary turnover"
    model: workforce_payroll
    explore: agg_department_monthly
    type: single_value
    fields: [agg_department_monthly.voluntary_turnover_rate, agg_department_monthly.voluntary_turnover_rate_comparison]
    show_single_value_title: true
    single_value_title: "Voluntary turnover (not annualised)"
    show_comparison: true
    comparison_type: change
    comparison_reverse_colors: true
    show_comparison_label: true
    note_state: collapsed
    note_display: hover
    note_text: "Single value with change, reverse colours (more resignations = red). Rate for the selected period: a quarter shows a quarterly rate."
    listen:
      fiscal_year: agg_department_monthly.fiscal_year
      fiscal_quarter: agg_department_monthly.fiscal_quarter
      division: dim_department.division
      department: dim_department.department_name
      compare_with: agg_department_monthly.comparison_period
    row: 0
    col: 18
    width: 6
    height: 4

  # ---------------------------------------------------------------- row 2: budget
  - name: budget_health_by_department
    title: "Budget health by department"
    model: workforce_payroll
    explore: agg_department_monthly
    type: looker_grid
    fields: [dim_department.division, dim_department.department_name,
             agg_department_monthly.gross_payroll, agg_department_monthly.budgeted_gross_payroll,
             agg_department_monthly.budget_bullet, agg_department_monthly.budget_variance_pct,
             agg_department_monthly.extra_pay_run_months,
             agg_department_monthly.employer_cost, agg_department_monthly.fully_loaded_cost]
    sorts: [agg_department_monthly.budget_variance_pct desc]
    limit: 50
    show_totals: true
    show_row_numbers: false
    hidden_fields: [agg_department_monthly.extra_pay_run_months]
    series_labels:
      agg_department_monthly.gross_payroll: "Actual"
      agg_department_monthly.budgeted_gross_payroll: "Budget"
      agg_department_monthly.budget_bullet: "Actual vs budget (line = 100%)"
      agg_department_monthly.budget_variance_pct: "Variance"
      agg_department_monthly.employer_cost: "Employer cost"
      agg_department_monthly.fully_loaded_cost: "Fully loaded"
    note_state: expanded
    note_display: below
    note_text: "Table with an inline bullet bar (custom HTML): leadership needs both the exact dollars and a visual ranking of who is over budget. Sorted worst first. Colours: green under budget, amber up to 2% over, red more than 2% over. Note: payroll is biweekly, so months with 3 pay runs look ~50% over a flat monthly budget (flagged in the Variance column)."
    listen:
      fiscal_year: agg_department_monthly.fiscal_year
      fiscal_quarter: agg_department_monthly.fiscal_quarter
      division: dim_department.division
      department: dim_department.department_name
    row: 4
    col: 0
    width: 24
    height: 7

  # ---------------------------------------------------------------- row 3: overtime
  - name: overtime_by_department
    title: "Where is overtime growing?"
    model: workforce_payroll
    explore: agg_department_monthly
    type: looker_bar
    fields: [dim_department.department_name, agg_department_monthly.overtime_pct,
             agg_department_monthly.overtime_pct_comparison, agg_department_monthly.overtime_cost]
    sorts: [agg_department_monthly.overtime_pct desc]
    limit: 20
    hidden_fields: [agg_department_monthly.overtime_cost]
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_value_labels: true
    label_density: 25
    legend_position: bottom
    series_colors:
      agg_department_monthly.overtime_pct: "#d92d20"
      agg_department_monthly.overtime_pct_comparison: "#98a2b3"
    y_axes: [{ label: "Overtime % of gross payroll", orientation: bottom, showValues: true, valueFormat: "0%" }]
    note_state: collapsed
    note_display: hover
    note_text: "Horizontal grouped bars: department names are long and the question is a ranking with a before/after comparison (red = this period, grey = comparison period). Hover a bar for the dollar cost."
    listen:
      fiscal_year: agg_department_monthly.fiscal_year
      fiscal_quarter: agg_department_monthly.fiscal_quarter
      division: dim_department.division
      department: dim_department.department_name
      compare_with: agg_department_monthly.comparison_period
    row: 11
    col: 0
    width: 12
    height: 7

  - name: overtime_trend
    title: "Overtime cost and % by month (all periods)"
    model: workforce_payroll
    explore: agg_department_monthly
    type: looker_column
    fields: [agg_department_monthly.period_month, agg_department_monthly.overtime_cost, agg_department_monthly.overtime_pct]
    sorts: [agg_department_monthly.period_month]
    limit: 60
    series_types:
      agg_department_monthly.overtime_pct: line
    series_colors:
      agg_department_monthly.overtime_cost: "#f79009"
      agg_department_monthly.overtime_pct: "#101828"
    y_axes: [{ label: "Overtime cost", orientation: left, series: [{ id: agg_department_monthly.overtime_cost }], valueFormat: "$0,\"K\"" },
             { label: "Overtime %", orientation: right, series: [{ id: agg_department_monthly.overtime_pct }], valueFormat: "0.0%" }]
    show_value_labels: false
    legend_position: bottom
    note_state: collapsed
    note_display: hover
    note_text: "Columns (dollars) + line (rate) over time: shows both how much overtime costs and whether it grows faster than payroll. Ignores the period filter on purpose to keep the full trend; follows division and department."
    listen:
      division: dim_department.division
      department: dim_department.department_name
    row: 11
    col: 12
    width: 12
    height: 7

  # ---------------------------------------------------------------- row 4: workforce
  - name: workforce_trend
    title: "Headcount and voluntary leavers by month (all periods)"
    model: workforce_payroll
    explore: agg_department_monthly
    type: looker_column
    fields: [agg_department_monthly.period_month, agg_department_monthly.headcount,
             agg_department_monthly.budgeted_headcount, agg_department_monthly.voluntary_terminations]
    sorts: [agg_department_monthly.period_month]
    limit: 60
    series_types:
      agg_department_monthly.budgeted_headcount: line
      agg_department_monthly.voluntary_terminations: scatter
    series_colors:
      agg_department_monthly.headcount: "#2e90fa"
      agg_department_monthly.budgeted_headcount: "#98a2b3"
      agg_department_monthly.voluntary_terminations: "#d92d20"
    y_axes: [{ label: "Headcount", orientation: left, series: [{ id: agg_department_monthly.headcount }, { id: agg_department_monthly.budgeted_headcount }] },
             { label: "Voluntary leavers", orientation: right, series: [{ id: agg_department_monthly.voluntary_terminations }] }]
    legend_position: bottom
    note_state: collapsed
    note_display: hover
    note_text: "Columns for headcount (a level), grey line for budgeted headcount, red dots for resignations (an event count on its own axis). Stability = flat columns close to the budget line and few red dots."
    listen:
      division: dim_department.division
      department: dim_department.department_name
    row: 18
    col: 0
    width: 24
    height: 7
