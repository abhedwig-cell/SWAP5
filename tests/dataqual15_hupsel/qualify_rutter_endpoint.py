"""Actual four-node water/heat/reactive composition plus guarded canopy event.

Reuse measured exact production providers. Inject only endpoint controls into
the incumbent real physical fixture; retain its genuine hydraulic integration,
original literal oracle, independent stock checks and source-window assertions.
"""
import argparse,hashlib,json,os,re,struct,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();bundle=a.bundle.resolve();out=a.output.resolve();out.mkdir();build=json.loads((bundle/'BUILD.json').read_text())
assert all(sha(Path(s))==h for s,h in build['source_sha256'].items())
assert all(sha(Path(s))==h for s,h in build['object_sha256'].items())
publisher=build['publication_provider'];assert sha(Path(publisher['object']))==publisher['object_sha256']
events=[]
def run(cmd,label,cwd=out):
 start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120);i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),label=label,seconds=time.monotonic()-start,returncode=r.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(label,r.stderr.decode(errors='replace'),r.stdout.decode(errors='replace'));return r.stdout.decode()
generator=ROOT/'tests/nut-sol/run_nonlinear_pond.py';namespace={'__file__':str(generator)};os.environ['DYNAMIC_POND_RESULT_DIR']=str(out/'oracle-generator')
exec(compile(generator.read_text().split('\nresults = dict')[0],str(generator),'exec'),namespace)
oracle=out/'mod_b111_literal_oracle.f90';oracle.write_text(namespace['oracle'])
fixture=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';text=fixture.read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing');(out/'matrix_fixture.inc').write_text(text[start:end]+'\n')
inc=ROOT/'tests/dataqual15_hupsel/rutter_endpoint_controls.inc';source=ROOT/'tests/nut-sol/test_pond_thermal.f90';text=source.read_text()
text=text.replace(' implicit none',' use solute_column_context,only:initialize_column_context\n implicit none',1)
text=text.replace(' call initialize_application_config(cfg,-75d0,k)', ' call initialize_column_context([.5d0,.5d0,1d0,1d0])\n call initialize_application_config(cfg,-75d0,k)',1)
anchor=" end do\n if(trim(mode)=='split')then";assert text.count(anchor)==1;text=text.replace(anchor," end do\n call endpoint_controls(water,chemical,t1)\n if(trim(mode)=='split')then")
anchor=' end subroutine checked_rutter_interval';assert text.count(anchor)==1;text=text.replace(anchor,' call incomplete_endpoint_control(w,b)\n'+anchor)
driver=out/'endpoint_driver.f90';text=text.rsplit('end program',1);driver.write_text(text[0]+inc.read_text()+'\nend program'+text[1])
fc=next(e['command'][0]for e in json.loads((bundle/'EVENTS.json').read_text())if e['label']=='link')
flags=[f for f in build['flags']if not f.startswith('-J')]+['-I'+str(out),'-J'+str(out)]
extra=[]
for i,s in enumerate([ROOT/'tests/nut-sol/matrix_nonlinear_oracle.f90',oracle]):
 obj=out/f'oracle{i}.o';run([fc,*flags,'-c',s,'-o',obj],'compile-oracle');extra.append(obj)
mapping={}
for s in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',s.read_text(),re.M|re.I):mapping[name.lower()]=s
known={Path(s).resolve()for s in build['source_sha256']};visited=set();additional=[]
def missing(s):
 if s.resolve()in known or s in visited:return
 visited.add(s)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s.read_text(),re.M|re.I):
  if name.lower()in mapping and mapping[name.lower()]!=s:missing(mapping[name.lower()])
 if s!=driver:additional.append(s)
missing(driver)
for i,s in enumerate(additional):
 obj=out/f'additional{i}.o';run([fc,*flags,'-c',s,'-o',obj],'compile-additional-production');extra.append(obj)
objects=[o for s,o in zip(build['source_sha256'],build['object_sha256'])if not s.endswith('main.f90')]
exe=out/'endpoint.exe';stack=['-Wl,--stack,16777216']if os.name=='nt'else[];cmd=[fc,*flags,*stack,driver,*extra,*objects,publisher['object'],build['ttutil_archive'],'-o',exe]
response=out/'link.args';response.write_text('\n'.join('"'+str(v).replace('\\','/').replace('"','\\"')+'"'for v in cmd[1:])+'\n');run([fc,'@'+str(response)],'link')
stdout=run([exe,'rutter-full',out/'unused.bin',out/'endpoint',2,1],'native');assert 'ACTUAL_RUTTER_ENDPOINT_EXPORT_ROLLBACK_LINEAGE_SOURCE_WINDOW_AND_STALE_CONTROLS_PASS'in stdout
before=(out/'endpoint.event-before').read_bytes();rolled=(out/'endpoint.event-rollback').read_bytes();after=(out/'endpoint.event-after').read_bytes();assert before==rolled,'discarded/rejected event changed complete typed owners';assert len(before)==len(after)
for raw in [before,after]:assert raw[:8]==b'S5PT0004'and zlib.crc32(raw[:-4])==struct.unpack_from('=I',raw,len(raw)-4)[0]
n,history,identity,count=struct.unpack_from('=iiqi',before,148);assert n==4 and history==0 and count>0
canopy=168+8*count+8*(3*n+2)+8+12+4
old=struct.unpack_from('=d',before,canopy)[0];new=struct.unpack_from('=d',after,canopy)[0];assert old>.005 and new==.005
assert struct.unpack_from('=q',after,128)[0]==struct.unpack_from('=q',before,128)[0]+1
left=bytearray(before);right=bytearray(after)
for off,length in [(128,8),(canopy,8),(len(before)-4,4)]:left[off:off+length]=right[off:off+length]=bytes(length)
assert left==right,'event changed soil, pond, thermal, chemical, source progress, parameter identity or physical clock'
report=dict(status='ACTUAL_RUTTER_ENDPOINT_PHYSICAL_MASS_AND_COMPLETE_OWNER_BYTE_CONTROLS_PASS_NOT_WHOLE_SCIENCE',build=build,executable_sha256=sha(exe),generated_driver_sha256=sha(driver),generated_original_oracle_sha256=sha(oracle),additional_production_sha256={s.relative_to(ROOT).as_posix():sha(s)for s in additional},repository_test_sha256={s.relative_to(ROOT).as_posix():sha(s)for s in [Path(__file__),inc,source,fixture,generator,ROOT/'tests/nut-sol/matrix_nonlinear_oracle.f90']},canopy_before=old,canopy_after=new,export_cm=old-new,only_changed_typed_fields=['kernel_revision','canopy_storage','CRC32'],stdout=stdout,scientific_whole_project_admission=False)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
