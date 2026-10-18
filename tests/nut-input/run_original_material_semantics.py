from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,time,zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['N_ORIGINAL_MATERIAL_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes()))) as t:
 raw={n:t.extractfile('SWAP/'+n).read() for n in ['management_soil.f90','wofost_soil_declarations.f90','wofost_soil_amendments.f90','wofost_soil_parameters.f90']}
assert hashlib.sha256(raw['management_soil.f90']).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
lines=raw['management_soil.f90'].decode().splitlines();read_material='\n'.join(lines[118:126]);read_event='\n'.join(lines[128:134]);convert='\n'.join(lines[146:149]);group='\n'.join(lines[152:166])
flag_read='\n'.join(lines[248:251])+'\nend if'
assert "'flCropExt'" in flag_read
assert "'MatNum'" in read_material and "'iMat'" in read_event and 'MatNum,masme' in read_event
ttutil=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes())
assert hashlib.sha256(ttutil).hexdigest()=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'
zipfile.ZipFile(io.BytesIO(ttutil)).extractall(OUT/'source');library=OUT/'source/TTUTIL'
events=[];results={};artifacts={}
def run(c,b,category,success=True):
 c=list(map(str,c));start=time.perf_counter();r=subprocess.run(c,cwd=b,input=b'',capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=c,category=category,returncode=r.returncode,seconds=time.perf_counter()-start));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if success and r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.returncode,r.stdout.decode()
