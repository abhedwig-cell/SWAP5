#!/usr/bin/env python3
"""Regenerate PUB-GC numerical SVG figures F3-F6 from admitted evidence.

Standard library only. F1/F2 are conceptual schematics and are maintained as
version-controlled SVG source. This script owns only numerical/data-driven
figures and must not alter or reinterpret the evidence.
"""
from __future__ import annotations
import csv, json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent

def esc(s):
    return str(s).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace('"',"&quot;")

STYLE = """<style>
text{font-family:Arial,Helvetica,sans-serif;fill:#111}.title{font-size:28px;font-weight:700}
.panel{font-size:21px;font-weight:700}.label{font-size:18px}.small{font-size:15px}
.tiny{font-size:13px}.box{fill:#fff;stroke:#222;stroke-width:2}.soft{fill:#f2f2f2;stroke:#333;stroke-width:1.5}
.line{stroke:#222;stroke-width:2;fill:none}.dash{stroke:#555;stroke-width:2;stroke-dasharray:7 5;fill:none}
.grid{stroke:#ddd;stroke-width:1}.axis{stroke:#222;stroke-width:1.5}.note{font-size:14px;fill:#333}
</style>"""

def header(w,h,title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{STYLE}<text x="40" y="42" class="title">{esc(title)}</text>'

def text(x,y,s,cls="label",anchor="start"):
    return f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{esc(s)}</text>'

def multi(x,y,lines,cls="label",dy=22,anchor="middle"):
    tsp=[]
    for i,s in enumerate(lines):
        tsp.append(f'<tspan x="{x}" dy="{dy if i else 0}">{esc(s)}</tspan>')
    return f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{"".join(tsp)}</text>'

def rect(x,y,w,h,cls="box"):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" class="{cls}"/>'

def write(name,body):
    (OUT/name).write_text(body+"</svg>\n",encoding="utf-8")

# F3
e3=json.loads((ROOT/"PUB_GC_E3_INITIAL_RESULT.json").read_text())
valid=[c for c in e3["cases"] if c["status"]=="CONVERGED"]
xmin,xmax,ymin,ymax=-15,-11,-15,-8
px,py,pw,ph=110,145,850,540
sx=lambda v:px+(math.log10(v)-xmin)/(xmax-xmin)*pw
sy=lambda v:py+ph-(math.log10(v)-ymin)/(ymax-ymin)*ph
s=header(1400,820,"F3. Strict interface closure can coexist with negligible groundwater-head correction")
s+=text(45,88,"E3 valid loose-versus-iterative cases; both axes logarithmic.","small")
for p in range(xmin,xmax+1):
    x=px+(p-xmin)/(xmax-xmin)*pw
    s+=f'<line x1="{x}" y1="{py}" x2="{x}" y2="{py+ph}" class="grid"/>'+text(x,py+568,f"10^{p}","tiny","middle")
for p in range(ymin,ymax+1):
    y=py+ph-(p-ymin)/(ymax-ymin)*ph
    s+=f'<line x1="{px}" y1="{y}" x2="{px+pw}" y2="{y}" class="grid"/>'+text(px-15,y+4,f"10^{p}","tiny","end")
s+=f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" fill="none" class="axis"/>'
s+=text(px+pw/2,755,"|loose interface residual| [m s^-1]","label","middle")
for c in valid:
    xr=max(abs(c["loose"]["residual_m_per_s"]),1e-16); yr=max(abs(c["delta_h_iter_minus_loose_m"]),1e-16)
    r={1e-4:5,1e-3:7,1e-2:9}[c["window_day"]]
    fill={1e-4:"#bbb",1e-3:"#777",1e-2:"#222"}[c["window_day"]]
    s+=f'<circle cx="{sx(xr)}" cy="{sy(yr)}" r="{r}" fill="{fill}" stroke="#111"/>'
s+=rect(1000,150,340,480,"soft")
s+=multi(1170,190,["Valid E3 cases: 12 / 48","higher-flux predictor unavailable: 36 / 48","",
"Maximum loose residual",f'{e3["max_loose_relative_flux_mismatch"]:.2f} relative',
f'{e3["max_abs_delta_h_m"]:.2e} m max head correction',"",
"E3-R stronger-flux refinement","max head correction 1.83e-9 m","20 / 24 converged; 4 component-bound failures"],"small",25)
write("PUB_GC_F3_CLOSURE_VS_HEAD_CORRECTION.svg",s)

# F4
e4=json.loads((ROOT/"PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json").read_text())
bases=e4["baselines"]; x0,y0,w,h=100,150,1180,500; ymin4,ymax4=.95,1.10
sy4=lambda v:y0+h-(v-ymin4)/(ymax4-ymin4)*h
s=header(1400,820,"F4. Response identity depends on the finite-window boundary-value map")
for k in range(7):
    v=.95+.025*k; y=sy4(v)
    s+=f'<line x1="{x0}" y1="{y}" x2="{x0+w}" y2="{y}" class="grid"/>'+text(x0-12,y+4,f"{v:.3f}","tiny","end")
s+=f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" fill="none" class="axis"/>'
gw=w/len(bases)
for i,b in enumerate(bases):
    cx=x0+gw*(i+.5)
    vals=[b["u_FD"]/b["u_A"], None if b["J_S"] is None else b["J_S"]/b["u_A"], None if b["J_R"] is None else abs(b["J_R"])/b["u_A"]]
    for j,(v,off,fill) in enumerate(zip(vals,[-55,0,55],["#222","#777","#bbb"])):
        if v is None: s+=text(cx+off,sy4(1.005),"NA","tiny","middle"); continue
        y=sy4(v); base=sy4(ymin4)
        s+=f'<rect x="{cx+off-21}" y="{y}" width="42" height="{base-y}" fill="{fill}" stroke="#111"/>'+text(cx+off,y-8,f"{v:.3f}","tiny","middle")
    s+=text(cx,690,b["id"],"label","middle")+text(cx,714,f'u_A={b["u_A"]:.2e}',"tiny","middle")
s+=text(105,112,"B3 separates maps; B5 retains u_A ~= u_FD but has no symmetric head-driven derivative.","small")
write("PUB_GC_F4_RESPONSE_IDENTITY.svg",s)

# F5
e5=json.loads((ROOT/"PUB_GC_E5_INFORMATION_VALUE_RESULT.json").read_text())
rows=[r for r in e5["comparisons"] if r["baseline_id"] in ("B1","B2","B4")]
Cs=[.1,.5,.9,1.1,1.5,2.0]
methods=[("FP","FP_work","FP_status","#222",""),("AITKEN","AITKEN_work","AITKEN_status","#555","6 4"),
("SECANT","SECANT_COLD_work","SECANT_COLD_status","#777","2 3"),("u_A","U_A_work","U_A_status","#999","10 4"),
("oracle J_R","ORACLE_JR_work","ORACLE_JR_status","#bbb","12 3 2 3")]
s=header(1400,820,"F5. Supplied response adds little work reduction beyond cold black-box secant learning")
for pi,bid in enumerate(("B1","B2","B4")):
    bx,by,pw,ph=65+pi*445,155,390,500
    s+=text(bx,125,bid,"panel")
    x=lambda i:bx+25+i*(pw-50)/(len(Cs)-1); y=lambda v:by+ph-(v/20)*ph
    for yv in range(0,21,5):
        yy=y(yv); s+=f'<line x1="{bx}" y1="{yy}" x2="{bx+pw}" y2="{yy}" class="grid"/>'+text(bx-8,yy+4,str(yv),"tiny","end")
    s+=f'<rect x="{bx}" y="{by}" width="{pw}" height="{ph}" fill="none" class="axis"/>'
    for i,C in enumerate(Cs): s+=text(x(i),by+ph+24,str(C),"tiny","middle")
    for lab,wk,sk,col,dash in methods:
        rs=[next(r for r in rows if r["baseline_id"]==bid and float(r["C"])==C) for C in Cs]
        d=" ".join(("M" if i==0 else "L")+f'{x(i)} {y(r[wk])}' for i,r in enumerate(rs))
        s+=f'<path d="{d}" fill="none" stroke="{col}" stroke-width="2"'+(f' stroke-dasharray="{dash}"' if dash else "")+'/>'
        for i,r in enumerate(rs):
            xx,yy=x(i),y(r[wk])
            if r[sk]=="CONVERGED": s+=f'<circle cx="{xx}" cy="{yy}" r="5" fill="{col}" stroke="#111"/>'
            else: s+=f'<path d="M{xx-5},{yy-5} L{xx+5},{yy+5} M{xx+5},{yy-5} L{xx-5},{yy+5}" stroke="{col}" stroke-width="2"/>'
write("PUB_GC_F5_RESPONSE_INFORMATION_VALUE.svg",s)

# F6
with (ROOT/"PUB_GC_E6A_STATE_SCREEN_SUMMARY.csv").open(newline="") as fh: data=list(csv.DictReader(fh))
e6=json.loads((ROOT/"PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.json").read_text())
Hs=[-150,-75,-25,-10]; Qs=[1e-6,1e-4,1e-2,1e-1,1.0]
s=header(1400,820,"F6. Stronger local response does not guarantee a valid stronger coupled problem")
s+=rect(70,120,1260,145,"soft")+text(95,155,"A  Active-drainage route","panel")
s+=multi(700,155,[f'predictor q_bot = {e6["fixture"]["predictor_qbot_cm_per_day"]} cm/day; u_A = {e6["predictor"]["u_A"]:.3e}',
"prescribed-head reference corrector: KERNEL_STATUS_NOT_ADMITTED before any transaction attempt",
"preregistered live-MODFLOW matrix therefore skipped"],"small",28)
gx,gy,cw,ch=220,355,190,82
s+=text(70,310,"B  Accepted-state / predictor-flux screen","panel")
for j,q in enumerate(Qs): s+=text(gx+j*cw+cw/2,gy-16,f"{q:g} cm/d","small","middle")
for i,H in enumerate(Hs): s+=text(gx-25,gy+i*ch+ch/2+5,f"H0 {H} cm","small","end")
for i,H in enumerate(Hs):
    for j,q in enumerate(Qs):
        r=next(x for x in data if float(x["initial_h0_cm"])==H and float(x["predictor_qbot_cm_per_day"])==q)
        if r["predictor_ready"]!="true": label,fill="PRED FAIL","#d0d0d0"
        elif r["max_symmetric_ready_delta_h_m"]: label,fill=f'sym +/-{float(r["max_symmetric_ready_delta_h_m"]):.0e} m',"#f5f5f5"
        else: label,fill="no symmetric pair","#e4e4e4"
        s+=f'<rect x="{gx+j*cw}" y="{gy+i*ch}" width="{cw}" height="{ch}" fill="{fill}" stroke="#222"/>'+text(gx+j*cw+cw/2,gy+i*ch+45,label,"tiny","middle")
s+=multi(700,725,["8 / 20 predictors ready; 12 / 20 higher-flux predictors failed.",
"0 cases reached the preregistered +/-1e-4 m E6-B gate.","No production tolerance, retry budget or physics was changed."],"small",23)
write("PUB_GC_F6_COMPONENT_ADMISSION_ENVELOPE.svg",s)

print("Regenerated F3-F6 from admitted PUB-GC evidence.")
