"""
Builds the dashboard mockup (HTML) from an export of the gold table
gold.agg_department_monthly (analysis/agg_department_monthly_export.csv).
Every number on the mockup comes from the same gold layer that Looker reads.

Usage: python3 mockups/build_mockup.py <folder with departments.csv>
"""
import html
import os
import sys

import pandas as pd

DATA = sys.argv[1] if len(sys.argv) > 1 else "data"
a = pd.read_csv("analysis/agg_department_monthly_export.csv")
d = pd.read_csv(os.path.join(DATA, "departments.csv"))
a = a.merge(d[["department_id", "department_name", "division"]], on="department_id")
q = a[a.fiscal_quarter == "FY2027-Q1"]

gross, bud = q.gross_payroll_usd.sum(), q.budgeted_gross_payroll_usd.sum()
ot, otpy, gpy = q.overtime_earnings_usd.sum(), q.overtime_earnings_usd_prior_year.sum(), q.gross_payroll_usd_prior_year.sum()
lm = q.month_start_date.max()
hc = q[q.month_start_date == lm].headcount_month_end.sum()
hcpy = q[q.month_start_date == lm].headcount_month_end_prior_year.sum()
n = q.month_start_date.nunique()
tr = q.voluntary_terminations.sum() / (q.headcount_month_end.sum() / n)
trpy = q.voluntary_terminations_prior_year.sum() / (q.headcount_month_end_prior_year.sum() / n)


def k(v):
    return f"${v/1e6:.2f}M" if v >= 1e6 else f"${v/1e3:.1f}K"


def chg(cur, prev, reverse=False, pp=False):
    if pp:
        delta = (cur - prev) * 100
        txt = f"{'▲' if delta > 0 else '▼'} {abs(delta):.2f} pts"
    else:
        delta = cur / prev - 1
        txt = f"{'▲' if delta > 0 else '▼'} {abs(delta)*100:.1f}%"
    bad = (delta > 0) if reverse else (delta < 0)
    return f'<span class="chg {"bad" if bad else "good"}">{txt}</span>'


t = q.groupby(["division", "department_name"]).agg(
    g=("gross_payroll_usd", "sum"), b=("budgeted_gross_payroll_usd", "sum"), ec=("employer_cost_usd", "sum"),
    ot=("overtime_earnings_usd", "sum"), otpy=("overtime_earnings_usd_prior_year", "sum"),
    gpy=("gross_payroll_usd_prior_year", "sum")).reset_index()
t["var"] = t.g / t.b - 1
t["otp"] = t.ot / t.g
t["otp_py"] = t.otpy / t.gpy

rows = ""
for _, r in t.sort_values("var", ascending=False).iterrows():
    pct = r.g / r.b * 100
    bar = min(pct * 0.8, 100)
    col = "#d92d20" if pct > 102 else "#f79009" if pct > 100 else "#12b76a"
    v = r["var"]
    if v > 0.02:
        vt = f'<span style="color:#b42318;font-weight:600">▲ {v*100:.1f}% over</span>'
    elif v > 0:
        vt = f'<span style="color:#b54708;font-weight:600">▲ {v*100:.1f}% over</span>'
    else:
        vt = f'<span style="color:#067647;font-weight:600">▼ {abs(v)*100:.1f}% under</span>'
    rows += (f"<tr><td>{r.division}</td><td>{html.escape(r.department_name)}</td><td class=n>{k(r.g)}</td>"
             f"<td class=n>{k(r.b)}</td><td><div class=bul><div class=track><div class=fill style='width:{bar:.1f}%;"
             f"background:{col}'></div><div class=mark></div></div><span>{pct:.0f}%</span></div></td><td>{vt}</td>"
             f"<td class=n>{k(r.ec)}</td><td class=n>{k(r.g + r.ec)}</td></tr>")
tg, tb, tec = t.g.sum(), t.b.sum(), t.ec.sum()
rows += (f"<tr class=tot><td>Total</td><td></td><td class=n>{k(tg)}</td><td class=n>{k(tb)}</td><td></td>"
         f"<td><span style='color:#067647;font-weight:600'>▼ {abs(tg/tb-1)*100:.1f}% under</span></td>"
         f"<td class=n>{k(tec)}</td><td class=n>{k(tg + tec)}</td></tr>")

