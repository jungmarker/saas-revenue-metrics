"""Build a static, single-file HTML dashboard from the dbt marts.

    python report/build_report.py            # reads warehouse.duckdb, writes report/index.html
"""
import json
import os
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "report" / "index.html"


def q(con, sql):
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, [float(v) if hasattr(v, "is_finite") or isinstance(v, (int, float)) and not isinstance(v, bool) else str(v) if v is not None else None for v in row])) for row in cur.fetchall()]


def main():
    con = duckdb.connect(os.environ.get("WAREHOUSE_PATH", str(ROOT / "warehouse.duckdb")), read_only=True)
    latest = q(con, "select max(month_end) as m from marts.metrics_monthly")[0]["m"]
    data = {
        "as_of": latest,
        "kpis": q(con, f"""select segment, arr, customers, arpa_monthly, nrr_ttm, grr_ttm, arr_growth_yoy, logo_churn_rate
                          from marts.metrics_monthly where month_end = '{latest}'"""),
        "arr": q(con, """select segment, strftime(month_end, '%Y-%m') as month, arr from marts.metrics_monthly
                          where segment <> 'All' order by month_end"""),
        "retention": q(con, """select strftime(month_end, '%Y-%m') as month, nrr_ttm, grr_ttm from marts.metrics_monthly
                               where segment = 'All' and nrr_ttm is not null order by month_end"""),
        "bridge": q(con, """select strftime(month_end, '%Y-%m') as month, new_mrr + reactivation_mrr as new_mrr, expansion_mrr,
                                   contraction_mrr, churned_mrr from marts.mrr_bridge order by month_end desc limit 12"""),
        "cohorts": q(con, """select strftime(date_trunc('quarter', cohort_month), '%Y-Q') || quarter(cohort_month) as cohort,
                                    months_since_start, sum(cohort_mrr) / nullif(sum(cohort_starting_mrr), 0) as rev_retention,
                                    sum(cohort_customers) as n
                             from marts.customer_cohorts
                             where months_since_start in (0, 3, 6, 9, 12, 15, 18, 21, 24, 30, 36)
                             group by 1, 2 order by 1, 2"""),
    }
    data["bridge"].reverse()
    html = TEMPLATE.replace("__DATA__", json.dumps(data))
    OUT.write_text(html)
    print(f"wrote {OUT.relative_to(ROOT)} (as of {latest})")


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ledgerly Revenue Metrics</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
<style>
:root{--bg:#f7f8fa;--card:#fff;--ink:#14171f;--muted:#5f6675;--line:#e4e7ec;--a:#2f5bea;--b:#18a07a;--c:#e0912f;--neg:#d64545}
@media (prefers-color-scheme:dark){:root{--bg:#0f1218;--card:#171b24;--ink:#e8ebf1;--muted:#99a1b3;--line:#262c38}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Inter,sans-serif}
main{max-width:1180px;margin:0 auto;padding:28px 16px 48px}h1{font-size:22px;margin:0}h2{font-size:15px;margin:0 0 10px}
.sub{color:var(--muted);margin:4px 0 22px}.grid{display:grid;gap:14px}.k{grid-template-columns:repeat(auto-fit,minmax(170px,1fr))}
.two{grid-template-columns:repeat(auto-fit,minmax(320px,1fr))}.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:16px}
.kv{font-size:24px;font-weight:650;margin-top:4px}.kl{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em}
.ks{color:var(--muted);font-size:12px;margin-top:2px}table{border-collapse:collapse;width:100%;font-size:12px}
th,td{padding:5px 6px;text-align:center;border-bottom:1px solid var(--line)}th:first-child,td:first-child{text-align:left}
.defs dt{font-weight:600;margin-top:8px}.defs dd{margin:2px 0 0;color:var(--muted)}.wrap{overflow-x:auto}
footer{color:var(--muted);font-size:12px;margin-top:22px}
</style></head><body><main>
<h1>Ledgerly · Revenue Metrics</h1>
<div class="sub" id="asof"></div>
<div class="grid k" id="kpis"></div>
<div class="grid two" style="margin-top:14px">
 <div class="card"><h2>ARR by segment</h2><canvas id="arr" height="230"></canvas></div>
 <div class="card"><h2>MRR bridge · last 12 months</h2><canvas id="bridge" height="230"></canvas></div>
 <div class="card"><h2>Net &amp; gross revenue retention (trailing 12 mo.)</h2><canvas id="ret" height="230"></canvas></div>
 </div>
<div class="card" style="margin-top:14px"><h2>Revenue retention by quarterly cohort (MRR vs. starting MRR, months since first payment)</h2><div class="wrap" id="cohorts"></div></div>
<div class="card" style="margin-top:14px"><h2>Metric definitions</h2><dl class="defs">
 <dt>MRR / ARR</dt><dd>Sum of contract-line MRR active on the last day of the month; ARR = MRR × 12.</dd>
 <dt>Net revenue retention (NRR)</dt><dd>MRR today from customers who were paying 12 months ago ÷ their MRR 12 months ago. Includes expansion and contraction; churned customers count as $0.</dd>
 <dt>Gross revenue retention (GRR)</dt><dd>Same as NRR, but each customer is capped at their MRR 12 months ago, so expansion can't hide churn.</dd>
 <dt>MRR movements</dt><dd>New (first paid month), reactivation (paid again after $0), expansion, contraction, churn (to $0). Starting MRR + movements = ending MRR; a dbt test enforces this every month.</dd>
 <dt>Cohort revenue retention</dt><dd>Cohort's MRR N months after its first paid month ÷ its starting MRR.</dd>
</dl></div>
<footer>Built with dbt + DuckDB on synthetic data from <a href="https://github.com/jungmarker/ledgerly-data">ledgerly-data</a>. Source: github.com/jungmarker/saas-revenue-metrics</footer>
</main>
<script>
const D=__DATA__;
const css=n=>getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const money=v=>{const s=v<0?'-':'',a=Math.abs(v);return s+(a>=1e6?'$'+(a/1e6).toFixed(1)+'M':a>=1e3?'$'+(a/1e3).toFixed(0)+'K':'$'+Math.round(a))};
const pct=v=>v==null?'–':(v*100).toFixed(1)+'%';
document.getElementById('asof').textContent='Snapshot as of '+D.as_of+' · synthetic SaaS company, all segments';
const all=D.kpis.find(k=>k.segment==='All');
const tiles=[['ARR',money(all.arr),'YoY growth '+pct(all.arr_growth_yoy)],['Customers',all.customers.toLocaleString(),'ARPA '+money(all.arpa_monthly*12)+'/yr'],
 ['Net revenue retention',pct(all.nrr_ttm),'trailing 12 months'],['Gross revenue retention',pct(all.grr_ttm),'trailing 12 months'],
 ['Monthly logo churn',pct(all.logo_churn_rate),'customers lost this month']];
document.getElementById('kpis').innerHTML=tiles.map(t=>`<div class="card"><div class="kl">${t[0]}</div><div class="kv">${t[1]}</div><div class="ks">${t[2]}</div></div>`).join('');
Chart.defaults.color=css('--muted');Chart.defaults.borderColor=css('--line');Chart.defaults.font.family='-apple-system,Inter,sans-serif';
const months=[...new Set(D.arr.map(r=>r.month))];const segs=['SMB','Mid-Market','Enterprise'];const cols=[css('--c'),css('--b'),css('--a')];
new Chart(arr,{type:'line',data:{labels:months,datasets:segs.map((s,i)=>({label:s,fill:true,pointRadius:0,borderColor:cols[i],backgroundColor:cols[i]+'55',
 data:months.map(m=>(D.arr.find(r=>r.month===m&&r.segment===s)||{arr:0}).arr)}))},options:{scales:{y:{stacked:true,ticks:{callback:money}}},plugins:{tooltip:{callbacks:{label:c=>c.dataset.label+': '+money(c.raw)}}}}});
new Chart(bridge,{type:'bar',data:{labels:D.bridge.map(r=>r.month),datasets:[['New',('new_mrr'),css('--a')],['Expansion','expansion_mrr',css('--b')],['Contraction','contraction_mrr',css('--c')],['Churn','churned_mrr',css('--neg')]]
 .map(([l,k,c])=>({label:l,data:D.bridge.map(r=>r[k]),backgroundColor:c}))},options:{scales:{x:{stacked:true},y:{stacked:true,ticks:{callback:money}}}}});
new Chart(ret,{type:'line',data:{labels:D.retention.map(r=>r.month),datasets:[{label:'NRR',data:D.retention.map(r=>r.nrr_ttm),borderColor:css('--a'),pointRadius:0},
 {label:'GRR',data:D.retention.map(r=>r.grr_ttm),borderColor:css('--c'),pointRadius:0}]},options:{scales:{y:{ticks:{callback:v=>(v*100).toFixed(0)+'%'}}}}});
const steps=[...new Set(D.cohorts.map(r=>r.months_since_start))];const cohorts=[...new Set(D.cohorts.map(r=>r.cohort))];
const cell=v=>{if(v==null)return '<td></td>';const a=Math.max(0,Math.min(1,(v-0.5)/0.8));return `<td style="background:rgba(47,91,234,${0.08+a*0.55})">${Math.round(v*100)}%</td>`};
document.getElementById('cohorts').innerHTML='<table><tr><th>Cohort</th>'+steps.map(s=>`<th>M${s}</th>`).join('')+'</tr>'+
 cohorts.map(c=>'<tr><td>'+c+'</td>'+steps.map(s=>{const r=D.cohorts.find(x=>x.cohort===c&&x.months_since_start===s);return cell(r?r.rev_retention:null)}).join('')+'</tr>').join('')+'</table>';
</script></body></html>"""

if __name__ == "__main__":
    main()
