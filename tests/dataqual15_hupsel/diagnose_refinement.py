"""Source-bound distinguishing executions, not a new literal-input admission."""
import argparse,hashlib,json,os,re,shutil,struct,subprocess,tarfile,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--phase',choices=['native','reference'],required=True);p.add_argument('--observations',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 record=dict(status='IN_PROGRESS',phase=a.phase,events=[],diagnostic_only=True,old_frozen_gate_pass=False,no_checkpoint_rebinding=True)
 def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',newline='\n')
 def run(cmd,label,cwd,expected=0,timeout=300,captures=None):
  start=time.monotonic();i=len(record['events']);captured=set();censored=False
  with(out/f'{i}.stdout').open('wb')as so,(out/f'{i}.stderr').open('wb')as se:
   proc=subprocess.Popen(list(map(str,cmd)),cwd=cwd,stdout=so,stderr=se)
   while proc.poll()is None:
    if captures:
     try:
      raw=(cwd/'checkpoint.bin').read_bytes();assert raw[:8]==b'S5HR0003'and zlib.crc32(raw[:-4])==struct.unpack_from('=I',raw,len(raw)-4)[0];day=struct.unpack_from('=d',raw,8)[0]
      if day in captures and day not in captured:(cwd/f'checkpoint-{int(day)}.bin').write_bytes(raw);captured.add(day)
     except(OSError,AssertionError,struct.error):pass
    if time.monotonic()-start>timeout:proc.kill();proc.wait();censored=True;break
    time.sleep(.005 if captures else .1)
  record['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=proc.returncode,censored=censored,seconds=time.monotonic()-start,captured=sorted(captured),stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save();assert proc.returncode==expected and not censored,(label,out/f'{i}.stderr')
 def cap_swp(raw,cap):
  pattern=rb'(?im)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+';assert len(re.findall(pattern,raw))==1
  changed=re.sub(pattern,lambda m:m[1]+str(cap).encode(),raw)
  assert re.sub(pattern,lambda m:m[1]+b'NUMERICAL_DTMAX',changed)==re.sub(pattern,lambda m:m[1]+b'NUMERICAL_DTMAX',raw)
  return changed
 if a.phase=='reference':
  obs=a.observations.resolve();old=json.loads((obs/'RESULT.json').read_text());exe=obs/'swap431';assert sha(exe.read_bytes())==old['original_executable_sha256']
  for path,digest in old['source_sha256'].items():assert sha((ROOT/path).read_bytes())==digest,path
  exe.chmod(0o755);record['executable_sha256']=sha(exe.read_bytes());save()
  for cap in [.000625,.0003125]:
   case=out/('dtmax-'+str(cap));case.mkdir()
   for source in (obs/'dtmax-0.04').iterdir():
    if source.suffix in ['.swp','.crp','.met','.dra']:shutil.copyfile(source,case/source.name)
   (case/'swap.swp').write_bytes(cap_swp((case/'swap.swp').read_bytes(),cap));run([exe],'original-'+str(cap),case,expected=100);assert(case/'swap.ok').exists()
 else:
  capsule=ROOT/'integration/dataqual15_hupsel/UNION_C3_HUPSEL_EVIDENCE.tar.xz';m=json.loads(capsule.with_name('UNION_C3_HUPSEL_RESULT.json').read_text());assert sha(capsule.read_bytes())==m['archive_sha256']
  for path,digest in m['repository_source_sha256'].items():assert sha((ROOT/path).read_bytes())==digest,path
  case=out/'native-dtmax-0.01';case.mkdir()
  with tarfile.open(capsule)as t:
   get=lambda name:t.extractfile(name).read();build=m['normalized_builds']['hupsel-O2'];exe=out/'swap5_hupsel';binary=get('binaries/hupsel-O2');assert sha(binary)==build['executable_sha256'];exe.write_bytes(binary);exe.chmod(0o755)
   reader=out/'read_fallow';reader.write_bytes(get('binaries/read-fallow-hupsel-O2'));reader.chmod(0o755)
   for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
    raw=get('cases/hupsel-full1096/'+name);assert raw==(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'/name).read_bytes();(case/name).write_bytes(raw)
   record.update(executable_sha256=sha(binary),reader_sha256=sha(reader.read_bytes()),sealed_build=build,predecessor_capsule_sha256=m['archive_sha256']);save()
  (case/'swap.swp').write_bytes(cap_swp((case/'swap.swp').read_bytes(),.01));run([reader,'swap.swp','283.met','swap.dra','1096','original-germination'],'prepare',case)
  text=(case/'input.nml').read_text();assert text.count('&column ')==1;text=text.replace('&column ','&column original_hupsel_rotation=.true.,reactive_substep_chemistry=.true.,',1);(case/'input.nml').write_text(text)
  ends=[float(v)for v in re.search('^ends_day=(.*)$',text,re.M)[1].split(',')if v.strip()];stop=next(i+1 for i,v in enumerate(ends)if v==1096)
  run([exe,'input.nml','-',stop,'swap.swp','maize.crp'],'fresh-native-dtmax0.01-full1096',case,timeout=2400,captures=[120,365,494,524,537,566,584,591,603,636,730,731,868,1058,1077])
 record['status']='DIAGNOSTIC_FULL_EXECUTIONS_COMPLETE';save();print(json.dumps({k:v for k,v in record.items()if k!='sealed_build'},indent=2))
if __name__=='__main__':main()