tb2 = t.sort_values("otp", ascending=False)
mx = max(tb2.otp.max(), tb2.otp_py.max()) * 1.15
bars = ""
for _, r in tb2.iterrows():
    bars += (f"<div class=hb><div class=lab>{html.escape(r.department_name)}</div><div class=bars>"
             f"<div class=b1 style='width:{r.otp/mx*100:.1f}%'></div><span class=v>{r.otp*100:.1f}%</span><br>"
             f"<div class=b2 style='width:{r.otp_py/mx*100:.1f}%'></div><span class='v g'>{r.otp_py*100:.1f}%</span></div></div>")

m = a.groupby("month_start_date").agg(
    ot=("overtime_earnings_usd", "sum"), g=("gross_payroll_usd", "sum"), hc=("headcount_month_end", "sum"),
    bhc=("budgeted_headcount", "sum"), vol=("voluntary_terminations", "sum"), runs=("pay_runs_in_month", "max")).reset_index()
m["otp"] = m.ot / m.g
labels = [pd.Timestamp(x).strftime("%b %y") for x in m.month_start_date]
W, H, P = 560, 230, 40
nm = len(m)


def svg_ot():
    bw = (W - 2 * P) / nm
    mo, mp = 40000, 0.05
    s = f"<svg viewBox='0 0 {W} {H}' class=chart>"
    for v in [0, 20000, 40000]:
        y = H - 40 - (v / mo) * (H - 70)
        s += f"<text x='{P-6}' y='{y+3:.1f}' class=ax text-anchor=end>${v//1000}K</text><line x1={P} x2={W-P} y1={y:.1f} y2={y:.1f} stroke='#eaecf0'></line>"
    for v in [0, 0.025, 0.05]:
        y = H - 40 - (v / mp) * (H - 70)
        s += f"<text x='{W-P+6}' y='{y+3:.1f}' class=ax>{v*100:.1f}%</text>"
    for i, r in m.iterrows():
        x = P + i * bw
        h = (r.ot / mo) * (H - 70)
        s += f"<rect x='{x+3:.1f}' y='{H-40-h:.1f}' width='{bw-6:.1f}' height='{h:.1f}' fill='#f79009' rx='2'/>"
        s += f"<text x='{x+bw/2:.1f}' y='{H-25}' class=ax text-anchor=middle>{labels[i].split()[0]}</text>"
        if i == 0 or labels[i].startswith("Jan"):
            s += f"<text x='{x+bw/2:.1f}' y='{H-12}' class=ax text-anchor=middle>20{labels[i].split()[1]}</text>"
    pts = " ".join(f"{P+i*bw+bw/2:.1f},{H-40-(r.otp/mp)*(H-70):.1f}" for i, r in m.iterrows())
    s += f"<polyline points='{pts}' fill=none stroke='#101828' stroke-width='2'/>"
    for i, r in m.iterrows():
        s += f"<circle cx='{P+i*bw+bw/2:.1f}' cy='{H-40-(r.otp/mp)*(H-70):.1f}' r='3' fill='#101828'/>"
    return s + "</svg>"


