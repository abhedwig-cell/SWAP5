"""Original full main: frozen Andelst control and synthetic bare-soil N envelope.

No prescribed top-node state, physics stub, replacement time loop or changed
historical process equation. Existing accepted Linux DEC branch selection only.
"""
from pathlib import Path
import csv,gzip,hashlib,io,json,os,re,shlex,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_ORIGINAL_FULL_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];runs={}
sha=lambda b:hashlib.sha256(b).hexdigest()
def event(cmd,cwd,category,acceptable=(0,)):
 t=time.perf_counter()
 try:p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,stdin=subprocess.DEVNULL,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'1'},timeout=120 if category=='original_native' else None)
 except subprocess.TimeoutExpired as e:p=subprocess.CompletedProcess(list(map(str,cmd)),124,e.stdout or b'',(e.stderr or b'')+b'\nORIGINAL_NATIVE_BUDGET_TIMEOUT_120_SECONDS\n')
 i=len(events)
 item=dict(command=list(map(str,cmd)),category=category,returncode=p.returncode,seconds=time.perf_counter()-t)
 for stream in ['stdout','stderr']:
  name=f'{i:04d}.{stream}';b=getattr(p,stream);(OUT/name).write_bytes(b);item[stream]=name;item[stream+'_sha256']=sha(b)
 events.append(item);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode not in acceptable:raise RuntimeError('retained failed original event '+str(i))
 return p
DATA=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006'
NAMES=['swap.swp','swap.bbc','swap.dra','wintcer1.crp','wintcer2.crp','andelst_meteo.998','andelst_meteo.999','andelst_rain.998','andelst_rain.999']
inputs={str(DATA/('b111-'+q+'.gz')).removeprefix(str(ROOT)+'/'):sha((DATA/('b111-'+q+'.gz')).read_bytes())for q in NAMES}
for q in ['integration/audits/run_nut_original_full.py','tools/performance/build_swap431_perf01.py','tools/vq/b0_source_runner.py','tests/data/ppa_wu05_migmac01/B1.11-source-manifest.sha256','tests/data/ppa_wu05_migmac01/TTUTIL-source-manifest.sha256','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64','integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']:
 inputs[q]=sha((ROOT/q).read_bytes())

def replace(s,k,v):
 s,n=re.subn(r'(?im)^(\s*'+re.escape(k)+r'\s*=)[^!\r\n]*',lambda m:m[1]+' '+v+' ',s)
 if n!=1:raise ValueError('original project unique input '+k+' '+str(n))
 return s

def snm(stock,denitr):
 s="""MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac
1 'Mineral' 0. 0. 0. 0. 1.
smedate iMat Dosagekgha VolatFraction
2099-01-01 1 0. 0.
"""
 s+=''.join(f'FOM{i}_t = 0.\n'for i in range(1,9))
 values={'Bio_t':1e-8,'Hum_t':0,'cNH4_t':0,'cNO3_t':stock,'cNH4N_top':0,'cNO3N_top':.005,'cNH4N_lat':0,'cNO3N_lat':0,'cNH4N_seep':0,'cNO3N_seep':0,'Temp_ref':20,'SorpCoef':.0002,'RateConNitrif_ref':0,'RateConDenitr_ref':denitr,'WFPSCrit':.6,'WFPScrit2':.5,'CdissiHalf':1e-30,'TCSF_N':.5,'LaiCritNupt':1,'dz_WSN':.3}
 return s+''.join(f'{k} = {v:.17e}\n'for k,v in values.items())+'flCropExt = .FALSE.\n'

def nutrient_rows(path):
 if not path.exists():return []
 lines=path.read_text(errors='replace').splitlines();start=next(i for i,l in enumerate(lines)if l.startswith('Date,Day,Dcum,'));result=[]
 for row in csv.DictReader(lines[start:]):
  if not row.get('NH4_old'):continue
  try:v={k:float(x)for k,x in row.items()if k not in ['Date']}
  except ValueError:continue
  old=sum(v[k+'_old']for k in ['NFOM','NBio','NHum','NH4','NO3']);end=sum(v[k+'_end']for k in ['NFOM','NBio','NHum','NH4','NO3'])
  incoming=sum(v[k]for k in ['NFOM_add','NHum_add','NFOM_cres','NHum_cres','NH4N_amend','NO3N_amend','NH4N_cres','NO3N_cres','NH4_intop','NO3_intop','NH4_inlat','NO3_inlat','NH4_inbot','NO3_inbot'])
  outgoing=sum(v[k]for k in ['NH3N_volat','NH4_upt','NO3_upt','NH4_out','NO3_out','NO3_denitr'])
  residual=old+incoming-outgoing-end;scale=max(abs(old)+abs(incoming),abs(outgoing)+abs(end),1e-30)
  # Original output uses1pe11.4; preserve the rounding envelope per printed term.
  keys=[k+'_old'for k in ['NFOM','NBio','NHum','NH4','NO3']]+[k+'_end'for k in ['NFOM','NBio','NHum','NH4','NO3']]+['NFOM_add','NHum_add','NFOM_cres','NHum_cres','NH4N_amend','NO3N_amend','NH4N_cres','NO3N_cres','NH4_intop','NO3_intop','NH4_inlat','NO3_inlat','NH4_inbot','NO3_inbot','NH3N_volat','NH4_upt','NO3_upt','NH4_out','NO3_out','NO3_denitr']
  rounding=0.
  for k in keys:
   token=row[k].strip();m=re.search(r'[Ee]([+-]?\d+)',token)
   if m:rounding+=.5*10.**(int(m[1])-4)
  result.append(dict(date=row['Date'],initial_kg_ha=old,input_kg_ha=incoming,output_kg_ha=outgoing,final_kg_ha=end,residual_kg_m2=residual*1e-4,relative_residual=abs(residual)/scale,output_rounding_bound_kg_m2=rounding*1e-4,top_water_mm=v['WFl_inTop'],no3_top_kg_ha=v['NO3_intop'],crop_uptake_kg_ha=v['NH4_upt']+v['NO3_upt']))
 return result

