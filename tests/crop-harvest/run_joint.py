"""Reuse the existing complete senescence science runner plus the harvest driver.

Every original driver, assertion, native mutation and immutable endpoint check
is retained. Providers are shared in the same live O0/O2 execution only.
"""
from pathlib import Path
import hashlib,json,os,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['HARVEST_JOINT_DIR']).resolve()
RESUME=os.environ.get('HARVEST_RESUME_COMPLETED_O0')=='1'
OUT.mkdir(parents=True,exist_ok=RESUME)
s=(ROOT/'tests/nut-senescence/run_senescence.py').read_text()
# Generated executable modes can be reset by workspace synchronization. Restore
# execute bits only for our freshly compiled native test binaries inside OUT.
needle_run=" args=list(map(str,args));t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)"
assert s.count(needle_run)==1
s=s.replace(needle_run," args=list(map(str,args))\n if category=='native' and Path(args[0]).is_relative_to(OUT):Path(args[0]).chmod(Path(args[0]).stat().st_mode|0o111)\n t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)")
needle="if mode=='joint':drivers += [ROOT/'tests/nut-material/test_material_joint.f90',ROOT/'tests/nut-material-environment/test_material_environment_joint.f90',ROOT/'tests/nut-senescence/test_senescence_joint.f90']"
assert s.count(needle)==1;s=s.replace(needle,needle+"+[ROOT/'tests/crop-harvest/test_harvest_joint.f90']")
s=s.replace("'test_senescence_joint':'senescence-'", "'test_senescence_joint':'senescence-','test_harvest_joint':'harvest-'")
s=s.replace("if d.stem!='test_senescence_joint':", "if d.stem not in ['test_senescence_joint','test_harvest_joint']:")
needle="   rawdisk=bytearray(first.read_bytes());mutants="
a=s.index(needle)
s=s[:a]+'''   if d.stem=='test_harvest_joint':
    assert first.read_bytes()[:8]==b'S5NC0006'
    assert end.read_bytes()[:8]==b'S5NC0005'
    # Entire admitted water record is unchanged by harvest incorporation.
    disk=first.read_bytes();nodes=struct.unpack_from('<i',disk,152)[0]
    history=struct.unpack_from('<i',disk,156)[0]
    water_end=160+16*nodes+16+(8*nodes if history else 0)
    assert disk[8:water_end]==end.read_bytes()[8:water_end]
    row['drivers'][d.stem]['water_record_unchanged']=True
    # Corrupt phase/budgets with a valid whole-file CRC: decoder must reject.
    negatives=[]
    for origin,phase in [(first,1.),(end,0.)]:
     phase_bytes=bytearray(origin.read_bytes());nn=struct.unpack_from('<i',phase_bytes,152)[0];hh=struct.unpack_from('<i',phase_bytes,156)[0]
     chemical=160+16*nn+16+(8*nn if hh else 0)
     pc=struct.unpack_from('<i',phase_bytes,chemical+24)[0];crop=chemical+28+8*pc+104
     cc=struct.unpack_from('<i',phase_bytes,crop+8)[0];owner=crop+12+8*cc+4
     assert struct.unpack_from('<d',phase_bytes,owner)[0]==-81001.
     tests={'forged_phase':(owner+24,phase),'forged_whole_N':(owner+27*8,99999.),'forged_organic_mass':(owner+28*8,99999.)}
     for label,(offset,value) in tests.items():
      mutant=phase_bytes.copy();struct.pack_into('<d',mutant,offset,value)
      struct.pack_into('<I',mutant,len(mutant)-4,zlib.crc32(mutant[:-4]))
      bad=b/(origin.stem+'-'+label+'.bin');bad.write_bytes(mutant)
      out=run([exe,'reject',bad],b,'native');assert 'INVALID_DISK=PASS'in out
      negatives.append(bad.name)
    row['drivers'][d.stem]['decoder_negatives']=negatives
    continue
'''+s[a:]
s=s.replace("for name in ['test_material_joint','test_material_environment_joint','test_senescence_joint']:","for name in ['test_material_joint','test_material_environment_joint','test_senescence_joint','test_harvest_joint']:")
s=s.replace("for p in [Path(__file__),ROOT/'tests/nut-crop/crop_fixture.inc'", "for p in [ROOT/'tests/crop-harvest/run_joint.py',ROOT/'tests/nut-senescence/run_senescence.py',ROOT/'tests/nut-crop/crop_fixture.inc'")
if RESUME:
 # The interrupted controller completed every O0 assertion and failed before
 # any O2 compile; only a Python temporary shadowed its original donor dict.
 # Bind that exact execution instead of rerunning unchanged O0 science.
 import re,subprocess
 old=(OUT/'executed_runner.py').read_text()
 assert re.sub(r'\bphase_bytes\b','raw',s)==old,'unexpected controller delta'
 e=json.loads((OUT/'events.json').read_text());assert e and all(x['returncode']==0 for x in e)
 assert not any('-O2' in x['command'] for x in e)
 pin=subprocess.check_output(['git','rev-parse','31334d1b'],cwd=ROOT,text=True).strip()
 assert subprocess.check_output(['git','diff',pin,'--','src'],cwd=ROOT)==b''
 bindings={}
 for x in e:
  if x['category'] in ['compile','driver_compile']:
   q=Path(x['command'][x['command'].index('-c')+1])
   if q.is_relative_to(ROOT):assert q.read_bytes()==subprocess.check_output(['git','show',pin+':'+str(q.relative_to(ROOT))],cwd=ROOT)
   bindings[str(q)]=hashlib.sha256(q.read_bytes()).hexdigest()
 for q in (OUT/'O0').iterdir():
  if q.is_file():bindings[str(q)]=hashlib.sha256(q.read_bytes()).hexdigest()
 for x in e:
  for stream in ['stdout','stderr']:
   q=OUT/x[stream+'_file'];assert hashlib.sha256(q.read_bytes()).hexdigest()==x[stream+'_sha256']
 o0={'production_providers':sum(x['category']=='compile' and '/src/' in ' '.join(x['command']) for x in e),'drivers':{}}
 native=[x for x in e if x['category']=='native']
 for x in native:
  cmd=x['command'];name=Path(cmd[0]).name
  if len(cmd)==1:o0['drivers'][name]={'stdout':(OUT/x['stdout_file']).read_text()}
  elif cmd[1]=='write':
   first,end=map(Path,cmd[2:4]);fresh=Path(str(end).replace('expected','fresh'))
   assert end.read_bytes()==fresh.read_bytes()==Path(str(end)+'.opaque').read_bytes()
   resumed=next(z for z in native if z['command']==[cmd[0],'resume',str(first),str(fresh)])
   row={'stdout':(OUT/x['stdout_file']).read_text(),'fresh_stdout':(OUT/resumed['stdout_file']).read_text(),
     'endpoint_sha256':hashlib.sha256(end.read_bytes()).hexdigest(),'restart_sha256':hashlib.sha256(first.read_bytes()).hexdigest()}
   if name in ['test_material_joint','test_material_environment_joint']:row['empty_batch_identity']=True
   row['decoder_negatives']=[Path(z['command'][2]).name for z in native if len(z['command'])>=3 and z['command'][0]==cmd[0]and z['command'][1]=='reject']
   if name=='test_harvest_joint':
    assert len(row['decoder_negatives'])==6;row['water_record_unchanged']=True
   o0['drivers'][name]=row
 assert len(o0['drivers'])==9
 recovery={'scope':'Terminal O0 science reused after controller-only failure before O2; no new numerical PASS fabricated',
   'source_pin':pin,'bindings':bindings,'original_controller_sha256':hashlib.sha256(old.encode()).hexdigest(),
   'events_sha256':hashlib.sha256((OUT/'events.json').read_bytes()).hexdigest(),'o0':o0}
 (OUT/'COMPLETED_O0_RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n')
 (OUT/'executed_runner.original.py').write_text(old)
 # Keep original raw events; every O2 event appends to them.
 s=s.replace("FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={};", "FC=shlex.split(os.environ.get('FC','gfortran'));events=json.loads((OUT/'events.json').read_text());inputs={};")
 s=s.replace("for opt in ['O0','O2']:", "for opt in ['O2']:",1)
 injection="result['runs']['O0']=json.loads((OUT/'COMPLETED_O0_RECOVERY.json').read_text())['o0']\n"
 s=s.replace("oracle='''", injection+"oracle='''",1)
(OUT/'executed_runner.py').write_text(s)
(OUT/'GENERATION.json').write_text(json.dumps(dict(executed_runner_sha256=hashlib.sha256(s.encode()).hexdigest(),source_runner_sha256=hashlib.sha256((ROOT/'tests/nut-senescence/run_senescence.py').read_bytes()).hexdigest()),indent=2)+'\n')
os.environ['SENESCENCE_RESULT_DIR']=str(OUT);sys.argv=[str(ROOT/'tests/nut-senescence/run_senescence.py'),'joint']
exec(compile(s,str(OUT/'executed_runner.py'),'exec'),globals())
