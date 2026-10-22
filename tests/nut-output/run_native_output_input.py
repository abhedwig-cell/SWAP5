"""Fresh bounded native output request and complete incumbent parser checks."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
recipe=ROOT/'tests/nut-input/run_native_snm.py'
ns={'__file__':str(recipe),'__name__':'fixture_preparation'}
os.environ['N_NATIVE_RESULT_DIR']=str(OUT/'fixtures')
exec(compile(recipe.read_text().split('providers={}')[0],str(recipe),'exec'),ns)
base=ns['array']+ns['params'];cases={}
for name,token,value in [('true','.TRUE.',1),('mixed_true','.TrUe.',1),('false','.FALSE.',0),('mixed_false','.FaLsE.',0),('omitted','',0)]:
 text=base+('flCropExt = '+token+'\n' if token else '')
 cases[name]=(text,value)
for name,text in {
 'duplicate':base+'flCropExt=.TRUE.\nflCropExt=.FALSE.\n',
 'numeric':base+'flCropExt=1\n','bare':base+'flCropExt=TRUE\n',
 'quoted':base+"flCropExt='.TRUE.'\n",'comma':base+'flCropExt=.TRUE.,\n',
 'late_unknown':base+'flCropExt=.TRUE.\nwrong_name=1.\n',
 'late_range':base.replace('Hum_t = 40.','Hum_t = 1001.')+'flCropExt=.TRUE.\n',
 'late_missing':base.replace('FOM8_t = 1.\n','')+'flCropExt=.TRUE.\n',
}.items():cases[name]=(text,-1)
for name,(text,_)in cases.items():(OUT/(name+'.snm')).write_text(text)
providers={}
for f in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',f.read_text(),re.M|re.I):providers[name.lower()]=f
ordered=[];seen=set()
def visit(f):
 if f in seen:return
 seen.add(f)
 for name in re.findall(r'^\s*use\s*(?:,\s*intrinsic\s*::\s*|::\s*)?(\w+)',f.read_text(),re.M|re.I):
  if name.lower()in providers:visit(providers[name.lower()])
 ordered.append(f)
driver=ROOT/'tests/nut-output/test_native_output_input.f90';visit(driver);ordered.remove(driver)
events=[];outputs={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd,b,kind):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True);i=len(events)
 for k in ['stdout','stderr']:(OUT/f'{i:04d}.{k}').write_bytes(getattr(r,k))
 events.append(dict(command=cmd,category=kind,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();fc=os.environ.get('FC','gfortran');flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objs=[]
 for i,f in enumerate(ordered):
  obj=b/f'{i}.o';run([fc,*flags,'-c',f,'-o',obj],b,'compile');objs.append(obj)
 outputs[opt]={}
 for label,f in [('request',driver),('incumbent',ROOT/'tests/nut-input/test_native_snm.f90')]:
  obj=b/(label+'.o');exe=b/label;run([fc,*flags,'-c',f,'-o',obj],b,'driver_compile');run([fc,*flags,*objs,obj,'-o',exe],b,'link')
  if label=='incumbent':
   for name,(_,value)in ns['fixtures'].items():outputs[opt]['old-'+name]=run([exe,OUT/'fixtures'/(name+'.snm'),value],b,'incumbent_native')
  else:
   for name,(_,value)in cases.items():
    for mode in [0,1]:outputs[opt][name+'-'+str(mode)]=run([exe,OUT/(name+'.snm'),-1 if mode==0 and value==1 else value,mode],b,'native')
assert outputs['O0']==outputs['O2']
inputs=ordered+[driver,ROOT/'tests/nut-input/test_native_snm.f90',recipe,Path(__file__).resolve()]
report=dict(status='NATIVE_OUTPUT_INPUT_O0_O2_PASS',results=outputs,providers=len(ordered),new_cases=len(cases)*2,incumbent_cases=len(ns['fixtures']),input_sha256={str(f.relative_to(ROOT)):sha(f)for f in inputs},cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],report['new_cases'],report['incumbent_cases'])
