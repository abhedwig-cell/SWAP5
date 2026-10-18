#!/usr/bin/env python3
"""Local age process/accepted-water qualification with literal immutable oracle."""
import base64, hashlib, io, json, os, pathlib, re, shlex, struct, subprocess, sys, tarfile, time, zlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(os.environ['AGE_RESULT_DIR']).resolve()
OUT.mkdir(parents=True, exist_ok=False)
FC = shlex.split(os.environ.get('FC', 'gfortran'))
events, inputs = [], {}
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args, cwd, category):
    start = time.perf_counter()
    p = subprocess.run(list(map(str, args)), cwd=cwd, capture_output=True)
    key = f'{len(events):04d}'
    (OUT / (key + '.stdout')).write_bytes(p.stdout)
    (OUT / (key + '.stderr')).write_bytes(p.stderr)
    events.append(dict(category=category, command=list(map(str,args)), seconds=time.perf_counter()-start,
        returncode=p.returncode, stdout=key+'.stdout', stderr=key+'.stderr'))
    (OUT/'events.json').write_text(json.dumps(events, indent=2)+'\n')
    if p.returncode:
        print(p.stdout.decode(errors='replace'), p.stderr.decode(errors='replace'))
        p.check_returncode()
    return p.stdout
def bind(p):
    if p.is_relative_to(ROOT):
        inputs[str(p.relative_to(ROOT))] = digest(p)
archive = ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz') as t:
    raw = t.extractfile('SWAP/solute.f90').read()
assert hashlib.sha256(raw).hexdigest() == '2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
lines = raw.decode('latin1').splitlines()
assert 'do i = 1, numnod' in lines[938]
assert 'Agefluxt = Agefluxb' in lines[985]
oracle = '''module historical_age_oracle
 use iso_fortran_env,only:real64
 use mod_b111_age_tracer_substep,only:b111_age_tracer_substep_forcing_t
 implicit none
contains
 subroutine literal_age_step(f,ageml,agemsy,production,root,drain,bottom)
 type(b111_age_tracer_substep_forcing_t),intent(in)::f
 real(real64),intent(inout)::ageml(:),agemsy(:)
 real(real64),intent(out)::production,root,drain,bottom
 integer::i,level,numnod,nrlevs,layer(size(ageml))
 real(real64)::agemlav,thetav,vpore,diffus,ddif,dispr,dtsolu,agefluxb,agefluxt,agedrain,agerot,agedrtot,ageprod,rottot,isqdra,sqdra
 real(real64)::inpola(size(ageml)+1),inpolb(size(ageml)),theta(size(ageml)),thetm1(size(ageml)),q(size(ageml)+1), &
   disnod(size(ageml)+1),ldis(size(ageml)),thetsl(size(ageml)),qrot(size(ageml)),dz(size(ageml)),qdra(size(f%qdra_cm_day,1),size(ageml))
 numnod=size(ageml);nrlevs=size(f%qdra_cm_day,1);layer=[(i,i=1,numnod)]
 inpola=0;inpolb=0;disnod=1;ldis=0;thetsl=1
 inpola(2:numnod)=f%face_left_weight;inpolb(1:numnod-1)=f%face_right_weight
 disnod(2:numnod)=f%face_distance_cm;ldis(1:numnod-1)=f%dispersivity_cm;thetsl(1:numnod-1)=f%theta_sat_left
 theta=f%theta;thetm1=f%theta_previous;dz=f%dz_cm;q=f%q_face_up_cm_day;qrot=f%root_sink_cm_day;qdra=f%qdra_cm_day
 dtsolu=f%dt_day;ddif=f%molecular_diffusion_cm2_day;agedrain=f%drain_age_day
 agefluxt=0;rottot=0;isqdra=0;sqdra=0
 production=sum(.5d0*(theta+thetm1)*dz)*dtsolu
''' + '\n'.join(lines[938:987]) + '''
 end do
 root=rottot;drain=sqdra;bottom=agefluxb
 end subroutine
end module
'''
results = dict(baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
    authority_sha256=hashlib.sha256(raw).hexdigest(),literal_lines=[939,987],runs={})
