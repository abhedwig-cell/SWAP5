#!/usr/bin/env python3
"""Rebind the immutable F-VQ42 equations to current empirical production."""
import contextlib, hashlib, importlib.util, io, json, pathlib, re, subprocess, tempfile, types

ROOT=pathlib.Path(__file__).resolve().parents[2]
AUTHORITY='702db051bf5dd0960a962be919ea0cfbf01895a4'
ORACLE='tests/fvq/test_fvq42_empirical_interflow_scientific.py'
ORACLE_BLOB='5eea0d3b591df048b98cc1cc266a0ecb071712c7'
PROCESS='src/process/mod_drainage_empirical_interflow_response.f90'
BASELINE_BLOB='eb53096b678d08b76d3fb1adb2247bc2a58ee748'
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode().strip()
assert git('rev-parse',AUTHORITY+':'+ORACLE)==ORACLE_BLOB
assert git('rev-parse','703b70c49dbc5fb4f2c54381608432d13bb67cf7:'+PROCESS)==BASELINE_BLOB
old=git('cat-file','blob',BASELINE_BLOB)
current=(ROOT/PROCESS).read_text().strip()
pattern=re.compile(r'^  (?:pure )?(?:logical function|subroutine) (\w+)\b.*?^  end (?:function|subroutine) \1\b[^\n]*',re.M|re.S)
bodies={m.group(1):m.group(0) for m in pattern.finditer(old)}
actual={m.group(1):m.group(0) for m in pattern.finditer(current)}
assert set(bodies)=={'valid_parameters','evaluate_empirical_interflow_response'}
for name,body in bodies.items():
    assert actual[name].replace('  pure logical function','  logical function',1)==body,name
build=pathlib.Path(tempfile.mkdtemp(prefix='ppa-wu05b13-scientific-'))
immutable=build/'immutable_oracle.py'
immutable.write_bytes(subprocess.check_output(['git','show',AUTHORITY+':'+ORACLE],cwd=ROOT))
spec=importlib.util.spec_from_file_location('fvq42_immutable',immutable)
oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
# Change only the candidate locator and compilation plumbing. The immutable
# oracle's cases, independent equations, tolerances and numerical checks run
# unchanged, including the activation singularity metadata.
oracle.CANDIDATE=git('rev-parse','HEAD')
oracle.CANDIDATE_BLOB=git('rev-parse','HEAD:'+PROCESS)
oracle.MANIFEST=ROOT/oracle.MANIFEST
original_write=oracle.write_sources
class PersistentBuild:
    def __init__(self,**kwargs):pass
    def __enter__(self):return str(build)
    def __exit__(self,*args):return False
oracle.tempfile=types.SimpleNamespace(TemporaryDirectory=PersistentBuild)
def write_sources(tmp,source):
    original_write(tmp,source)
    pathlib.Path(tmp,'mod_process_hydraulic_view.f90').write_bytes((ROOT/'src/solver/mod_process_hydraulic_view.f90').read_bytes())
    pathlib.Path(tmp,'mod_soil_water_solver_contract.f90').write_text('''module mod_soil_water_solver_contract
 use iso_fortran_env,only:real64
 implicit none
 type::soil_water_physical_state_t
  integer::active_nodes=0
  real(real64),allocatable::pressure_head(:),water_content(:)
  real(real64)::ponding_depth=0._real64,groundwater_level=0._real64
 end type
end module
''')
def compile_driver(tmp,opt):
    exe=pathlib.Path(tmp,'driver_'+opt.replace('-',''))
    sources=['mod_soil_water_solver_contract.f90','mod_process_hydraulic_view.f90','candidate.f90','driver.f90']
    subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror=compare-reals','-fcheck=all','-ffpe-trap=invalid,zero,overflow',opt,'-J',tmp,'-I',tmp,*[str(pathlib.Path(tmp,s))for s in sources],'-o',str(exe)],check=True)
    return exe
oracle.write_sources=write_sources;oracle.compile_driver=compile_driver
output=io.StringIO()
with contextlib.redirect_stdout(output):assert oracle.main()==0
log=output.getvalue();print(log,end='')
summary=json.loads(re.search(r'^FVQ42_SUMMARY=(.*)$',log,re.M).group(1))
assert summary['active_cases']==1404 and summary['derivative_formula_checks']==1404
assert summary['finite_difference_checks']==6 and summary['inactive_contribution_checks']==8 and summary['activation_checks']==4
record={'work_unit':'PPA-WU05B13','gate':'CURRENT_SOURCE_SCIENTIFIC_COMPONENT_PASS_NOT_RUNTIME_ADMISSION','authority':AUTHORITY,'immutable_oracle_blob':ORACLE_BLOB,'body_proof':{n:hashlib.sha256(b.encode()).hexdigest()for n,b in bodies.items()},'summary':summary,'build':str(build),'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in [PROCESS,'src/solver/mod_process_hydraulic_view.f90']}}
pathlib.Path('/tmp/frost-b13-scientific.json').write_text(json.dumps(record,indent=2)+'\n')
print('PPA_WU05B13_CURRENT_SOURCE_SCIENTIFIC_O0_O2=PASS')
