#!/usr/bin/env python3
"""Measured bounded driver of real Fortran production. No persistent cache."""
import base64,hashlib,io,json,os,pathlib,re,shlex,subprocess,tarfile,time,struct,zlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=pathlib.Path(os.environ.get('MATRIX_RESULT_DIR',str(ROOT.parent/'matrix-evidence'))).resolve()
OUT.mkdir(parents=True,exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'))
FIXTURE=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90'
TEST=ROOT/'tests/nut-sol/test_matrix_route.f90'
JOINT=ROOT/'tests/nut-sol/test_matrix_joint.f90'
BUNDLE=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
events=[]
NONLINEAR=os.environ.get('MATRIX_NONLINEAR')=='1'
EXPONENTS=('1','0.5','0.8','1.0005','1.5','2') if NONLINEAR else ('1',)
PROCESS_ONLY='--process-only' in sys.argv[1:]
INVERSE=ROOT/'tests/nut-sol/matrix_nonlinear_oracle.f90'
PARTITION=ROOT/'tests/nut-sol/test_matrix_nonlinear_partition.f90'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def command(args,cwd,category):
 t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True)
 i=len(events);(OUT/f'{i:04d}.stdout').write_bytes(r.stdout);(OUT/f'{i:04d}.stderr').write_bytes(r.stderr)
 events.append({'category':category,'seconds':time.perf_counter()-t,'returncode':r.returncode,'command':list(map(str,args))})
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:
  print(r.stdout.decode(errors='replace'));print(r.stderr.decode(errors='replace'));r.check_returncode()
 return r.stdout
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(BUNDLE.read_bytes())),mode='r:gz') as a:
 raw=a.extractfile('SWAP/solute.f90').read()
# Immutable B1.11 authority. Never use public main as a substitute.
expected='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
# The archive source hash is retained independently with exact literal lines.
source_hash=hashlib.sha256(raw).hexdigest()
if source_hash!=expected:raise RuntimeError('B1.11 source hash mismatch')
lines=raw.decode('latin1').splitlines()
assert 'cmsy(i) = cmsy(i) + (cfluxb-cfluxt)' in lines[418]
assert 'cml(i) = cmsy(i) / (theta(i) + bdenskf(i))' in lines[441]
loop='\n'.join(lines[360:432])+'\n'+lines[441]+'\n'+lines[454]+'\n          end do\n'
# Keep all historical transport/reaction expressions literal. Only its inverse
# is independently solved in quad for the explicitly classified nonlinear path.
loop=loop.replace(lines[441],''' if(abs(frexp-1.0_real64)<=epsilon(1.0_real64))then
'''+lines[441]+'''
 else
 cml(i)=nonlinear_inverse(theta(i),f%bulk_density(i),f%kf(i),cref,frexp,cmsy(i))
 end if''')
