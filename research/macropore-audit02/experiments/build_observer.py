"""Generate/link research-only observers against exact preserved original objects."""
import argparse,json,shutil,subprocess,time,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',required=True);p.add_argument('--target',default='x86-64-v3');p.add_argument('--template',type=Path);p.add_argument('--mode',choices=['rollback','retry','trace'],required=True)
a=p.parse_args();a.output.mkdir()
base=a.workspace/'O2/build';ref=a.workspace/'provider/generic-reference/build';here=Path(__file__).parent
for f in base.iterdir():
 if f.is_file():shutil.copyfile(f,a.output/f.name)
source=(base/'macropore.f90').read_text(encoding='cp1252')
if a.mode in ['rollback','retry']:
 source=(ref/'swap-selected/soilwater.f90').read_text(encoding='cp1252')
 source=source.replace('            call headcalc','            if(t1900>=35809d0.and.t1900<35810d0) call audit_state(0)\n            call headcalc')
 (a.output/'soilwater.f90').write_text(source,encoding='cp1252')
 source=(base/'swap.f90').read_text(encoding='cp1252')
 source=source.replace('            call SoilWaterStateVar(2)','            if(t1900>=35809d0.and.t1900<35810d0) call audit_state(1)\n            call SoilWaterStateVar(2)')
 source=source.replace('            call TimeControl(5)','            if(t1900>=35809d0.and.t1900<35810d0) call audit_state(2)\n            call TimeControl(5)')
 (a.output/'swap.f90').write_text(source,encoding='cp1252')
 shutil.copyfile(here/'state_observer.c',a.output/'observer.c');changed=['soilwater.f90','swap.f90']
 if a.mode=='retry':
  source=(base/'headcalc.f90').read_text(encoding='cp1252')
  source=source.replace('   call vector_F(1, hgrad)','   call retry_probe02()\n   call vector_F(1, hgrad)',1)
  source=source.replace('\ncontains\n','\ncontains\n'+(here/'retry_probe.f90').read_text()+'\n',1)
  (a.output/'headcalc.f90').write_text(source,encoding='cp1252');changed.append('headcalc.f90')
  # Keep only fork helpers from the second translation unit.
  c=(here/'retry_observer.c').read_text()+'\n#include <sys/wait.h>\n#include <unistd.h>\n#include <errno.h>\nint s5_shadow_begin'+(here/'fork_observer.c').read_text().split('int s5_shadow_begin',1)[1].split('int64_t audit_hash_',1)[0]
  (a.output/'observer.c').write_text(c)

else:
 source=(base/'headcalc.f90').read_text(encoding='cp1252')
 source=source.replace('   real(8)                          :: QMpLatSsSav, lateral_before_pond','   real(8)                          :: QMpLatSsSav, lateral_before_pond\n   integer :: audit_seq=0, audit_unit\n   real(8) :: audit_h(macp),audit_q(macp)')
 source=source.replace('   F = 0.0d0','   audit_seq=0\n   F = 0.0d0',1)
 source=source.replace('      call jacobian_F()','      call trace02(3)\n      call jacobian_F()\n      call trace02(4)')
 source=source.replace('         call vector_F(2, hgrad)','         call trace02(0)\n         call vector_F(2, hgrad)\n         call trace02(2)')
 source=source.replace('!        special case for macropores','         call trace02(5)\n!        special case for macropores')
 source=source.replace('         call MACROPORE(2)','         call MACROPORE(2)\n         audit_h=h\n         audit_q=QExcMpMtx\n         call trace02(1)')
 source=source.replace('\ncontains\n','\ncontains\n'+(a.template or here/'trace_observer.f90').read_text()+'\n',1)
 (a.output/'headcalc.f90').write_text(source,encoding='cp1252');shutil.copyfile(here/'fork_observer.c',a.output/'observer.c');changed=['headcalc.f90']
m=json.loads((base/'BUILD.json').read_text());flags=[*m['identity']['donor_flags'],'-march='+a.target];logs=[]
def run(cmd):
 t=time.perf_counter();r=subprocess.run(cmd,cwd=a.output,text=True,capture_output=True,timeout=30);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));(a.output/'AUDIT_BUILD.json').write_text(json.dumps(logs,indent=2));assert r.returncode==0,r.stderr
run(['gcc','-O2','-c','observer.c'])
for name in changed:run([a.compiler,*flags,'-I',str(base),'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-c',name])
replacements={Path(n).with_suffix('.o').name:a.output/Path(n).with_suffix('.o').name for n in m['identity']['donor_generated']}
replacements.update({Path(n).with_suffix('.o').name:a.output/Path(n).with_suffix('.o').name for n in changed})
run([a.compiler,'-o',str(a.output/'day_donor'),*(str(replacements.get(f.name,f)) for f in sorted((ref/'swap-obj').glob('*.o'))),str(a.output/'hybrid_step_budget.o'),str(a.output/'observer.o'),str(ref/'ttutil-obj/libttutil.a')])
# all Fortran statically stored globals/SAVEs, not only the checkpoint envelope.
symbols=[];offset=0
for line in subprocess.check_output(['nm','-S','--defined-only',str(a.output/'day_donor')],text=True).splitlines():
 x=line.split()
 if len(x)!=4 or x[2] not in 'bBdD':continue
 addr,size,kind,name=x;size=int(size,16)
 if not (name.startswith('__') and '_MOD_' in name or '.' in name):continue
 if name.startswith(('seen_reject','done','image_base')):continue
 symbols.append(dict(name=name,address=int(addr,16),size=size,offset=offset));offset+=size
(a.output/'symbols.txt').write_text(''.join(f'{s["address"]:x} {s["size"]:x} {s["name"]}\n' for s in symbols))
(a.output/'symbols.json').write_text(json.dumps(symbols,indent=2))
(a.output/'OBSERVER_IDENTITY.json').write_text(json.dumps(dict(mode=a.mode,compiler=subprocess.check_output([a.compiler,'--version'],text=True),files={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in a.output.iterdir() if f.is_file() and f.name in ['observer.c','headcalc.f90','macropore.f90','day_donor']},static_bytes=offset),indent=2))
print('built',a.mode,offset,'static bytes')
