"""Focused unchanged production drivers for Hupsel's composed process chain."""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--lineage-only',action='store_true');p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.compiler=a.compiler.resolve();out=a.output.resolve();out.mkdir();programs=[ROOT/f for f in ['tests/physics/test_ppa_wu05d2_jarvis.f90','tests/fapp/test_ppa_wu04a_black_process.f90','tests/nut-sol/test_fixed_crop_phenology.f90']];mapping={}
if a.lineage_only:programs=[ROOT/'tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90']
for f in (ROOT/'src').rglob('*.f90'):
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',f.read_text(),re.M|re.I):mapping[n.lower()]=f
order=[];seen=set()
def visit(f):
 if f in seen:return
 seen.add(f)
 for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',f.read_text(),re.M|re.I):
  if n.lower()in mapping:visit(mapping[n.lower()])
 order.append(f)
for f in programs:visit(f)
order=[f for f in order if f not in programs];events=[];outputs={}
def run(cmd,label,folder):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=folder,capture_output=True,timeout=60);i=len(events);(folder/f'{i}.stdout').write_bytes(r.stdout);(folder/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(label=label,command=list(map(str,cmd)),seconds=time.monotonic()-t,returncode=r.returncode,**({'executable_sha256':sha(Path(cmd[0]))}if label=='native'else{})));(out/'EVENTS.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stdout.decode()+r.stderr.decode();return r.stdout
for opt in ['O0','O2']:
 folder=out/opt;folder.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-I'+str(folder),'-J'+str(folder)];objects=[]
 if a.lineage_only:flags+=['-ffpe-trap=invalid,zero,overflow']
 for i,f in enumerate(order):
  obj=folder/f'{i}.o';run([a.compiler,*flags,'-c',f,'-o',obj],'compile',folder);objects.append(obj)
 for driver in programs:
  exe=folder/driver.stem;run([a.compiler,*flags,driver,*objects,'-o',exe],'link',folder);raw=run([exe],'native',folder);(folder/(driver.stem+'.stdout')).write_bytes(raw);assert b'PASS'in raw;outputs[opt,driver.name]=raw;print(opt,driver.name,'PASS',flush=True)
if a.lineage_only:assert outputs['O0',programs[0].name]==outputs['O2',programs[0].name]
(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_CLIPPED_ROOT_LINEAGE_O0_O2_PASS'if a.lineage_only else'REAL_PRODUCTION_JARVIS_BLACK_FIXED_CROP_O0_O2_PASS',compiler=subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0],candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),provider_count=len(order),events=events,source_sha256={str(f):sha(f)for f in order+programs+[Path(__file__).resolve()]}),indent=2)+'\n')