pre='''module b111_literal_oracle
 use iso_fortran_env,only:real64
 use matrix_nonlinear_oracle,only:nonlinear_inverse
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 implicit none
contains
 subroutine literal_step(f,cml,cmsy_mass,decay_out,ext_in,ext_out)
 type(b111_reactive_solute_substep_forcing_t),intent(in)::f
 real(real64),intent(inout)::cml(:),cmsy_mass(:)
 real(real64),intent(out)::decay_out,ext_in,ext_out
 integer::numnod,i,level,nrlevs,swhea
 real(real64)::dtsolu,cfluxt,cfluxb,cmlav,dispr,cseep,ftemp,gampar,ftheta,rtheta,bexp,decact,ctrans,cref,frexp,tscf,crot,cdrtot,cdrain,isqdra,sqdra,imsqdra,qbot,sqbot,imsqbot,dectot,imdectot,rottot,imrottot
 real(real64)::theta(size(cml)),dz(size(cml)),q(size(cml)+1),inpola(size(cml)+1),inpolb(size(cml)),thetav(size(cml)),dispr1(size(cml)),vpore2(size(cml)),disnod(size(cml)+1),decpotfdepth(size(cml)),bdenskfcref(size(cml)),bdenskf(size(cml)),qrot(size(cml)),cmsy(size(cml)),imqsol(size(cml)+1),qdra(size(f%qdra_cm_day,1),size(cml))
 numnod=size(cml);nrlevs=size(f%qdra_cm_day,1)
 theta=f%theta;dz=f%dz_cm;q=f%q_face_up_cm_day;qdra=f%qdra_cm_day
 qrot=f%root_sink_cm_day;tscf=f%tscf;cdrain=f%cdrain_mg_cm3;cseep=f%cseep_mg_cm3
 dtsolu=f%dt_day;cref=f%cref_mg_cm3;frexp=f%frexp;swhea=0
 if(f%temperature_active)swhea=1
 gampar=f%gampar(1);rtheta=f%rtheta(1);bexp=f%bexp(1)
 bdenskf=f%bulk_density*f%kf;bdenskfcref=bdenskf*cref
 decpotfdepth=f%decpot*f%fdepth
 cmsy=cmsy_mass/dz
 inpola=0;inpolb=0;disnod=1;thetav=0;dispr1=0;vpore2=0
 inpola(2:numnod)=f%face_left_weight;inpolb(1:numnod-1)=f%face_right_weight
 disnod(2:numnod)=f%face_distance_cm
 do i=1,numnod-1
 thetav(i)=inpola(i+1)*theta(i)+inpolb(i)*theta(i+1)
 vpore2(i)=(abs(q(i+1))/thetav(i))**2
 dispr1(i)=f%molecular_diffusion_cm2_day*thetav(i)**2.33d0/f%theta_sat_left(i)**2+f%dispersivity_cm(i)*abs(q(i+1))/thetav(i)
 end do
 cfluxt=0;imqsol=0;dectot=0;imdectot=0;rottot=0;imrottot=0
 isqdra=0;sqdra=0;imsqdra=0;sqbot=0;imsqbot=0;qbot=q(numnod+1)
'''
# Raw literal block needs only its historical tsoil variable.
pre=pre.replace('theta(size(cml)),','tsoil(size(cml)),theta(size(cml)),').replace('theta=f%theta;','tsoil=f%temperature_c;theta=f%theta;')
post=''' cmsy_mass=cmsy*dz
 decay_out=dectot
 ext_in=0;ext_out=dectot+rottot
 do i=1,numnod
 do level=1,nrlevs
 if(qdra(level,i)>0)then
 ! Drain receipts can be evaluated from the literal mass balance, below.
 end if
 end do
 end do
 ! Signed sum is authoritative for the total balance; tests separately check
 ! production positive and negative boundary receipts in contract scenarios.
 ext_out=ext_out+sqdra-sqbot
 end subroutine
end module
'''
results={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
 'authority_member':'SWAP/solute.f90','authority_sha256':source_hash,'archive_sha256':sha(BUNDLE),
 'literal_lines':[[361,432],[442,442],[455,455]],'inverse_policy':'linear literal; nonlinear independent real128 Newton, classified historical difference',
 'exponents':EXPONENTS,'process_only':PROCESS_ONLY,'runs':{},'process_runs':{},
 'input_sha256':{str(p.relative_to(ROOT)):sha(p) for p in (TEST,JOINT,FIXTURE,INVERSE,PARTITION,pathlib.Path(__file__).resolve())}}
