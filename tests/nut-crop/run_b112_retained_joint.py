"""Selected current Richards/Soil-N integration and unchanged default byte gate."""
from pathlib import Path
import base64,hashlib,io,json,os,runpy,struct,tarfile,zlib
ROOT=Path(__file__).resolve().parents[2]
# One shared stable build executes the original default/1253/1260 science first.
original=runpy.run_path(str(ROOT/('tests/nut-crop/reuse_b112_stable.py'if os.environ.get('B112_REUSE_STABLE')else'tests/nut-crop/run_reproductive_binding.py')))
ns=original['ns'];OUT=ns['OUT'];cmd=ns['cmd'];FC=ns['FC'];sha=ns['sha'];result=original['result'];result['b112_retained']={}
more_original=original['more']
# Extend the measured production closure for source-driven amendment calendar execution.
start=len(ns['ordered'])
ns['visit'](ROOT/'src/runtime/mod_fmr_crop_soil_n_calendar_application.f90')
calendar_providers=ns['ordered'][start:]
for opt in ('O0','O2'):
 b=OUT/opt;flags=[x.replace(str(OUT/'O2'),str(b))for x in ns['flags']];flags[0]='-'+opt;flags+=['-I'+str(ROOT/'tests/nut-material')]
 objects=sorted(b.glob('provider-*.o'),key=lambda p:int(p.stem.split('-')[-1]))
 more=[Path(str(p).replace(str(OUT/'O2'),str(b)))for p in more_original]
 for i,p in enumerate(calendar_providers):
  obj=b/('calendar-provider-'+str(i)+'.o')
  cmd(FC+flags+['-c',p,'-o',obj],b,'compile');more.append(obj)
  result['input_sha256'][str(p.relative_to(ROOT))]=sha(p)
 driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';obj=b/(driver.stem+'.o');exe=b/driver.stem
 cmd(FC+flags+['-c',driver,'-o',obj],b,'driver_compile');cmd(FC+flags+objects+more+[b/'reproductive_literal.o',obj,'-o',exe],b,'link')
 restart=b/'b112-restart.bin';expected=b/'b112-expected.bin';fresh=b/'b112-fresh.bin'
 output=cmd([exe,'write',restart,expected],b,'native')
 assert 'B112_ACTUAL_RICHARDS_RETAINED_PENDING_HARVEST_OPAQUE_NATIVE=PASS'in output
 continuation=cmd([exe,'resume',restart,fresh],b,'native')
 assert expected.read_bytes()==fresh.read_bytes()==Path(str(expected)+'.opaque').read_bytes()
 assert restart.read_bytes()[:8]==b'S5NC0010'
 for suffix,tag in [('.harvest-pending',b'S5NC0014'),('.consumed',b'S5NC0013')]:
  path=Path(str(expected)+'.stages'+suffix);assert path.read_bytes()[:8]==tag
 assert Path(str(expected)+'.stages.consumed').read_bytes()==Path(str(expected)+'.stages.disk-consumed').read_bytes()
 negatives=['absent','old-profile','legacy','wrong-return','wrong-dvsnlt','wrong-dvsnt','wrong-nfixf','wrong-fntrt']
 for selected in negatives:assert 'INVALID_DISK=PASS'in cmd([exe,'reject',restart,'unused',selected],b,'native')
 raw=bytearray(restart.read_bytes());mutants={}
 def changed(name,offset,fmt,value):
  data=raw.copy();struct.pack_into(fmt,data,offset,value);struct.pack_into('<I',data,len(data)-4,zlib.crc32(data[:-4]));mutants[name]=data
 # Locate the explicit live profile envelope; its exact marker cannot occur in
 # any validated positive owner or physical input payload.
 marker=struct.pack('<d',-81003.);offset=raw.find(marker);assert offset>=0 and raw.find(marker,offset+1)<0
 size=int(struct.unpack_from('<d',raw,offset+8)[0]);assert 29<=size<=1562
 changed('retained_N_nan',offset+8*(size+7),'d',float('nan'))
 changed('retained_N_orphan',offset+8*(size+7),'d',1e5)
 changed('retained_DM_negative',offset+8*(size+5),'d',-1.)
 changed('gross_mortality_negative',offset+8*(size+2),'d',-1.)
 changed('owner_profile_marker_missing',offset,'d',-999.)
 changed('owner_envelope_size',offset+8,'d',9999.)
 changed('old_native_tag',0,'8s',b'S5NC0002')
 changed('unsupported_native_tag',0,'8s',b'S5NC0099')
 data=raw.copy();data[140]^=1;mutants['crc']=data;mutants['truncated']=raw[:120];mutants['trailing']=raw+b'x'
 for label,data in mutants.items():
  path=b/('b112-invalid-'+label+'.bin');path.write_bytes(data)
  assert 'INVALID_DISK=PASS'in cmd([exe,'reject',path,'unused'],b,'native')
 source_restart=b/'source-startup-restart.bin'
 source_endpoint=b/'source-startup-expected.bin'
 source_fresh=b/'source-startup-fresh.bin'
 source_out=cmd([exe,'write',source_restart,source_endpoint,'source-profile'],b,'source_native')
 assert 'NUT_SOURCE_FOUR_DAY_TWO_EVENTS_FRESH_RESTART=PASS' in source_out
 fresh_out=cmd([exe,'resume',source_restart,source_fresh,'source-profile'],b,'source_native')
 assert 'NUT_SOURCE_FOUR_DAY_TWO_EVENTS_FRESH_RESTART=PASS' in fresh_out
 assert source_endpoint.read_bytes()==source_fresh.read_bytes(),'source project fresh continuation differs'
 result['b112_retained'][opt]={'joint_stdout':output,'fresh_stdout':continuation,'endpoint_sha256':sha(expected),'restart_sha256':sha(restart),'profile_negatives':negatives,'decoder_negatives':list(mutants),'native_tags':[10,13,14],'source_fresh_endpoint_sha256':sha(source_fresh)}
 result['input_sha256'][str(driver.relative_to(ROOT))]=sha(driver)
# Original default and selected1253 bytes must still equal the admitted1260 capsule.
path=ROOT/'integration/audits/evidence/MC_NUT01_REPRODUCTIVE_PROCESS_SCIENCE_20261016.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(path.read_bytes())))as t:
 old={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
for opt in ('O0','O2'):
 for name in ['b111-expected.bin','b111-restart.bin','test_crop_soil_joint-expected.bin','test_crop_soil_joint-restart.bin','reproductive-expected.bin','reproductive-restart.bin']:
  assert (OUT/opt/name).read_bytes()==old['final/'+opt+'/'+name],name
assert result['b112_retained']['O0']==result['b112_retained']['O2']
result['input_sha256'][str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__))
result['status']='B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED'
result['cost_seconds']={c:sum(e['seconds']for e in ns['events']if e['category']==c)for c in sorted({e['category']for e in ns['events']})}
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
