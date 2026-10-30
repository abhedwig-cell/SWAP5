"""Compare read-only actual donor/native germination observations, not model execution."""
import argparse,csv,datetime,hashlib,json,math,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--donor',type=Path,required=True);p.add_argument('--native',type=Path,required=True);p.add_argument('--previous',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(exist_ok=True)
text=(a.native/'potato.crp').read_text()
def literal(name):return float(re.search(r'^\s*'+name+r'\s*=\s*([0-9.EeDd+\-]+)',text,re.I|re.M).group(1).replace('D','E').replace('d','e'))
opt,base,cap,dry,wet,coef=[literal(n) for n in ['TSUMEMEOPT','TBASEM','TEFFMX','HDRYGERM','HWETGERM','AGERM']]
def increment(head,temp):
 pf=math.log10(max(1,-head));needed=opt
 if head<dry:needed=coef*pf+opt-coef*math.log10(-dry)
 elif head>wet:needed=-coef*pf+opt+coef*math.log10(-wet)
 amount=max(0,min(temp,cap)-base)
 return amount if needed<.1 else opt/needed*amount
D={r[0]:r for r in csv.reader((a.donor/'germination_donor.csv').open()) if r[1]=='potato.crp'}
P={int(r['day']):r for r in csv.DictReader((a.previous/'crop.csv').open())}
rows=[];previous_native=previous_donor=0
for n in csv.DictReader((a.native/'crop.csv').open()):
 day=int(n['day']);date=str(datetime.date(2002,1,1)+datetime.timedelta(days=day-1))
 if date not in D:continue
 d=D[date];nt,dt=float(n['germination_tsum']),float(d[6]);nh,dh=float(n['pressure_average_cm']),float(d[3]);navg,davg=float(n['mean_air_c']),float(d[5])
 rows.append(dict(day_end_clock=day,date=date,native_pressure_cm=nh,donor_pressure_cm=dh,pressure_difference_cm=nh-dh,native_temperature_c=navg,donor_temperature_c=davg,temperature_difference_c=navg-davg,native_tsum=nt,donor_tsum=dt,tsum_difference=nt-dt,previous_native_tsum=float(P[day]['germination_tsum']),native_increment_formula_residual=nt-previous_native-increment(nh,navg),donor_increment_formula_residual=dt-previous_donor-increment(dh,davg)))
 previous_native,previous_donor=nt,dt
assert len(rows)==29,'Require all actual original potato germination days May10–June7'
with (a.output/'native_donor_germination_measured.csv').open('w') as f:w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
manifest={'status':'ACTUAL_INPUT_AND_STATE_DIAGNOSIS_NOT_FULL_MODEL_QUALIFICATION','original_literal_parameters':dict(zip(['optimal','base','cap','dry','wet','a'],[opt,base,cap,dry,wet,coef])),'germination_days_compared':len(rows),'maximum_temperature_difference_c':max(abs(r['temperature_difference_c']) for r in rows),'maximum_native_increment_formula_residual':max(abs(r['native_increment_formula_residual']) for r in rows),'maximum_donor_increment_formula_residual':max(abs(r['donor_increment_formula_residual']) for r in rows),'common_june6':rows[-2],'common_june7':rows[-1],'input_sha256':{str(f):sha(f) for f in [a.native/'potato.crp',a.native/'crop.csv',a.previous/'crop.csv',a.donor/'germination_donor.csv']},'native_full_run_still_active':not(a.native/'RESULT.json').exists()}
(a.output/'MEASURED_COMPARISON.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