# Check pinned hash from the qualified donor source probe.
PIN=expected
results['authority_pin']=PIN
for opt in ('O0','O2'):
 build=OUT/('process-'+opt);build.mkdir(exist_ok=True)
 historical=build/'b111_historical_inverse.f90'
 block='\n'.join(lines[433:452])
 # Safety observer only: unchanged expressions/stop predicate, bounded failure
 # instead of a hung qualification if the original iteration diverges.
 block=block.replace('do while (differ)','''do while (differ)
 iterations=iterations+1
 if(iterations>100000)then
 status=1;return
 end if''')
 historical.write_text('''module b111_historical_inverse
 use iso_fortran_env,only:real64
 implicit none
contains
 subroutine historical_inverse(w,b,r,n,m,c0,c,iterations,status)
 real(real64),intent(in)::w,b,r,n,m,c0
 real(real64),intent(out)::c
 integer,intent(out)::iterations,status
 real(real64),parameter::rer=1d-3,vsmall=1d-15
 real(real64)::theta(1),bdenskf(1),cmsy(1),cml(1),dz(1),cref,frexp,rounderr,old,dummy
 logical::differ
 integer::i
 theta=w;bdenskf=b;cmsy=m;cml=c0;dz=1;cref=r;frexp=n;rounderr=0;i=1;iterations=0;status=0
'''+block+'''
 c=cml(1)
 end subroutine
end module
''')
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror','-fcheck=all',
        '-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
 objects=[]
 for i,p in enumerate((ROOT/'src/process/mod_b111_solute_sorption.f90',INVERSE,historical,PARTITION)):
  obj=build/f'{i}.o';objects.append(str(obj))
  command(FC+flags+['-c',str(p),'-o',str(obj)],build,'compile')
  if p.is_relative_to(ROOT):results['input_sha256'][str(p.relative_to(ROOT))]=sha(p)
 exe=build/'partition'
 command(FC+flags+objects+['-o',str(exe)],build,'link')
 stdout=command([str(exe)],build,'native').decode();print(stdout,flush=True)
 if 'MATRIX_NONLINEAR_PARTITION_UNITS_LEGACY_DIFFERENCES=PASS' not in stdout:raise RuntimeError('partition missing PASS')
 results['process_runs'][opt]={'stdout':stdout,'historical_oracle_sha256':sha(historical),'source_count':4}