def svg_hc():
    WW = W * 2
    bw = (WW - 2 * P) / nm
    lo, hi, mv = 150, 190, 8

    def sc(v):
        return (H - 40) - ((v - lo) / (hi - lo)) * (H - 70)
    s = f"<svg viewBox='0 0 {WW} {H}' class=chart>"
    for v in [150, 170, 190]:
        s += f"<text x='{P-6}' y='{sc(v)+3:.1f}' class=ax text-anchor=end>{v}</text><line x1={P} x2={WW-P} y1={sc(v):.1f} y2={sc(v):.1f} stroke='#eaecf0'></line>"
    for v in [0, 4, 8]:
        y = (H - 40) - (v / mv) * (H - 70)
        s += f"<text x='{WW-P+6}' y='{y+3:.1f}' class=ax>{v}</text>"
    for i, r in m.iterrows():
        x = P + i * bw
        s += (f"<rect x='{x+10:.1f}' y='{sc(r.hc):.1f}' width='{bw-20:.1f}' height='{H-40-sc(r.hc):.1f}' fill='#2e90fa' rx='2'/>"
              f"<text x='{x+bw/2:.1f}' y='{sc(r.hc)-4:.1f}' class=ax text-anchor=middle>{int(r.hc)}</text>"
              f"<text x='{x+bw/2:.1f}' y='{H-25}' class=ax text-anchor=middle>{labels[i]}</text>")
    pts = " ".join(f"{P+i*bw+bw/2:.1f},{sc(r.bhc):.1f}" for i, r in m.iterrows())
    s += f"<polyline points='{pts}' fill=none stroke='#98a2b3' stroke-width=2 stroke-dasharray='5 4'/>"
    for i, r in m.iterrows():
        if r.vol > 0:
            cy = (H - 40) - (r.vol / mv) * (H - 70)
            s += (f"<circle cx='{P+i*bw+bw/2:.1f}' cy='{cy:.1f}' r='6' fill='#d92d20'/>"
                  f"<text x='{P+i*bw+bw/2+9:.1f}' y='{cy+4:.1f}' class=ax style='fill:#d92d20'>{int(r.vol)}</text>")
    return s + "</svg>"


CSS = """
body{margin:0;background:#f2f4f7;font-family:Inter,Roboto,'Segoe UI',Arial,sans-serif;color:#101828}
.top{background:#fff;border-bottom:1px solid #eaecf0;padding:14px 24px} h1{font-size:20px;margin:0 0 10px}
.filters{display:flex;gap:10px;flex-wrap:wrap;font-size:12px}.f{border:1px solid #d0d5dd;border-radius:6px;padding:6px 10px;background:#fff}.f b{color:#475467;font-weight:500;margin-right:6px}
.tog span{padding:4px 8px;border:1px solid #d0d5dd}.tog .on{background:#1849a9;color:#fff;border-color:#1849a9}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;padding:16px 24px}
.tile{background:#fff;border:1px solid #eaecf0;border-radius:8px;padding:14px 16px}.tile h3{margin:0 0 8px;font-size:13px;color:#475467;font-weight:600}
.kpi .v{font-size:32px;font-weight:600;letter-spacing:-.5px}.kpi .s{font-size:12px;color:#475467;margin-top:6px}
.chg{font-weight:600}.good{color:#067647}.bad{color:#b42318}
.prog{height:6px;background:#eaecf0;border-radius:3px;margin-top:8px}.prog div{height:6px;background:#12b76a;border-radius:3px}
.w4{grid-column:span 4}.w2{grid-column:span 2}
table{width:100%;border-collapse:collapse;font-size:12.5px}th{text-align:left;color:#475467;font-weight:600;border-bottom:1px solid #eaecf0;padding:6px}td{padding:6px;border-bottom:1px solid #f2f4f7}.n{text-align:right;font-variant-numeric:tabular-nums}.tot td{font-weight:600;border-top:1px solid #d0d5dd}
.bul{display:flex;align-items:center;gap:8px;min-width:200px}.track{position:relative;flex:1;height:14px;background:#f2f4f7;border-radius:3px}.fill{position:absolute;left:0;top:0;height:14px;border-radius:3px}.mark{position:absolute;left:80%;top:-3px;height:20px;border-left:2px solid #101828}
.note{font-size:11.5px;color:#667085;margin-top:8px}
.hb{display:flex;align-items:center;font-size:12px;margin:5px 0}.lab{width:170px}.bars{flex:1}.b1,.b2{display:inline-block;height:9px;border-radius:2px;vertical-align:middle}.b1{background:#d92d20}.b2{background:#98a2b3}.v{font-size:11px;margin-left:5px}.v.g{color:#667085}
.chart{width:100%;height:auto}.ax{font-size:10px;fill:#667085}.leg{font-size:11px;color:#475467;font-weight:400}.leg i{display:inline-block;width:10px;height:10px;border-radius:2px;margin:0 4px 0 10px;vertical-align:middle}
.badge{font-size:10px;background:#fef0c7;color:#93370d;border-radius:4px;padding:2px 6px;margin-left:6px;vertical-align:middle}
"""

