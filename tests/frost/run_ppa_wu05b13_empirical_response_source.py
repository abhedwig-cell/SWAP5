#!/usr/bin/env python3
"""Actual selected binding and corrected B7 source composition, O0/O2."""
import pathlib,re,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
BUILD=pathlib.Path(tempfile.mkdtemp(prefix='ppa-wu05b13-source-'))
stub=BUILD/'mod_soil_water_solver_contract.f90'
stub.write_text('''module mod_soil_water_solver_contract
 use iso_fortran_env,only:real64
 implicit none
 type::soil_water_physical_state_t
 integer::active_nodes=0
 real(real64),allocatable::pressure_head(:),water_content(:)
 real(real64)::ponding_depth=0._real64,groundwater_level=0._real64
 end type
end module
''')
modules={}
for p in [*ROOT.joinpath('src').rglob('*.f90'),ROOT/'tests/frost/mod_ppa_wu05b13_empirical_fixture.f90',stub]:
 m=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.I|re.M)
 if m:modules[m[1].lower()]=p
seen=set();ordered=[]
def visit(name):
 if name in seen or name not in modules:return
 seen.add(name);p=modules[name]
 for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),re.I|re.M):visit(n.lower())
 ordered.append(p)
for n in ['mod_fmr_drainage_response_binding','mod_ppa_wu05b13_empirical_fixture','mod_frost_low_air_drainage_effect']:visit(n)
ordered += [ROOT/'tests/frost/test_ppa_wu05b5_corrected_drain_globals.f90',ROOT/'reference/swap-4.3.1/frost-corrections/FROST-GEOMETRY-01/frozencond.f90',ROOT/'tests/frost/test_ppa_wu05b13_empirical_response_source.f90']
outputs=[]
for opt in (0,2):
 out=BUILD/f'o{opt}';out.mkdir()
 flags=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(out),'-I',str(out)]
 objects=[]
 for i,p in enumerate(ordered):
  obj=out/f'{i}.o';subprocess.run([*flags,'-c',str(p),'-o',str(obj)],check=True);objects.append(str(obj))
 subprocess.run(['gfortran',*objects,'-o',str(out/'test')],check=True)
 r=subprocess.run([str(out/'test')],capture_output=True,text=True,check=True)
 (out/'output.txt').write_text(r.stdout);print(r.stdout,end='');outputs.append(r.stdout)
assert outputs[0]==outputs[1]
print('PPA_WU05B13_EMPIRICAL_SOURCE_O0_O2_IDENTITY=PASS')
print('BUILD='+str(BUILD))