if results['process_runs']['O0']['stdout']!=results['process_runs']['O2']['stdout']:raise RuntimeError('process O0/O2 differs')
for opt in ('O0','O2'):
 if PROCESS_ONLY:break
 build=OUT/opt;build.mkdir(exist_ok=True)
 oracle=build/'mod_b111_literal_oracle.f90';oracle.write_text(pre+loop+post)
 text=FIXTURE.read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 fixture=build/'matrix_fixture.inc';fixture.write_text(text[start:end]+'\n')
 sources=[p for p in (ROOT/'src').rglob('*.f90')]+[ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90',oracle,INVERSE]
 providers={}
 for p in sources:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  if p in active:raise RuntimeError('module cycle '+str(p))
  active.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   if name.lower() in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib','ieee_exceptions'):continue
   q=providers.get(name.lower())
   if q is None:raise RuntimeError('unresolved '+name+' in '+str(p))
   if q!=p:visit(q)
  active.remove(p);seen.add(p);ordered.append(p)
 visit(TEST);visit(JOINT)
 ordered=[p for p in ordered if p not in (TEST,JOINT)]
 ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
 for p in ordered:
  if p.is_relative_to(ROOT):results['input_sha256'][str(p.relative_to(ROOT))]=sha(p)
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
 objects=[]
 for i,p in enumerate(ordered):
  obj=build/f'{i:03d}.o';objects.append(str(obj))
  strict=['-Wall','-Wextra','-Werror'] if p.name in ('mod_fmr_b111_matrix_solute_route.f90','mod_b111_reactive_solute_substep.f90','mod_fmr_b111_matrix_joint_application.f90','mod_matrix_joint_restart_file.f90') else []
  command(FC+flags+strict+['-c',str(p),'-o',str(obj)],build,'compile')
 outputs={}
 for driver in (TEST,JOINT):
  obj=build/(driver.stem+'.o');exe=build/driver.stem
  command(FC+flags+['-c',str(driver),'-o',str(obj)],build,'compile')
  command(FC+flags+objects+[str(obj),'-o',str(exe)],build,'link')
  for exponent in EXPONENTS:
   runbuild=build if exponent=='1' else build/('n'+exponent)
   runbuild.mkdir(exist_ok=True)
   if driver==TEST:
    stdout=command([str(exe),exponent],runbuild,'native').decode()
    if 'MATRIX_ACTUAL_RICHARDS_ORACLE_ROLLBACK_RESTART=PASS' not in stdout:raise RuntimeError('missing original route pass')
   else:
    restart=runbuild/'joint-restart.bin';endpoint=runbuild/'joint-expected.bin';fresh=runbuild/'joint-fresh.bin'
    stdout=command([str(exe),'write',str(restart),str(endpoint),exponent],runbuild,'native').decode()
    if 'MATRIX_JOINT_COMMIT_ROLLBACK_OPAQUE_DISK=PASS' not in stdout:raise RuntimeError('missing joint pass')
    resumed=command([str(exe),'resume',str(restart),str(fresh),exponent],runbuild,'native').decode()
    if 'MATRIX_JOINT_FRESH_PROCESS=PASS' not in resumed:raise RuntimeError('missing fresh-process pass')
    if endpoint.read_bytes()!=fresh.read_bytes():raise RuntimeError('fresh-process endpoint bits differ')
    suffix='' if exponent=='1' else '@'+exponent
    outputs['fresh_endpoint_sha256'+suffix]=sha(fresh)
    outputs['restart_sha256'+suffix]=sha(restart)
    raw=restart.read_bytes();mutants={}
    mutants['truncated']=raw[:-12]
    damaged=bytearray(raw);damaged[10]^=1;mutants['crc_corrupt']=bytes(damaged)
    if struct.calcsize('i')!=4 or struct.calcsize('d')!=8:raise RuntimeError('unsupported test ABI')
    for label,offset,fmt,value in [('water_clock',136,'d',5.0),('node_count',152,'i',100000),('chemical_revision',280,'q',-1)]:
     damaged=bytearray(raw[:-4]);damaged[offset:offset+struct.calcsize(fmt)]=struct.pack(fmt,value)
     mutants[label]=bytes(damaged)+struct.pack('I',zlib.crc32(damaged)&0xffffffff)
    # Physical semantic negatives must also fail after a valid CRC at every n.
    n=struct.unpack('i',raw[152:156])[0];count=struct.unpack('i',raw[296:300])[0];start=300+8*count
    for label,offset,value in [('negative_water',start,-0.1),('nonfinite_concentration',start+8*n,float('nan')),
         ('negative_dissolved',start+16*n,-1.0),('wrong_sorbed_equilibrium',start+24*n,100.0)]:
     damaged=bytearray(raw[:-4]);damaged[offset:offset+8]=struct.pack('d',value)
     mutants[label]=bytes(damaged)+struct.pack('I',zlib.crc32(damaged)&0xffffffff)
    for label,data in mutants.items():
     path=runbuild/(label+'.bin');path.write_bytes(data)
     rejected=command([str(exe),'reject',str(path),str(fresh),exponent],runbuild,'native').decode()
     if 'MATRIX_JOINT_INVALID_FILE=PASS' not in rejected:raise RuntimeError('missing negative '+label)
    stdout+=resumed+'MATRIX_JOINT_CORRUPTION_NEGATIVES=PASS\n'
   print('EXPONENT='+exponent+' '+stdout,flush=True)
   outputs[driver.name+('' if exponent=='1' else '@'+exponent)]=stdout
 results['runs'][opt]={'stdout':outputs,'source_count':len(ordered)+2,'generated_oracle_sha256':sha(oracle),'generated_fixture_sha256':sha(fixture)}
results['o0_o2_stdout_identity']=PROCESS_ONLY or results['runs']['O0']['stdout']==results['runs']['O2']['stdout']
if not results['o0_o2_stdout_identity']:raise RuntimeError('O0/O2 mismatch')
results['cost_seconds']={c:sum(e['seconds'] for e in events if e['category']==c) for c in ('compile','link','native')}
results['status']='SCOPED_LOCAL_QUALIFICATION_PASS_NOT_ADMITTED'
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print('MATRIX_O0_O2=PASS')
