#!/usr/bin/env python3
"""Replay the unchanged Q4A oracle on actual current production modules."""
import contextlib,hashlib,importlib.util,io,json,os,pathlib,re,subprocess,sys,tempfile,types
ROOT=pathlib.Path(__file__).resolve().parents[2]
AUTHORITY='48df989b098d73208eed2496005b656f588ebffd'
ORACLE='tests/sw-rib-swm01/test_q4a_extended_exchange_candidate.py'
DRIVER='tests/sw-rib-swm01/q4a_extended_exchange_driver.f90'
PROCESS='src/process/mod_drainage_extended_exchange.f90'
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT)
assert git('rev-parse',AUTHORITY+':'+ORACLE).decode().strip()=='ac04dc0a132183f400d49d3f13cb30e956124900'
assert git('rev-parse',AUTHORITY+':'+DRIVER).decode().strip()=='599ba9d809262419929163ef50f502346c230ebd'
old=git('show',AUTHORITY+':'+PROCESS).decode()
current=(ROOT/PROCESS).read_text()
pattern=re.compile(r'^  (?:pure )?subroutine (\w+)\b.*?^  end subroutine \1\b[^\n]*',re.M|re.S)
a={m.group(1):m.group(0)for m in pattern.finditer(old)}
b={m.group(1):m.group(0)for m in pattern.finditer(current)}
assert set(a)==set(b)=={'validate_extended_drainage_parameters','evaluate_extended_drainage_exchange'}
for n,s in a.items():assert b[n].replace('  pure subroutine','  subroutine',1)==s,n
build=pathlib.Path(tempfile.mkdtemp(prefix='ppa-wu05b19-scientific-'))
facade=build/'current_source';facade.mkdir();(facade/'src').symlink_to(ROOT/'src',target_is_directory=True)
(facade/'tests/sw-rib-swm01').mkdir(parents=True)
(facade/DRIVER).write_bytes(git('show',AUTHORITY+':'+DRIVER))
immutable=build/'immutable_oracle.py';immutable.write_bytes(git('show',AUTHORITY+':'+ORACLE))
spec=importlib.util.spec_from_file_location('q4a_immutable',immutable)
oracle=importlib.util.module_from_spec(spec);sys.modules[spec.name]=oracle;spec.loader.exec_module(oracle)
class PersistentBuild:
 def __init__(self,**kwargs):pass
 def __enter__(self):return str(build)
 def __exit__(self,*args):return False
oracle.tempfile=types.SimpleNamespace(TemporaryDirectory=PersistentBuild)
previous=os.environ.get('SWAP5_ROOT');os.environ['SWAP5_ROOT']=str(facade)
output=io.StringIO()
try:
 with contextlib.redirect_stdout(output):oracle.main()
finally:
 if previous is None:os.environ.pop('SWAP5_ROOT')
 else:os.environ['SWAP5_ROOT']=previous
log=output.getvalue();print(log,end='')
for opt in (0,2):assert f'SW_RIB_SWM01_Q4A_O{opt}_CASES=1507' in log
assert 'SW_RIB_SWM01_Q4A_O0_O2_IDENTITY=PASS' in log
paths=['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90',PROCESS]
record={'work_unit':'PPA-WU05B19','gate':'CURRENT_SOURCE_SCIENTIFIC_PASS_NOT_RUNTIME_ADMISSION','authority':AUTHORITY,'oracle_blob':'ac04dc0a132183f400d49d3f13cb30e956124900','driver_blob':'599ba9d809262419929163ef50f502346c230ebd','production_source_tree':git('rev-parse','HEAD:src').decode().strip(),'body_proof':{n:hashlib.sha256(s.encode()).hexdigest()for n,s in a.items()},'build':str(build),'cases_per_opt':1507,'actual_full_soil_contract':True,'source_sha256':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest()for f in paths},'O0_O2_identical':True}
pathlib.Path('/tmp/frost-b19-scientific.json').write_text(json.dumps(record,indent=2)+'\n')
print('PPA_WU05B19_CURRENT_SOURCE_SCIENTIFIC_O0_O2=PASS')
