#!/usr/bin/env python3
"""Replay immutable F-VQ38 oracle/probe on actual current analytic kernels."""
import hashlib, importlib.util, json, pathlib, re, subprocess, tempfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
AUTHORITY='49728b999b884a37643908c1dad40269f4e2db9b'
ORACLE_PATH='tests/fvq/test_fvq38_dramet2_scientific.py'
ORACLE_BLOB='ee8773388e15b164b049aea297bdd78b7b701eaa'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
assert git('rev-parse',AUTHORITY+':'+ORACLE_PATH).decode().strip()==ORACLE_BLOB
build=pathlib.Path(tempfile.mkdtemp(prefix='ppa-wu05b12-scientific-'))
oracle_path=build/'immutable_oracle.py';oracle_path.write_bytes(git('show',AUTHORITY+':'+ORACLE_PATH))
spec=importlib.util.spec_from_file_location('fvq38_immutable',oracle_path)
oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
sources=[path for _,path in oracle.EXPECTED_BLOBS]
# Private validator purity and public forwarding accessors do not change any
# existing evaluator/preparation/validation arithmetic or status branches.
body_proof={}
pattern=re.compile(r'^  (?:pure )?(?:logical function|subroutine) (\w+)\b.*?^  end (?:function|subroutine) \1\b[^\n]*',re.M|re.S)
for (commit,path),blob in oracle.EXPECTED_BLOBS.items():
    # The certificate's exact scientific source blobs remain present in the
    # admitted canonical baseline. Historical owner commit/path locators are
    # not assumed to remain navigable in the current repository history.
    assert git('rev-parse','879a9c65b0badb650c9b4e4fe194b7e6ffcc02f6:'+path).decode().strip()==blob
    old=git('cat-file','blob',blob).decode();new=(ROOT/path).read_text()
    existing={m.group(1):m.group(0) for m in pattern.finditer(old)}
    current={m.group(1):m.group(0) for m in pattern.finditer(new)}
    assert existing
    for name,body in existing.items():
        observed=current[name].replace('  pure logical function','  logical function',1)
        assert observed==body,(path,name)
    body_proof[path]={name:hashlib.sha256(body.encode()).hexdigest() for name,body in existing.items()}
carrier=build/'mod_soil_water_solver_contract.f90'
carrier.write_text('''module mod_soil_water_solver_contract
 use iso_fortran_env,only:real64
 implicit none
 type::soil_water_physical_state_t
  integer::active_nodes=0
  real(real64),allocatable::pressure_head(:),water_content(:)
  real(real64)::ponding_depth=0._real64,groundwater_level=0._real64
 end type
end module
''')
probe=build/'probe.f90';probe.write_text(oracle.PROBE)
cases=oracle.build_cases();payload=oracle.serialize_cases(cases)
outputs=[]
for opt in [0,2]:
    out=build/f'o{opt}';out.mkdir()
    flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(out),'-I'+str(out)]
    ordered=[carrier,ROOT/'src/solver/mod_process_hydraulic_view.f90',*[ROOT/p for p in sources],probe]
    objects=[]
    for index,path in enumerate(ordered):
        obj=out/f'{index}.o';subprocess.run(['gfortran',*flags,'-c',str(path),'-o',str(obj)],check=True);objects.append(str(obj))
    exe=out/'probe';subprocess.run(['gfortran',f'-O{opt}',*objects,'-o',str(exe)],check=True)
    result=subprocess.run([str(exe)],input=payload,text=True,capture_output=True,check=True)
    (out/'output.txt').write_text(result.stdout);outputs.append(result.stdout)
assert outputs[0]==outputs[1]
observed=oracle.parse_outputs(outputs[0]);assert len(observed)==len(cases)==148
checks=0;max_flux=0.;max_derivative=0.;branches=set()
for case,result in zip(cases,observed):
    ipos=case['ipos'];x=case['x'];tag=case['tag'];expected=oracle.oracle(ipos,x)
    assert result['status']==0 and result['evaluated']==1,(ipos,tag)
    assert oracle.close(result['q'],expected['q']),(ipos,tag)
    max_flux=max(max_flux,abs(result['q']-expected['q']))
    assert bool(result['ddef'])==bool(expected['derivative_expected']),(ipos,tag)
    d=(x[12]-x[2])/x[1]
    if expected['derivative_expected'] and d>oracle.CUTOFF and tag!='above_cutoff':
        fd=oracle.oracle_fd(ipos,x);assert oracle.close(result['dq'],fd,rtol=3e-6,atol=2e-9)
        checks+=1;max_derivative=max(max_derivative,abs(result['dq']-fd)/max(1e-12,abs(fd)))
    if ipos in [2,3] and tag=='eqdepth':
        depth,branch,_=oracle.eqdepth_oracle(x[0],x[2],x[3],x[4]);assert result['branch']==branch
        assert oracle.close(result['aux1'],depth,rtol=5e-12,atol=2e-13);branches.add(branch)
    if tag=='negative_rrad':assert result['aux1']<0 and result['aux2']>0
    if tag=='below_cutoff':assert result['q']==0 and result['ddef']==1 and result['dq']==0
    if tag in ['exact_cutoff','interface_kink']:assert result['ddef']==0
    if tag=='interface_equal':assert result['ddef']==1
assert checks==132 and branches=={1,2,3}
record={'work_unit':'PPA-WU05B12','gate':'CURRENT_SOURCE_SCIENTIFIC_COMPONENT_PASS_NOT_RUNTIME_ADMISSION','authority':AUTHORITY,'immutable_oracle_blob':ORACLE_BLOB,'cases':len(cases),'derivative_checks':checks,'max_flux_abs_error':max_flux,'max_derivative_rel_error':max_derivative,'existing_bodies_unchanged':body_proof,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'build':str(build),'o0_o2_identity':True}
pathlib.Path('/tmp/frost-b12-scientific.json').write_text(json.dumps(record,indent=2)+'\n')
print('PPA_WU05B12_CURRENT_SOURCE_SCIENTIFIC_CASES=148 TANGENT_CHECKS=132')
print('PPA_WU05B12_CURRENT_SOURCE_SCIENTIFIC_O0_O2=PASS')
