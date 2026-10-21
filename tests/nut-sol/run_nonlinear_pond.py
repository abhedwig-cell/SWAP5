#!/usr/bin/env python3
"""Nonlinear persistent pond: incumbent real drivers and independent quad inverse."""
import base64, hashlib, io, json, os, pathlib, re, shlex, struct, subprocess, sys, tarfile, time, zlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(os.environ['DYNAMIC_POND_RESULT_DIR']).resolve()
OUT.mkdir(parents=True, exist_ok=False)
EXPONENT = os.environ.get('POND_EXPONENT','1')
assert float(EXPONENT) in [0.5,0.8,1,1.0005,1.5,2]
REUSE = pathlib.Path(os.environ['POND_REUSE_BUILD']).resolve() if 'POND_REUSE_BUILD' in os.environ else None
FC = shlex.split(os.environ.get('FC', 'gfortran'))
events, inputs = [], {}
if REUSE:
    old=json.loads((REUSE/'result.json').read_text())
    assert old['status']=='NONLINEAR_POND_PHYSICAL_PASS_NOT_ADMITTED'
    for path,h in old['input_sha256'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==h, 'reused source drift '+path
    for path,h in old['artifacts'].items():
        assert hashlib.sha256((REUSE/path).read_bytes()).hexdigest()==h, 'reused artifact drift '+path
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args, cwd, category):
    args=list(args)
    if pathlib.Path(str(args[0])).name in ['joint','incumbent']:
        while len(args)<5: args.append('wet')
        args.append(EXPONENT)
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
assert 'csurf = (nird*cirr' in lines[345]
assert 'cmsy(i) = cmsy(i) + (cfluxb-cfluxt)' in lines[418]
surface = 'module historical_surface_oracle\n use iso_fortran_env,only:real64\n implicit none\ncontains\n subroutine literal_surface(initial,rain,rc,irr,ic,qtop,pond,dtsolu,cpond,transfer,remaining)\n real(real64),intent(in)::initial,rain,rc,irr,ic,qtop,pond,dtsolu\n real(real64),intent(out)::cpond,transfer,remaining\n real(real64)::csurf,nird,cirr,nraidt,cpre,cfluxt,ArMpSs,isqtop\n csurf=initial;nird=irr;cirr=ic;nraidt=rain;cpre=rc;ArMpSs=0\n' + '\n'.join(lines[345:355])+'''
 transfer=-cfluxt;remaining=csurf
 end subroutine
end module
'''
pre='module b111_literal_oracle\n use iso_fortran_env,only:real64\n use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t\n implicit none\ncontains\n subroutine literal_step(f,cml,cmsy_mass,decay_out,ext_in,ext_out)\n type(b111_reactive_solute_substep_forcing_t),intent(in)::f\n real(real64),intent(inout)::cml(:),cmsy_mass(:)\n real(real64),intent(out)::decay_out,ext_in,ext_out\n integer::numnod,i,level,nrlevs,swhea\n real(real64)::csurf,pond,qtop,ArMpSs,nird,cirr,nraidt,cpre,cpond,isqtop\n real(real64)::dtsolu,cfluxt,cfluxb,cmlav,dispr,cseep,ftemp,gampar,ftheta,rtheta,bexp,decact,ctrans,cref,frexp,tscf,crot,cdrtot,cdrain,isqdra,sqdra,imsqdra,qbot,sqbot,imsqbot,dectot,imdectot,rottot,imrottot\n real(real64)::tsoil(size(cml)),theta(size(cml)),dz(size(cml)),q(size(cml)+1),inpola(size(cml)+1),inpolb(size(cml)),thetav(size(cml)),dispr1(size(cml)),vpore2(size(cml)),disnod(size(cml)+1),decpotfdepth(size(cml)),bdenskfcref(size(cml)),bdenskf(size(cml)),qrot(size(cml)),cmsy(size(cml)),imqsol(size(cml)+1),qdra(size(f%qdra_cm_day,1),size(cml))\n numnod=size(cml);nrlevs=size(f%qdra_cm_day,1)\n tsoil=f%temperature_c;theta=f%theta;dz=f%dz_cm;q=f%q_face_up_cm_day;qdra=f%qdra_cm_day\n qrot=f%root_sink_cm_day;tscf=f%tscf;cdrain=f%cdrain_mg_cm3;cseep=f%cseep_mg_cm3\n dtsolu=f%dt_day;cref=f%cref_mg_cm3;frexp=f%frexp;swhea=0\n if(f%temperature_active)swhea=1\n gampar=f%gampar(1);rtheta=f%rtheta(1);bexp=f%bexp(1)\n bdenskf=f%bulk_density*f%kf;bdenskfcref=bdenskf*cref\n decpotfdepth=f%decpot*f%fdepth\n cmsy=cmsy_mass/dz\n inpola=0;inpolb=0;disnod=1;thetav=0;dispr1=0;vpore2=0\n inpola(2:numnod)=f%face_left_weight;inpolb(1:numnod-1)=f%face_right_weight\n disnod(2:numnod)=f%face_distance_cm\n do i=1,numnod-1\n thetav(i)=inpola(i+1)*theta(i)+inpolb(i)*theta(i+1)\n vpore2(i)=(abs(q(i+1))/thetav(i))**2\n dispr1(i)=f%molecular_diffusion_cm2_day*thetav(i)**2.33d0/f%theta_sat_left(i)**2+f%dispersivity_cm(i)*abs(q(i+1))/thetav(i)\n end do\n imqsol=0;\n csurf=0;pond=0;qtop=f%q_face_up_cm_day(1);ArMpSs=0\n nird=f%irrigation_rate_cm_day;cirr=f%irrigation_c_mg_cm3\n nraidt=f%rain_rate_cm_day;cpre=f%rain_c_mg_cm3\ndectot=0;imdectot=0;rottot=0;imrottot=0\n isqdra=0;sqdra=0;imsqdra=0;sqbot=0;imsqbot=0;qbot=q(numnod+1)\nPLACEHOLDER\n'
post=' cmsy_mass=cmsy*dz\n decay_out=dectot\n ext_in=(nird*cirr+nraidt*cpre)*dtsolu;ext_out=dectot+rottot\n do i=1,numnod\n do level=1,nrlevs\n if(qdra(level,i)>0)then\n ! Drain receipts can be evaluated from the literal mass balance, below.\n end if\n end do\n end do\n ! Signed sum is authoritative for the total balance; tests separately check\n ! production positive and negative boundary receipts in contract scenarios.\n ext_out=ext_out+sqdra-sqbot\n end subroutine\nend module\n'
pre=pre.replace('literal_step(f,cml,cmsy_mass,decay_out', 'literal_step(f,cml,cmsy_mass,surface_mass,decay_out').replace(' real(real64),intent(inout)::cml(:),cmsy_mass(:)', ' real(real64),intent(inout)::cml(:),cmsy_mass(:),surface_mass').replace('csurf=0;pond=0;', 'csurf=surface_mass;pond=f%pond_end_cm;')
post=post.replace(' cmsy_mass=cmsy*dz', ' surface_mass=csurf\n cmsy_mass=cmsy*dz')
oracle=pre.replace('PLACEHOLDER','\n'.join(lines[345:355]))+'\n'.join(lines[360:432])+'\n'+lines[441]+'\n'+lines[454]+'\n end do\n'+post
# Preserve historical surface/transport source order, use the previously accepted
# independent real128 Newton inverse for the explicit SWAP5 Freundlich law.
oracle=oracle.replace(' use iso_fortran_env,only:real64', ' use iso_fortran_env,only:real64\n use matrix_nonlinear_oracle,only:nonlinear_inverse',1)
assert oracle.count(lines[441])==1
oracle=oracle.replace(lines[441], ' if(frexp==1d0)then\n'+lines[441]+'\n else\n cml(i)=nonlinear_inverse(theta(i),f%bulk_density(i),f%kf(i),cref,frexp,cmsy(i))\n end if')