driver='''program original_material_identity
 use wofost_soil_declarations
 use MOD_texture_orgmat
 implicit none
 integer,parameter::masme=1000
 integer::unit_snm=20,unit_err=0,nsmm,nsme,i,j,declared(2),expected(2)
 real(8)::smedate(1000),MatAmount(1000)
 character(512)::filnam,arg
 logical::rdinqr,expected_flag
 call get_command_argument(1,filnam)
 call get_command_argument(2,arg);read(arg,*)expected(1)
 call get_command_argument(3,arg);read(arg,*)expected(2)
 CALL_MATERIAL
 declared=MatNum(:2)
 if(nsmm/=2.or.any(declared/=expected))error stop 'initial MatNum read'
 CALL_EVENT
 CALL_FLAG
 call get_command_argument(4,arg);read(arg,*)expected_flag
 if(flCropExt.neqv.expected_flag)error stop 'original disabled/true crop diagnostic flag'
 print '(A,L1)','ORIGINAL_TTUTIL_CROP_EXT_FLAG=',flCropExt
 if(nsme/=2.or.any(MatNum(:2)/=[2,1]))error stop 'event iMat overwrites definition IDs'
 CALL_CONVERT
 CALL_GROUP
 call wofost_soilparameters
 WFrac_t0=.3d0;dz_WSN=.3d0;SorpCoef=0d0;bdens=1300d0
 cNH4_t0=0d0;cNO3_t0=0d0;NH4N_amend=0d0;NO3N_amend=0d0;NH4N_volat=0d0
 do isme=1,2
  call wofost_soilamendents
 end do
 if(abs(cNH4_t0*.3d0*.3d0-.006d0)>1d-16)error stop 'positional NH4 result'
 if(abs(cNO3_t0*.3d0*.3d0-.0045d0)>1d-16)error stop 'positional NO3 result'
 if(abs(NH4N_amend-.006d0)>1d-16.or.abs(NO3N_amend-.0045d0)>1d-16)error stop 'original gross receipts'
 print '(A,2I4)','ORIGINAL_DECLARED_IDS ',declared
 print '(A,2I4)','ORIGINAL_EVENT_POSITIONS ',MatNum(:2)
 print '(A,2ES24.15)','ORIGINAL_ACTUAL_MINERAL_INPUT_KG_M2 ',cNH4_t0*.3d0*.3d0,cNO3_t0*.3d0*.3d0
 print '(A)','ORIGINAL_MATNUM_OVERWRITE_POSITIONAL_PROPERTY_SELECTION=PASS'
end program
'''.replace('CALL_MATERIAL',read_material).replace('CALL_EVENT',read_event).replace('CALL_CONVERT',convert).replace('CALL_GROUP',group).replace('CALL_FLAG',flag_read)
fixture="""MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac
IDS1 'First' 0. 0. 0. .10 .20
IDS2 'Second' 0. 0. 0. .40 .05
smedate iMat Dosagekgha VolatFraction
1901-01-01 2 100. 0.
1901-01-02 1 200. 0.
;
"""
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=b/'ttutil';old.mkdir()
 sources=[library/'ttutilprefs.f90',library/'ttutil.f90']+sorted(p for p in library.glob('*.f90')if p.name not in ['ttutilprefs.f90','ttutil.f90'])+sorted(library.glob('*.for'))
 for i,p in enumerate(sources):
  run(['gfortran','-'+opt,'-std=legacy','-fallow-argument-mismatch','-ffixed-line-length-none','-ffree-line-length-none','-J'+str(old),'-I'+str(old),'-I'+str(library),'-c',p,'-o',old/(str(i)+'.o')],old,'ttutil_compile')
 for p in old.glob('*.o'):artifacts[str(p)]=sha(p)
 for p in old.glob('*.mod'):artifacts[str(p)]=sha(p)
 for n in raw:
  if n!='management_soil.f90':(b/n).write_bytes(raw[n])
 (b/'fixture.f90').write_text('module MOD_texture_orgmat\n real(8)::bdens(1)\nend module\n')
 (b/'driver.f90').write_text(driver)
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b),'-I'+str(old)]
 objects=[]
 for n in ['wofost_soil_declarations.f90','fixture.f90','wofost_soil_parameters.f90','wofost_soil_amendments.f90','driver.f90']:
  obj=b/(n+'.o');run(['gfortran',*flags,'-c',b/n,'-o',obj],b,'compile');objects.append(obj)
 exe=b/'witness';run(['gfortran',*flags,*objects,*sorted(old.glob('*.o')),'-o',exe],b,'link');results[opt]={}
 for name,ids in [('contiguous',(1,2)),('noncontiguous',(20,1)),('reversed',(2,1)),('duplicate',(1,1))]:
  for flag,extra,expected_flag in [('absent','',False),('disabled_lower','flCropExt = .false.\n',False),('disabled_upper','FLCROPEXT = .FALSE.\n',False),('enabled_source','flCropExt = .true.\n',True)]:
   key=name+'_'+flag;p=b/(key+'.snm');p.write_text(fixture.replace('IDS1',str(ids[0])).replace('IDS2',str(ids[1]))+extra)
   _,stdout=run([exe,p.name,*ids,'.true.'if expected_flag else'.false.'],b,'native');results[opt][key]=stdout
 for name,label in [('zero',0),('too_large',21)]:
  p=b/(name+'.snm');p.write_text(fixture.replace('IDS1',str(label)).replace('IDS2','1'))
  code,stdout=run([exe,p.name,label,1,'.false.'],b,'negative_native',False)
  assert code!=0 and 'ORIGINAL_MATNUM_OVERWRITE_POSITIONAL_PROPERTY_SELECTION=PASS'not in stdout
  results[opt][name]='REJECTED_ORIGINAL_MATERIAL_LABEL_SOURCE_RANGE'

assert results['O0']==results['O2']
assert all(sha(Path(p))==h for p,h in artifacts.items())
r=dict(status='ORIGINAL_MATERIAL_POSITIONS_DISABLED_CROP_FLAG_O0_O2_PASS',source_sha256={n:hashlib.sha256(v).hexdigest()for n,v in raw.items()},source_lines={'material':[119,126],'event':[129,134],'dose':[147,149],'group':[153,166],'crop_flag':[249,251]},reused_artifacts=artifacts,results=results,runner_sha256=sha(Path(__file__)),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['ttutil_compile','compile','link','native','negative_native']},scope='Unmodified original TTUTIL material/default-logical interpretation and full original amendment property selection; original true is interpreted but SWAP5 extended diagnostics remain unsupported')
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
