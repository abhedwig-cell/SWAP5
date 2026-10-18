"""Actual native reader: source-field fixtures, grammar and atomic negatives."""
from pathlib import Path
import hashlib,json,os,re,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_NATIVE_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
array="""MatNum = 1*1
MatName = 1*'Mineral ! fertiliser'
AppAge = 1*0.
OrgMatFrac = 1*0.
OrgNFrac = 1*0.
NH4NFrac = 1*.21
NO3NFrac = 1*.10
smedate = 1900-12-30 1901-01-01 1901-01-01
iMat = 1 1 1
Dosagekgha = 100. 50. 25.
VolatFraction = .1 .1 .1
"""
params=''.join(f'FOM{i}_t = 1.\n'for i in range(1,9))+"""Bio_t = 5.
Hum_t = 40.
cNH4_t = .02
cNO3_t = .03
Temp_ref = 20.
SorpCoef = .0002
RateConNitrif_ref = .02
RateConDenitr_ref = .03
WFPSCrit = .6
WFPScrit2 = .5
CdissiHalf = .1
TCSF_N = .5
dz_WSN = .3
cNH4N_lat = .3
cNO3N_lat = .4
cNH4N_seep = .1
cNO3N_seep = .2
cNH4N_top = 0.
cNO3N_top = 0.
"""
table="""MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac
1 'Mineral ! fertiliser' 0. 0. 0. .21 .10
smedate iMat Dosagekgha VolatFraction
1900-12-30 1 100. .1
1901-01-01 1 50. .1
1901-01-01 1 25. .1
;
"""
fixtures={'arrays':(array+params,0),'table':(table+params,0),
 'case_comments':((array+params).lower().replace(' = ',' = ').replace(' = .02\n',' = .02 ! scalar comment\n'),0),
 'continuation':(array.replace('100. 50. 25.','100.\n  50. 25.').replace('1 1 1','1\n 1 1')+params,0)}
for key,text in {
 'missing':(array+params).replace('FOM1_t = 1.\n',''),
 'duplicate':array+params+'Hum_t = 40.\n',
 'range':array+params.replace('Hum_t = 40.','Hum_t = 1001.'),
 'nonzero_top':array+params.replace('cNH4N_top = 0.','cNH4N_top = .1'),
 'unsupported_hum_exp':array+params+'RateconHum_exp = .1\n',
 'zero_repeat':array.replace('1 1 1','0*1')+params,
 'scalar_material':array.replace('MatNum = 1*1','MatNum = 1')+params,
 'cardinality':array.replace('100. 50. 25.','100 50')+params,
 'unknown_material':array.replace('1 1 1','1 9 1')+params,
 'array_duplicate':array+'iMat = 1 1 1\n'+params,
 'empty_comma':array.replace('100. 50. 25.','100,,50,25')+params,
 'trailing_comma':array.replace('100. 50. 25.','100,50,25,')+params,
 'unterminated':array.replace("fertiliser'","fertiliser")+params,
 'table_incomplete':table.replace('1901-01-01 1 50. .1','1901-01-01 1 50')+params,
 'overlong':array+('!'+'x'*513)+'\n'+params,
}.items():fixtures[key]=(text,-1)
for key,field,value in [('negative_nitrif','RateConNitrif_ref','-.02'),('lai_range','LaiCritNupt','11')]:
 text=array+params
 if field=='LaiCritNupt':text+=field+' = 11.\n'
 else:text=text.replace(field+' = .02',field+' = '+value)
 line=next(i+1 for i,s in enumerate(text.splitlines())if s.startswith(field+' ='))
 fixtures[key]=(text,-line)
for name,(text,_)in fixtures.items():(OUT/(name+'.snm')).write_text(text)
providers={}
for p in (ROOT/'src').rglob('*.f90'):
 for m in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.I|re.M):providers[m.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for m in re.findall(r'^\s*use\s*(?:,\s*intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.I|re.M):
  if m.lower() in providers:visit(providers[m.lower()])
 ordered.append(p)
driver=ROOT/'tests/nut-input/test_native_snm.f90';visit(driver)
events=[];outputs={}
def run(args,b,category):
 t=time.perf_counter();p=subprocess.run(list(map(str,args)),cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=list(map(str,args)),category=category,seconds=time.perf_counter()-t,returncode=p.returncode))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objs=[]
 for i,p in enumerate(ordered):
  o=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',o],b,'compile');objs.append(o)
 exe=b/'test';run(['gfortran',*flags,*objs,'-o',exe],b,'link')
 outputs[opt]={name:run([exe,OUT/(name+'.snm'),str(expected)],b,'native')for name,(_,expected)in fixtures.items()}
assert outputs['O0']==outputs['O2']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=dict(status='PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=run(['gfortran','--version'],OUT,'compiler').splitlines()[0],input_sha256={str(p.relative_to(ROOT)):sha(p)for p in ordered+[Path(__file__)]},fixtures={n:sha(OUT/(n+'.snm'))for n in fixtures},outputs=outputs,production_providers=len(ordered)-1,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print('NATIVE_SNM_O0_O2_PASS',len(fixtures),'fixtures',len(ordered)-1,'providers')