bind(archive);bind(pathlib.Path(__file__).resolve())
for opt in ('O0','O2'):
    build=OUT/opt;build.mkdir()
    source=build/'literal_age.f90';source.write_text(oracle)
    flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
        '-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
    providers=[ROOT/'src/process'/p for p in ('mod_solute_compartment_state.f90','mod_b111_age_tracer_substep.f90')]
    objects=[]
    driver=ROOT/'tests/nut-sol/test_age_process.f90'
    for i,p in enumerate(providers+[source,driver]):
        obj=build/f'process{i}.o';objects.append(obj);bind(p)
        run(FC+flags+(['-Wall','-Wextra','-Werror'] if p in providers else [])+['-c',p,'-o',obj],build,'process_compile')
    exe=build/'process';run(FC+flags+objects+['-o',exe],build,'process_link')
    stdout=run([exe],build,'process_native');assert b'AGE_LITERAL_150_STEPS_PRODUCTION_UNITS_BALANCE_INVALID_RETRY=PASS' in stdout
    results['runs'][opt]=dict(process_stdout=stdout.decode(),oracle_sha256=digest(source),process_provider_count=2)
    if '--process-only' in sys.argv: continue
    fixture=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';bind(fixture)
    text=fixture.read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
    (build/'matrix_fixture.inc').write_text(text[start:end]+'\n')
    stub=ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90';bind(stub)
    sources=list((ROOT/'src').rglob('*.f90'))+[stub,source];mapping={}
    for p in sources:
        for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):
            assert name.lower() not in mapping, name
            mapping[name.lower()]=p
    ordered=[];seen=set();active=set()
    def visit(p):
        if p in seen:return
        assert p not in active,p
        active.add(p)
        for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
            if name.lower() in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'):continue
            q=mapping[name.lower()]
            if q!=p:visit(q)
        active.remove(p);seen.add(p);ordered.append(p)
    driver=ROOT/'tests/nut-sol/test_age_joint.f90';visit(driver);ordered.remove(driver)
    surface_driver=ROOT/'tests/nut-sol/test_surface_age_joint.f90'
    visit(surface_driver);ordered.remove(surface_driver)
    ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
    objects=[]
    for i,p in enumerate(ordered+[driver]):
        obj=build/f'joint{i}.o';objects.append(obj);bind(p)
        run(FC+flags+['-c',p,'-o',obj],build,'physical_compile')
    exe=build/'joint';run(FC+flags+objects+['-o',exe],build,'physical_link')
    restart=build/'restart.bin';expected=build/'expected.bin';fresh=build/'fresh.bin'
    stdout=run([exe,'write',restart,expected],build,'physical_native');assert b'AGE_JOINT_ATOMIC_RETRY_RESTART_BALANCE=PASS' in stdout
    resumed=run([exe,'resume',restart,fresh],build,'physical_native');assert b'AGE_FRESH_PROCESS=PASS' in resumed
    assert expected.read_bytes()==fresh.read_bytes()
    raw=restart.read_bytes();n=struct.unpack_from('i',raw,152)[0];history=struct.unpack_from('i',raw,156)[0]
    chem=160+8*(2*n+2+(n if history else 0));count=struct.unpack_from('i',raw,chem+24)[0]
    values=chem+28;state=values+8*count
    negatives={'truncated':raw[:-12]};data=bytearray(raw);data[10]^=1;negatives['crc']=bytes(data)
    for label,offset,fmt,value in [('clock',136,'d',5.),('node_count',152,'i',100000),('revision',chem+8,'q',-1),
        ('age_clock',chem+16,'d',5.),('parameter_nan',values,'d',float('nan')),('water_nan',state,'d',float('nan')),
        ('negative_age',state+8*n,'d',-1.),('huge_age',state+8*n,'d',1e300)]:
        data=bytearray(raw[:-4]);struct.pack_into(fmt,data,offset,value)
        negatives[label]=bytes(data)+struct.pack('I',zlib.crc32(data)&0xffffffff)
    for label,data in negatives.items():
        path=build/(label+'.bin');path.write_bytes(data)
        out=run([exe,'reject',path,fresh],build,'physical_native');assert b'AGE_INVALID_DISK=PASS' in out
    surface_obj=build/'surface.o';bind(surface_driver)
    run(FC+flags+['-c',surface_driver,'-o',surface_obj],build,'surface_compile')
    surface_exe=build/'surface'
    run(FC+flags+objects[:-1]+[surface_obj,'-o',surface_exe],build,'surface_link')
    snapshot=build/'triplet.bin';surface_expected=build/'surface_expected.bin';surface_fresh=build/'surface_fresh.bin'
    surface_stdout=run([surface_exe,'write',snapshot,surface_expected],build,'surface_native')
    run([surface_exe,'resume',snapshot,surface_fresh],build,'surface_native')
    assert surface_expected.read_bytes()==surface_fresh.read_bytes()
    original=snapshot.read_bytes()
    # Outer envelope CRC binds the pair. Also exercise valid outer CRC with invalid inner payload.
    negatives={'truncated':original[:-1], 'overlong':original+b'x'}
    data=bytearray(original);data[32]^=1;negatives['outer_crc']=bytes(data)
    data=bytearray(original[:-4]);data[-10]^=1
    negatives['inner_crc']=bytes(data)+struct.pack('I',zlib.crc32(data)&0xffffffff)
    for label,data in negatives.items():
        path=build/('snapshot_'+label+'.bin');path.write_bytes(data)
        run([surface_exe,'reject',path,surface_fresh],build,'surface_native')
    results['runs'][opt]['surface']=dict(stdout=surface_stdout.decode(),endpoint_sha256=digest(surface_expected),
        fresh_sha256=digest(surface_fresh),snapshot_negatives=list(negatives))
    results['runs'][opt].update(physical_stdout=stdout.decode(),physical_provider_count=len(ordered),
        endpoint_sha256=digest(expected),fresh_sha256=digest(fresh),restart_negatives=list(negatives))
assert results['runs']['O0']['process_stdout']==results['runs']['O2']['process_stdout']
if '--process-only' not in sys.argv:
    assert (OUT/'O0/expected.bin').read_bytes()==(OUT/'O2/expected.bin').read_bytes()
    assert results['runs']['O0']['physical_stdout']==results['runs']['O2']['physical_stdout']
    assert (OUT/'O0/surface_expected.bin').read_bytes()==(OUT/'O2/surface_expected.bin').read_bytes()
results.update(input_sha256=inputs,cost_seconds={k:sum(e['seconds'] for e in events if e['category']==k) for k in sorted({e['category'] for e in events})},
    status='PROCESS_PASS' if '--process-only' in sys.argv else 'PHYSICAL_PASS_NOT_ADMITTED')
assert all(digest(ROOT/p)==h for p,h in inputs.items())
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print(results['status'],json.dumps(results['cost_seconds']))
