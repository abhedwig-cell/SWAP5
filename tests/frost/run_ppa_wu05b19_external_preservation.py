"""Replay unchanged admitted F-APP09/VQ128 programs on B19 fresh whole modules."""
import argparse,gzip,hashlib,json,subprocess
from pathlib import Path
P=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--whole-record',required=True);ap.add_argument('--record',required=True);args=ap.parse_args()
def git(*a):return subprocess.check_output(['git',*a],cwd=P)
source='636e782080abdd2c0366f96317c4f59e8170dc53'
assert git('rev-parse','HEAD:src').decode().strip()==source
programs=[('FAPP09','ba3699f970d48b6b15db24fac1d1ec619f7fcb32','tests/fapp/test_fapp09_ribasim_external_surface_water_profile.f90','FAPP09_RIBASIM_EXTERNAL_SURFACE_WATER_PROFILE=PASS'),('VQ128','181c785de059842a6361a1f57951a129ed78d8bb','tests/fvq/test_fvq128_fapp09_independent.f90','F_VQ128_FAPP09_INDEPENDENT=PASS')]
receipt={'production_source_tree':source,'programs':{},'source_sha256':{}}
review=json.loads((P/'integration/audits/PPA_WU05B9_SOURCE_REVIEW.json').read_text())['recovered_oracles']
for n in (73,74):
 rel=f'tests/frost/oracles/immutable_vq{n}.f90'
 assert git('hash-object',str(P/rel)).decode().strip()==review[f'VQ{n}_test_blob']
 programs.append((f'VQ{n}',None,rel,f'FVQ{n}_'))
whole=json.loads(Path(args.whole_record).read_text());assert whole['production_source']==source
for f,h in whole['source_sha256'].items():assert hashlib.sha256(Path(f).read_bytes()).hexdigest()==h,f
receipt['whole_module_source_proof']=whole['source_sha256']
for opt in (0,2):
 b=Path(whole['build'])/f'o{opt}'
 assert (b/'mod_fmr_serialized_reference_backend.o').exists()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}',f'-J{b}',f'-I{b}']
 support=[]
 for rel in ['tests/fmr/mod_fmr04_fixed_top_provider.f90','src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90','src/runtime/mod_fmr_surface_water_swap_participant.f90']:
  obj=f'/tmp/frost-b19-external-{Path(rel).stem}-o{opt}.o'
  subprocess.run(['gfortran',*flags,'-c',str(P/rel),'-o',obj],check=True);support.append(obj)
  receipt['source_sha256'][rel]=hashlib.sha256((P/rel).read_bytes()).hexdigest()
 objects=[str(o)for o in b.glob('*.o')if not o.name.startswith('test_')]+support
 for label,authority,rel,marker in programs:
  frozen=git('show',authority+':'+rel)if authority else(P/rel).read_bytes()
  if label=='FAPP09':assert frozen==(P/rel).read_bytes(),rel
  # VQ128 primary contains additional accepted-window/rollback/owner guards
  # absent from the canonical materialized subset. Replay the exact primary.
  program=Path(f'/tmp/frost-b19-immutable-{label.lower()}.f90');program.write_bytes(frozen)
  obj=f'/tmp/frost-b19-external-{label.lower()}-o{opt}.o';exe=obj[:-2]
  subprocess.run(['gfortran',*flags,'-c',str(program),'-o',obj],check=True)
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,obj,'-o',exe],check=True)
  log=Path(f'/tmp/frost-b19-external-{label.lower()}-o{opt}.log')
  with log.open('w')as out,log.with_suffix('.err').open('w')as err:subprocess.run([exe],stdout=out,stderr=err,check=True)
  assert marker in log.read_text()
  receipt['programs'][label]={'authority':authority,'program_blob':git('rev-parse',authority+':'+rel).decode().strip()if authority else git('hash-object',str(P/rel)).decode().strip(),'program_sha256':hashlib.sha256(frozen).hexdigest(),'canonical_materialized_blob':git('hash-object',str(P/rel)).decode().strip(),'canonical_materialization_is_exact_primary':frozen==(P/rel).read_bytes()}
  print(f'B19_CURRENT_SOURCE_IMMUTABLE_{label}_O{opt}=PASS',flush=True)
for label,*_ in programs:
 a=Path(f'/tmp/frost-b19-external-{label.lower()}-o0.log');b=Path(f'/tmp/frost-b19-external-{label.lower()}-o2.log')
 assert a.read_bytes()==b.read_bytes()
 receipt['programs'][label]['O0_O2_stdout_identical']=True
 print(f'B19_CURRENT_SOURCE_IMMUTABLE_{label}_O0_O2_IDENTITY=PASS',flush=True)
Path(args.record).write_text(json.dumps(receipt,indent=2)+'\n')
