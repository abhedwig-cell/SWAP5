"""Coherent transitive rebuild of the read-only next-window observer."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
# Observer sources are produced and pinned by observe_joint_entry_barrier.py.
prepared=Path(sys.argv[sys.argv.index('--prepared')+1]).resolve();at=sys.argv.index('--prepared');del sys.argv[at:at+2]
main_only='--main-only'in sys.argv
if main_only:sys.argv.remove('--main-only')
bundle=Path(sys.argv[sys.argv.index('--reuse')+1]).resolve();meta=json.loads((bundle/'BUILD.json').read_text());shadow={}
for name,pin in meta['source_sha256'].items():
 p=Path(name);assert hashlib.sha256(p.read_bytes()).hexdigest()==pin
 normalized=name.replace('\\','/')
 for area in ('src','app'):
  if '/'+area+'/' in normalized:
   relative=area+'/'+normalized.split('/'+area+'/',1)[1]
   if p.resolve()!=(ROOT/relative).resolve():shadow[ROOT/relative]=p
   break
overrides=[('app/solute_project/main_water.f90','main_observed.f90')]
if not main_only:overrides += [('src/legacy/b1_10_port/headcalc.f90','headcalc_observed.f90'),('src/runtime/mod_fmr_serialized_reference_backend.f90','backend_observed.f90')]
for relative,filename in overrides:shadow[ROOT/relative]=prepared/filename
clock=None if main_only else prepared/'clock.f90'
if clock is not None:assert clock.is_file()
pins={str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in [*shadow.values(),*([clock]if clock is not None else [])]}
(prepared/'COHERENT_SOURCE_PINS.json').write_text(json.dumps(pins,indent=2)+'\n')
recipe=ROOT/'tests/dataqual15_hupsel/build_and_run.py';source=recipe.read_text().replace('timeout=120','timeout=300')
needle="for s in list((ROOT/'src').rglob('*.f90'))+list((ROOT/'app/solute_column').glob('*.f90'))+list((ROOT/'app/solute_project').glob('*.f90'))+[original]:"
assert source.count(needle)==1
source=source.replace(needle,needle.replace('for s in','for original_source in').replace('[original]:','[original,clock]:'if clock is not None else '[original]:')+'\n s=shadow.get(original_source,original_source)')
source=source.replace('visit(program);order.remove(program);','program=shadow.get(program,program)\nvisit(program);order.remove(program);')
source=source.replace("visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')","visit(shadow[ROOT/'src/legacy/b1_10_port/headcalc.f90'])")
exec(compile(source,str(recipe)+'[coherent read-only entry observer]','exec'),{'__name__':'__main__','__file__':str(recipe),'clock':clock,'shadow':shadow})
assert all(hashlib.sha256(Path(n).read_bytes()).hexdigest()==h for n,h in pins.items())