def parameterized_driver(path,build):
    bind(path)
    text=path.read_text()
    assert text.count('  call parameters(p)')==1
    text=text.replace('  call parameters(p)',"  call parameters(p)\n  block\n    character(64)::arg\n    call get_command_argument(5,arg)\n    read(arg,*)p%frexp\n  end block")
    generated=build/path.name
    generated.write_text(text)
    return generated

results = dict(exponent=float(EXPONENT),baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
    authority_sha256=hashlib.sha256(raw).hexdigest(),literal_lines=[[346,355],[361,432],[442,442],[455,455]],runs={})
bind(archive);bind(pathlib.Path(__file__).resolve())
for opt in ('O0','O2'):
    build=OUT/opt;build.mkdir()
    source=build/'literal_age.f90';source.write_text(surface)
    flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
        '-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
    providers=[ROOT/'src/process'/p for p in ('mod_b111_pond_solute_exchange.f90','mod_b111_surface_supply.f90')]
    objects=[]
    driver=ROOT/'tests/nut-sol/test_surface_process.f90'
    for i,p in enumerate(providers+[source,driver]):
        obj=build/f'process{i}.o';objects.append(obj);bind(p)
        run(FC+flags+(['-Wall','-Wextra','-Werror'] if p in providers else [])+['-c',p,'-o',obj],build,'process_compile')
    exe=build/'process';run(FC+flags+objects+['-o',exe],build,'process_link')
    stdout=run([exe],build,'process_native');assert b'SURFACE_LITERAL_150_UNITS_BALANCE_INVALID_CUTOFF=PASS' in stdout
    results['runs'][opt]=dict(process_stdout=stdout.decode(),oracle_sha256=digest(source),process_provider_count=2)
    if '--process-only' in sys.argv: continue
    fixture=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';bind(fixture)
    text=fixture.read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
    (build/'matrix_fixture.inc').write_text(text[start:end]+'\n')
    stub=ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90';bind(stub)
    joint_oracle=build/'literal_matrix_surface.f90';joint_oracle.write_text(oracle)
    inverse=ROOT/'tests/nut-sol/matrix_nonlinear_oracle.f90';bind(inverse)
    sources=list((ROOT/'src').rglob('*.f90'))+[stub,source,joint_oracle,inverse];mapping={}
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
    driver=parameterized_driver(ROOT/'tests/nut-sol/test_dynamic_pond_joint.f90',build);visit(driver);ordered.remove(driver)
    original_driver=ROOT/'tests/nut-sol/test_surface_joint.f90';visit(original_driver);ordered.remove(original_driver)
    ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
    objects=[]
    for i,p in enumerate(ordered+[driver]):
        obj=build/f'joint{i}.o';objects.append(obj);bind(p)
        if REUSE:
            import shutil
            shutil.copyfile(REUSE/opt/obj.name,obj)
        else:
            run(FC+flags+['-c',p,'-o',obj],build,'physical_compile')
    if REUSE:
        import shutil
        for mod in (REUSE/opt).glob('*.mod'):shutil.copyfile(mod,build/mod.name)
    exe=build/'joint';run(FC+flags+objects+['-o',exe],build,'physical_link')
    restart=build/'restart.bin';expected=build/'expected.bin';fresh=build/'fresh.bin'
    stdout=run([exe,'write',restart,expected],build,'physical_native');assert b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in stdout
    resumed=run([exe,'resume',restart,fresh],build,'physical_native');assert b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in resumed
    assert expected.read_bytes()==fresh.read_bytes()
    dry_restart=build/'dry-restart.bin';dry_expected=build/'dry-expected.bin';dry_fresh=build/'dry-fresh.bin'
    dry_stdout=run([exe,'write',dry_restart,dry_expected,'dry'],build,'physical_native')
    dry_resumed=run([exe,'resume',dry_restart,dry_fresh,'dry'],build,'physical_native')
    assert b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in dry_stdout
    assert b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in dry_resumed
    assert dry_expected.read_bytes()==dry_fresh.read_bytes()
    results['runs'][opt].update(dry_stdout=dry_stdout.decode(),dry_endpoint_sha256=digest(dry_expected))

    fill_stdout=run([exe,'write',build/'fill-restart.bin',build/'fill-expected.bin','fill'],build,'physical_native')
    fill_resume=run([exe,'resume',build/'fill-restart.bin',build/'fill-fresh.bin','fill'],build,'physical_native')
    assert b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in fill_stdout
    assert (build/'fill-expected.bin').read_bytes()==(build/'fill-fresh.bin').read_bytes()
    results['runs'][opt].update(fill_stdout=fill_stdout.decode(),fill_endpoint_sha256=digest(build/'fill-expected.bin'))
    # Execute the entire admitted fixed/dry pond driver using these production objects.
    incumbent=parameterized_driver(ROOT/'tests/nut-sol/test_pond_joint.f90',build)
    incumbent_obj=build/'incumbent.o'
    run(FC+flags+['-c',incumbent,'-o',incumbent_obj],build,'preservation_compile')
    incumbent_exe=build/'incumbent'
    run(FC+flags+objects[:-1]+[incumbent_obj,'-o',incumbent_exe],build,'preservation_link')
    for variant in ('wet','dry'):
        args=[] if variant=='wet' else ['dry']
        ir=build/(variant+'-incumbent.bin');ie=build/(variant+'-incumbent-expected.bin');ifresh=build/(variant+'-incumbent-fresh.bin')
        iw=run([incumbent_exe,'write',ir,ie]+args,build,'preservation_native')
        ires=run([incumbent_exe,'resume',ir,ifresh]+args,build,'preservation_native')
        assert b'POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in iw and ie.read_bytes()==ifresh.read_bytes()
        results['runs'][opt][variant+'_incumbent_endpoint_sha256']=digest(ie)
    gross_restart=build/'gross.bin'
    gw=run([incumbent_exe,'gross',gross_restart,build/'unused'],'gross_native')
    gr=run([incumbent_exe,'gross-resume',gross_restart,build/'unused'],'gross_native')
    assert b'MC_SOL01_GROSS_POSITIVE_RUNON_RUNOFF_JOINT_V2=PASS' in gw
    assert (build/'gross.bin.gross-next').read_bytes()==(build/'gross.bin.gross-fresh').read_bytes()
    results['runs'][opt]['gross_endpoint_sha256']=digest(build/'gross.bin.gross-next')

    raw=restart.read_bytes();n=struct.unpack_from('i',raw,152)[0];history=struct.unpack_from('i',raw,156)[0]
    chem=160+8*(2*n+2+(n if history else 0));count=struct.unpack_from('i',raw,chem+24)[0]
    values=chem+28;state=values+8*count
    negatives={'truncated':raw[:-12]};data=bytearray(raw);data[10]^=1;negatives['crc']=bytes(data)
    for label,offset,fmt,value in [('clock',136,'d',5.),('node_count',152,'i',100000),('revision',chem+8,'q',-1),
        ('chemical_clock',chem+16,'d',5.),('parameter_nan',values,'d',float('nan')),('water_nan',state,'d',float('nan')),
        ('negative_dissolved',state+16*n,'d',-1.),('wrong_sorbed',state+24*n,'d',100.),('surface_negative',len(raw)-12,'d',-1.),('surface_nan',len(raw)-12,'d',float('nan')),('surface_overbound',len(raw)-12,'d',1.01e12),('surface_infinite',len(raw)-12,'d',float('inf')),('surface_tag',0,'8s',b'S5MJ9999')]:
        data=bytearray(raw[:-4]);struct.pack_into(fmt,data,offset,value)
        negatives[label]=bytes(data)+struct.pack('I',zlib.crc32(data)&0xffffffff)
    for label,data in negatives.items():
        path=build/(label+'.bin');path.write_bytes(data)
        out=run([exe,'reject',path,fresh],build,'physical_native');assert b'POND_JOINT_INVALID_FILE=PASS' in out
    original=ROOT/'tests/nut-sol/test_surface_joint.f90';bind(original)
    original_oracle=build/'literal_original.f90'
    original_oracle.write_text(oracle.replace('literal_step(f,cml,cmsy_mass,surface_mass,decay_out','literal_step(f,cml,cmsy_mass,decay_out').replace('cml(:),cmsy_mass(:),surface_mass','cml(:),cmsy_mass(:)').replace('csurf=surface_mass;pond=f%pond_end_cm;','csurf=0;pond=0;').replace(' surface_mass=csurf\n',''))
    # Recompile oracle and original driver only; production objects remain byte-identical in this live run.
    original_objects=[]
    for j,source in enumerate((original_oracle,original)):
        obj=build/('original'+str(j)+'.o');original_objects.append(obj)
        run(FC+flags+['-c',source,'-o',obj],build,'preservation_compile')
    original_exe=build/'original'
    run(FC+flags+[obj for source,obj in zip(ordered,objects[:-1]) if source!=joint_oracle]+original_objects+['-o',original_exe],build,'preservation_link')
    original_stdout=run([original_exe,'write',build/'old-restart.bin',build/'old-expected.bin'],build,'preservation_native')
    original_resume=run([original_exe,'resume',build/'old-restart.bin',build/'old-fresh.bin'],build,'preservation_native')
    assert b'SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS' in original_stdout
    assert b'SURFACE_JOINT_FRESH_PROCESS=PASS' in original_resume
    assert (build/'old-expected.bin').read_bytes()==(build/'old-fresh.bin').read_bytes()
    assert digest(build/'old-expected.bin')=='7927b66f0ccf253d00795dd6c174a8323ac6e06d5bd6d384248e9bb0e7331d9e'
    results['runs'][opt].update(original_surface_stdout=original_stdout.decode(),original_surface_endpoint=digest(build/'old-expected.bin'))
    results['runs'][opt].update(physical_stdout=stdout.decode(),physical_provider_count=len(ordered),
        endpoint_sha256=digest(expected),fresh_sha256=digest(fresh),restart_negatives=list(negatives))
assert results['runs']['O0']['process_stdout']==results['runs']['O2']['process_stdout']
if '--process-only' not in sys.argv:
    assert (OUT/'O0/expected.bin').read_bytes()==(OUT/'O2/expected.bin').read_bytes()
    assert results['runs']['O0']['physical_stdout']==results['runs']['O2']['physical_stdout']
results.update(input_sha256=inputs,cost_seconds={k:sum(e['seconds'] for e in events if e['category']==k) for k in sorted({e['category'] for e in events})},
    status='PROCESS_PASS' if '--process-only' in sys.argv else 'NONLINEAR_POND_PHYSICAL_PASS_NOT_ADMITTED')
assert all(digest(ROOT/p)==h for p,h in inputs.items())
results['artifacts']={str(p.relative_to(OUT)):digest(p) for p in OUT.rglob('*') if p.is_file() and p.suffix in ['.o','.mod']}
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print(results['status'],json.dumps(results['cost_seconds']))