for opt in ['O0','O2']:
 build=OUT/('build-'+opt)
 event([sys.executable,'-B',ROOT/'tools/performance/build_swap431_perf01.py','--output',build,'--opt',opt],ROOT,'original_full_build')
 manifest=json.loads((build/'INPUTS.json').read_text());flags=manifest['flags'];bs=build/'swobj';bt=build/'ttobj';main=build/'selected/swap_main.f90';obj=build/'swap_main.o';exe=build/'swap_original'
 event([*FC,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I',bt,'-I',bs,'-c',main,'-o',obj],bs,'main_compile')
 event([*FC,*flags,*sorted(bs.glob('*.o')),obj,bt/'libttutil.a','-o',exe],build,'main_link')
 for name in ['original-control-prefix','fallow-low','fallow-high','fallow-no-denitr','fallow-ample-no-denitr']:
  case=OUT/opt/name;case.mkdir(parents=True)
  for q in NAMES:(case/q).write_bytes(gzip.decompress((DATA/('b111-'+q+'.gz')).read_bytes()))
  control=case/'swap.swp';control.write_text(replace(control.read_text(encoding='cp1252'),'TEND','1998-01-10'),encoding='cp1252')
  if name!='original-control-prefix':
   p=case/'swap.swp';s=p.read_text(encoding='cp1252')
   for k,v in {'TEND':'1998-01-10','SWCROP':'1','SWRAIN':'0','SWMACRO':'0','SWDRA':'0','GWLI':'-1.0','PONDMX':'0.1','RSRO':'1.0','SWEND':'1','INLIST_CSV':"'RAIN,RUNOFF,WTOT,DSTOR,BALDEV,TOP_IN,TOP_OUT,EACT,EPD'"}.items():s=replace(s,k,v)
   s,n=re.subn(r'1998-01-01(\s+)1998-08-20',r'1998-01-15\g<1>1998-08-20',s);assert n==1,'future emergence row'
   s+="\nSWCROPSNM = 1\nSNMFIL = 'nut-main'\nPATHSNM = ' '\n";p.write_text(s,encoding='cp1252');(case/'nut-main.snm').write_text(snm(.05 if name in ['fallow-high','fallow-ample-no-denitr'] else 0.,0 if 'no-denitr'in name else 50.))
   p=case/'andelst_meteo.998';lines=[]
   for l in p.read_text(encoding='cp1252').splitlines():
    if l.lstrip().startswith("'ANDE-M'"):
     w=l.split();w[4:]=['15000.','20.','25.','1.5','2.','200.'if w[1]=='1'and w[2]=='1'else'0.','3.','1.'if w[1]=='1'and w[2]=='1'else'0.'];l=' '.join(w)
    lines.append(l)
   p.write_text('\n'.join(lines)+'\n',encoding='cp1252')
  caseinputs={str(q.relative_to(case)):sha(q.read_bytes())for q in case.iterdir()if q.is_file()}
  p=event([exe,'./swap.swp'],case,'original_native',acceptable=tuple(range(256))+(-11,-8,-6))
  error=(case/'swap.err').read_text(errors='replace')if(case/'swap.err').exists()else''
  ok=p.returncode==100 and(case/'swap.ok').exists()and not error.strip()
  rows=nutrient_rows(case/'result_nut.csv')
  runs[opt+'/'+name]=dict(returncode=p.returncode,success=ok,soil_n_executed=bool(rows),swap_ok=(case/'swap.ok').exists(),error=error,input_sha256=caseinputs,nutrient_rows=rows)
  (OUT/'runs.json').write_text(json.dumps(runs,indent=2)+'\n')
result=dict(status='ORIGINAL_FULL_MAIN_EXECUTED_QUALIFICATION_ONLY',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,runs=runs,production_changed=False,full_capability=False)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