page = f"""<!doctype html><html><head><meta charset=utf-8><title>Workforce & Payroll – Executive Overview (mockup)</title><style>{CSS}</style></head><body>
<div class=top><h1>Workforce &amp; Payroll – Executive Overview <span class=badge>MOCKUP · numbers from the gold layer</span></h1>
<div class=filters><div class=f><b>Fiscal Year</b>any</div><div class=f><b>Fiscal Quarter</b>FY2027-Q1</div><div class=f><b>Division</b>all</div><div class=f><b>Department</b>all</div>
<div class="f tog"><b>Compare with</b><span class=on>Same period last year</span><span>Previous quarter</span></div></div></div>
<div class=grid>
<div class="tile kpi"><h3>Gross payroll vs budget</h3><div class=v>{k(gross)}</div><div class=prog><div style="width:{gross/bud*100:.0f}%"></div></div>
<div class=s>{gross/bud*100:.1f}% of budget ({k(bud)}) · <span class="chg good">▼ {abs(gross/bud-1)*100:.1f}% under</span></div></div>
<div class="tile kpi"><h3>Overtime % of gross payroll</h3><div class=v>{ot/gross*100:.1f}%</div><div class=s>{chg(ot/gross, otpy/gpy, reverse=True, pp=True)} vs Q1 FY2026 ({otpy/gpy*100:.1f}%) · {k(ot)} of overtime</div></div>
<div class="tile kpi"><h3>Headcount at end of period</h3><div class=v>{int(hc)}</div><div class=s>{chg(hc, hcpy)} vs 30 Sep 2025 ({int(hcpy)}) · full-time + part-time</div></div>
<div class="tile kpi"><h3>Voluntary turnover</h3><div class=v>{tr*100:.1f}%</div><div class=s>{chg(tr, trpy, reverse=True, pp=True)} vs Q1 FY2026 ({trpy*100:.1f}%) · quarterly rate</div></div>
<div class="tile w4"><h3>Budget health by department</h3><table><tr><th>Division</th><th>Department</th><th class=n>Actual</th><th class=n>Budget</th><th>Actual vs budget (line = 100%)</th><th>Variance</th><th class=n>Employer cost</th><th class=n>Fully loaded</th></tr>{rows}</table>
<div class=note>Sorted worst first. Green = under budget, amber = up to 2% over, red = more than 2% over. Executive Office is over and Finance far under because three Finance staff were transferred to the Executive Office cost center while the budget stayed in Finance. Months with 3 biweekly pay runs (Oct 2025, May 2026) show ~+40% against a flat monthly budget and are flagged in the Variance column.</div></div>
<div class="tile w2"><h3>Where is overtime growing? <span class=leg><i style="background:#d92d20"></i>Q1 FY2027<i style="background:#98a2b3"></i>Q1 FY2026</span></h3>{bars}
<div class=note>Facilities &amp; Operations has the highest overtime share (9.6%) and it grew vs last year; Family Services fell.</div></div>
<div class="tile w2"><h3>Overtime cost and % by month <span class=leg><i style="background:#f79009"></i>Overtime $<i style="background:#101828"></i>Overtime %</span></h3>{svg_ot()}</div>
<div class="tile w4"><h3>Headcount and voluntary leavers by month <span class=leg><i style="background:#2e90fa"></i>Headcount<i style="background:#98a2b3"></i>Budgeted headcount<i style="background:#d92d20;border-radius:50%"></i>Voluntary leavers</span></h3>{svg_hc()}
<div class=note>Resignations peaked in Jan–Mar 2026 (13 people); headcount recovered from 168 to 175 by 30 Sep 2026, still below the budgeted 179.</div></div>
</div></body></html>"""

os.makedirs("mockups", exist_ok=True)
open("mockups/executive_dashboard_mockup.html", "w").write(page)
print("mockups/executive_dashboard_mockup.html written")
