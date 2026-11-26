"""Real original CALCGWL on two exact retained original contexts, no full model."""
from pathlib import Path
import sys,os,json,subprocess,time,re,traceback,shutil
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','');sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import macro_perched_classification as candidate
res=json.loads((R/'RESOURCE_PATHS.json').read_text());ref=Path(res['O2']['path'])/'original-worker-reference';opt=sys.argv[1];b=Path(res[opt]['path'])/'PERCHED_COMPONENT_R1';b.mkdir(exist_ok=False)
text=(ref/'distribution/SWAP_4.3.1/cases/3.macroporeflow/swap.swp').read_text();grid=[list(map(float,l.split())) for l in text[text.index(' ISUBLAY ISOILLAY HSUBLAY NCOMP'):].splitlines()[1:9]];soil=[list(map(float,l.split())) for l in text[text.index('  ORES  OSAT'):].splitlines()[1:9]]
dz=[];sat=[]
for sub,lay,ht,n in grid:
 dz.extend([ht/n]*int(n));sat.extend([soil[int(lay)-1][1]]*int(n))
lines=(Path(res[opt]['path'])/'OBSERVER08_OWN2TO3/original/coupled_refusal_observer.txt').read_text().splitlines();cases=[]
for i in range(0,len(lines),9):
 h=lines[i].split()
 if h[0]=='3' and (h[3],h[13]) in [('59','2'),('60','4')]:
  v=list(map(float,lines[i+1].split()));cases.append(dict(gwl=float(h[6]),heads=v[:112],theta=v[112:224],perched=[int(h[17]),int(h[18])]))
assert len(cases)==2 and len(dz)==112
bbc=(ref/'distribution/SWAP_4.3.1/cases/3.macroporeflow/swap.bbc').read_text();swbot=int(re.search(r'(?mi)^\s*SWBOTB\s*=\s*(-?\d+)',bbc).group(1));crit=float(re.search(r'(?mi)^\s*CRITUNDSATVOL\s*=\s*([\d.]+)',text).group(1))
context=f'112 {swbot} {crit}\n'+''.join(f'{a:.17g} {s:.17g}\n' for a,s in zip(dz,sat))+'2\n'+''.join(' '.join(format(v,'.17g') for v in c['heads']+c['theta'])+'\n' for c in cases)
source=(ref/'build/swap-selected/calcgwl.f90').read_text();flags=['-'+opt,'-ffree-line-length-none','-fallow-argument-mismatch','-finit-local-zero']+(['-fcheck=all'] if opt=='O0' else [])
q=dict(opt=opt,status='RUNNING',contexts=cases,critical_air_cm=crit,compiler_scope='CALCGWL and driver '+opt+'; unchanged original providerO2',routes=[]);t=time.perf_counter()
try:
 for label,s in [('BASELINE',source),('CANDIDATE',candidate.render(source))]:
  d=b/label;d.mkdir();(d/'CONTEXTS.txt').write_text(context);(d/'calcgwl.f90').write_text(s);shutil.copyfile(ROOT/'tests/macro_complete01/test_perched_component.f90',d/'driver.f90')
  obj=ref/'build/swap-obj';tt=ref/'build/ttutil-obj';commands=[['gfortran',*flags,'-I',str(obj),'-c','calcgwl.f90'],['gfortran',*flags,'-I',str(obj),'-c','driver.f90'],['gfortran','-o','component.exe','driver.o','calcgwl.o',*(str(p) for p in sorted(obj.glob('*.o')) if p.name not in ['calcgwl.o','swap_main.o']),str(tt/'libttutil.a')]];logs=[]
  for cmd in commands:
   p=subprocess.run(cmd,cwd=d,capture_output=True,text=True,timeout=45);logs.append(dict(command=cmd,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr));(d/'BUILD.json').write_text(json.dumps(logs,indent=2)+'\n');assert p.returncode==0,p.stderr
  rt=time.perf_counter();p=subprocess.run([str(d/'component.exe')],cwd=d,capture_output=True,text=True,timeout=20);r=dict(label=label,returncode=p.returncode,seconds=time.perf_counter()-rt,stdout=p.stdout,stderr=p.stderr);q['routes'].append(r);(d/'RUN.json').write_text(json.dumps(r,indent=2)+'\n');assert p.returncode==0,p.stderr
 baseline=q['routes'][0]['stdout'].splitlines();patched=q['routes'][1]['stdout'].splitlines();assert len(baseline)==len(patched)==4 and baseline[:2]==patched[:2]
 for k,line in enumerate(baseline[2:]):
  x=line.split();assert int(x[7])==cases[k]['perched'][0] and int(x[8])==cases[k]['perched'][1] and abs(float(x[4])-cases[k]['gwl'])<1e-12
 for line in patched[2:]:
  x=line.split();assert int(x[7])==-1 and int(x[8])==-1
 q['status']='REAL_CALCGWL_COMPONENT_PASS_MACRO_CLASSIFICATION_AND_EXACT_NONMACRO_CONTROL'
except Exception:q.update(status='FAILED',error=traceback.format_exc())
q['seconds']=time.perf_counter()-t;(R/('PERCHED_'+opt+'_COMPONENT_R1.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({k:v for k,v in q.items() if k not in ['contexts']}));sys.exit(1 if q['status']=='FAILED' else 0)
