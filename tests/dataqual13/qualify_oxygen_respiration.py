"""Original grass input, original compiled biomass oracle, current crop owners."""
import argparse,hashlib,json,re,subprocess,time,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=ROOT.parent/'dq13-oxygen-respiration-final')
out=parser.parse_args().output.resolve();out.mkdir(exist_ok=False)
ref=ROOT.parent/'dq13-reference431/providers';original=(ref/'selected/wofost.f90').read_text();oracle=out/'original_wofost.f90';oracle.write_text(original.replace('   private\n','   private\n   public :: read_wofost,initialize_wofost,initialize_grass,update_dvs_rate,update_wofost,r_act\n',1))
shutil.copyfile(ROOT/'reference/swap-4.3.1/projects/2.grassgrowth/grass.crp',out/'grass.crp')
# Extract the literal original oxygen-publication block; no scientific edits.
assim=original[original.index('   subroutine assimilation'):original.index('   end subroutine assimilation')]
body=assim[assim.index('         q10_root = p%q10'):assim.rindex('      end if')]
helper=out/'original_oxygen_respiration.f90'
helper.write_text('''subroutine original_oxygen_respiration()
use MOD_wofost,only:p,s_act,r_act,m_act,sw_wofost
use MOD_arrays,only:macroptb
use plant_interface,only:dvs,q10_root,c_mroot,f_senes,max_resp_factor
use atmosphere_interface,only:tav
implicit none
real(8)::rmres,teff,mres,asrc,cvf,help,froots,rg_roots,rm_roots,fr,fs,fl,fo,afgen
'''+body+'\nend subroutine\n')
driver=ROOT/'tests/dataqual13/grass_oxygen_respiration_driver.f90';mapping={}
for p in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  if name.lower()in mapping and mapping[name.lower()]!=p:visit(mapping[name.lower()])
 ordered.append(p)
visit(driver);ordered.remove(driver);events=[]
source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered+[driver]}
def run(cmd,**kw):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True,**kw);events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode));(out/(str(len(events))+'.stderr')).write_bytes(r.stderr);(out/(str(len(events))+'.stdout')).write_bytes(r.stdout);(out/'EVENTS.json').write_text(json.dumps(events,indent=2))
 if r.returncode:raise RuntimeError(r.stderr.decode()+r.stdout.decode())
 return r.stdout
fc='/usr/bin/x86_64-linux-gnu-gfortran-13'
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(f),'-J'+str(f),'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj')];objs=[]
 for i,p in enumerate(ordered+[oracle]):
  obj=f/(str(i)+'.o');run([fc,*flags,'-c',p,'-o',obj]);assert obj.stat().st_size>0;objs.append(obj)
 original_objects=sorted(p for p in(ref/'swobj').glob('*.o')if p.name.lower()!='wofost.o')
 run([fc,*flags,driver,helper,*objs,*original_objects,ref/'ttobj/libttutil.a','-o',f/'test'])
 stdout=run([f/'test'],cwd=out);(f/'stdout').write_bytes(stdout);assert b'ORIGINAL_OXYGEN_RESPIRATION_PASS'in stdout;print(opt,stdout.decode(),flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in source_hashes.items())
bindings={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in original_objects+[ref/'ttobj/libttutil.a',ref/'INPUTS.json',ref.parent/'BUILD.json']}
bindings.update({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ref/'selected').glob('*.f90')})
inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file() and p.suffix in ['.crp','.swp','.met']}
(out/'ORIGINAL_BINDINGS.json').write_text(json.dumps(dict(compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],original_artifacts_sha256=bindings,original_inputs_sha256=inputs),indent=2))
(out/'RESULT.json').write_text(json.dumps(dict(status='ORIGINAL_OXYGEN_RESPIRATION_PASS_NOT_PROJECT_RUN',events=events,source_sha256=source_hashes),indent=2))
