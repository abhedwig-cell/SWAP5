"""Additional real public decoder controls on the exact retained POSIX executables."""
import argparse,json,os,struct,subprocess,time,zlib
from pathlib import Path
import generation_crc_posix_evidence as evidence

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='posix'
 record,files=evidence.unpack();evidence.audit(files);out=a.output.resolve();out.mkdir(parents=True);events=[];rows=[]
 def run(command,case,label,token):
  start=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=case,capture_output=True,timeout=180,env=dict(os.environ,OMP_NUM_THREADS='1'));stem='%03d'%len(events)
  for stream in ('stdout','stderr'):(out/(stem+'.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(label=label,command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-start,stdout=stem+'.stdout',stderr=stem+'.stderr'));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
  assert r.returncode==0 and token in r.stdout,(label,r.stdout,r.stderr)
 for role in ('incumbent','candidate'):
  for opt in ('O0','O2'):
   for family in ('joint','saved'):
    case=out/(role+'-'+opt+'-'+family);case.mkdir();exe=case/'decoder';exe_key=role+'/'+family+'/'+opt+'/'+('joint-output'if family=='joint'else'saved');exe.write_bytes(files[exe_key]);exe.chmod(0o755)
    good_key=role+'/joint/'+opt+'/model.restart.generation'if family=='joint'else evidence.prefix(files,role,opt,'saved')+'.phase-3'
    raw=files[good_key];evidence.valid_generation(raw);expected=zlib.crc32(raw[:-4]);assert expected!=0
    good=case/'good';good.write_bytes(raw);proper=case/'proper';proper.write_bytes(raw[:-4]+struct.pack('<I',expected));copy=case/'copy'
    positive=[exe,'generation-read',proper,copy]if family=='joint'else[exe,'saved-resume',proper,copy,'','roundtrip']
    run(positive,case,'proper-resealed-'+case.name,b'JOINT_OUTPUT_INDEPENDENT_GENERATION_READ=PASS'if family=='joint'else b'SAVED_GENERATION_FRESH_CONTINUATION_PASS');assert copy.read_bytes()==raw
    inner=bytearray(raw);n=struct.unpack_from('<i',inner,8)[0];end=152+n-1 if family=='joint'else 84+n-1;inner[end]^=1;inner[-4:]=struct.pack('<I',zlib.crc32(inner[:-4]))
    for label,bad in [('zero_footer',raw[:-4]+b'\0'*4),('inner_crc_resealed_outer',bytes(inner))]:
     invalid=case/label;invalid.write_bytes(bad);prefix=case/(label+'-live')
     if family=='joint':
      run([exe,'generation-reject',invalid,prefix,'',good],case,label+'-'+case.name,b'JOINT_OUTPUT_GENERATION_ATOMIC_INVALID=PASS');assert Path(str(prefix)+'.before').read_bytes()==Path(str(prefix)+'.after').read_bytes()==raw
     else:
      run([exe,'saved-reject',invalid,case/'unused'],case,label+'-empty-'+case.name,b'SAVED_GENERATION_INVALID_ATOMIC_PASS')
      prefix.write_bytes(raw);run([exe,'saved-reject-live',invalid,prefix],case,label+'-live-'+case.name,b'SAVED_GENERATION_INVALID_LIVE_ATOMIC_PASS');assert Path(str(prefix)+'.before-invalid').read_bytes()==Path(str(prefix)+'.after-invalid').read_bytes()==raw
    rows.append(dict(role=role,optimization=opt,family=family,executable_key=exe_key,executable_sha256=evidence.sha(files[exe_key]),good_key=good_key,good_sha256=evidence.sha(raw),expected_crc=expected,proper_valid_resealed=True,zero_footer_refused=True,resealed_outer_bad_inner_refused=True,live_authority_unchanged=True))
 assert len(events)==32 and len(rows)==8
 (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_PUBLIC_GENERATION_32_NATIVE_CONTROLS_PASS',original_artifact_sha256=record['artifact_zip_sha256'],rows=rows,events=events,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('ACTUAL_PUBLIC_GENERATION_32_NATIVE_CONTROLS_PASS')
if __name__=='__main__':main()

