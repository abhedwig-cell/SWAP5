"""Compare measured113-node checkpoint profiles with real original output."""
import argparse,csv,hashlib,json,math,struct
from pathlib import Path
from checkpoint_layout import layout
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--profiles',type=Path,required=True);p.add_argument('--scalar',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
rows=lambda f:list(csv.DictReader(f.open()));reference=rows(a.profiles);scalar=list(csv.DictReader(l for l in a.scalar.read_text().splitlines()if l.strip()and not l.startswith('*')));byday={}
for r in reference:byday.setdefault(int(r['day']),[]).append(r)
files=list(a.run.glob('checkpoint-*.bin'))
if (a.run/'RESULT.json').exists():files.append(a.run/'checkpoint.bin')
measurements={}
for f in files:
 raw=f.read_bytes();s=layout(raw);day=int(s['clock'])
 if day not in byday:continue
 n=s['nodes'];old=sorted(byday[day],key=lambda r:int(r['node']));assert len(old)==n==113
 vector=lambda pos:list(struct.unpack_from('='+str(n)+'d',raw,pos))
 z=vector(s['header']+48);dz=vector(s['header']+48+8*n);assert abs(sum(dz)-600)<1e-12 and min(dz)>0
 pos=s['physical'];h=vector(pos);theta=vector(pos+8*n);pond=struct.unpack_from('=d',raw,pos+16*n)[0];temperature=vector(pos+16*n+16)
 assert all(math.isfinite(v)for v in [*h,*theta,*temperature])
 # A separate scalar/vector stock identity detects profile/time/unit mistakes.
 source_stock=math.fsum(float(r['water_content'])*w for r,w in zip(old,dz))+float(scalar[day]['PD_VOL'])
 assert abs(source_stock-float(scalar[day]['WTOT']))<1e-8,(day,source_stock,scalar[day]['WTOT'])
 differences={k:[abs(v-float(r[k]))for v,r in zip(vs,old)]for k,vs in [('head_cm',h),('water_content',theta),('temperature_c',temperature)]}
 near=[i for i,v in enumerate(z)if abs(v)<=30]
 measurements[day]=dict(day=day,checkpoint_sha256=hashlib.sha256(raw).hexdigest(),maximum_all_nodes={k:dict(difference=max(v),node=v.index(max(v))+1)for k,v in differences.items()},maximum_top30cm={k:max(v[i]for i in near)for k,v in differences.items()},bulk_water_difference_cm=math.fsum(v*w for v,w in zip(theta,dz))+pond-float(scalar[day]['WTOT']))
assert measurements
report=dict(status='MEASURED_ORIGINAL_NODAL_PROFILE_DIFFERENCES',sampled_days=sorted(measurements),nodes=113,profile_sha256=hashlib.sha256(a.profiles.read_bytes()).hexdigest(),scalar_sha256=hashlib.sha256(a.scalar.read_bytes()).hexdigest(),maximum_all_sampled_profiles={k:max(m['maximum_all_nodes'][k]['difference']for m in measurements.values())for k in ['head_cm','water_content','temperature_c']},measurements=[measurements[d]for d in sorted(measurements)],scope='Only retained actual checkpoint dates; not all daily profiles, whole energy equivalence or causal attribution.',scientific_equivalence=False)
a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k!='measurements'},indent=2))
