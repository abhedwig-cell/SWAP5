#!/usr/bin/env python3
"""Persist raw selected runs, receipts and complete short traces and hashes of every long hydraulic sequence.

Executables, object/modules and duplicate repeated trajectory payloads are not
evidence members. Every retained member has a SHA256. Repeat hashes/timings stay
in CONTROL.json; all full hydraulic sequences can also be regenerated.
"""
import argparse,base64,hashlib,io,json,tarfile
from pathlib import Path
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--results',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();root=a.results.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);members={}
 dirs=['arena-benchmark','canonical-benchmark','arena-qualification','arena-preservation','arena-reactive-unlimited','arena-age','arena-dry','trace-branch','observations-final','proposal-diagnostic','application-profile-run','arena-profile','three-way','historical-O0-final','historical-O3','retained','production-qualification']
 for name in dirs:
  for p in (root/name).rglob('*'):
   if not p.is_file()or p.suffix in {'.o','.mod','.smod'}:continue
   rel=p.relative_to(root);parts=p.relative_to(root/name).parts
   if p.suffix=='.bin'and p.name in {'trajectory.bin','legacy_trajectory.bin'}:
    if name!='three-way'or len(parts)!=2 or parts[0].split('-')[1]!='0'or parts[0].endswith('after')or parts[0].split('-')[0]not in {'3','4'}:continue
   # Repeated direct solver series are identical across compiler settings;
   # keep every stdout/hash/counter, not the object build directory.
   if name=='retained'and (len(parts)==1 or (len(parts)>1 and len(parts[0].split('-'))==2)):
    if p.name!='INPUTS.json':continue
   if p.name=='gmon.out':continue
   if p.suffix in {'.f90','.f','.for'}and name not in {'observations-final','proposal-diagnostic'}:continue
   with p.open('rb')as f:magic=f.read(4)
   if magic==b'\x7fELF':continue
   members[str(rel)]=p
 for d in ['arena-O0','arena-O2','arena-O2-checked','canonical-production','retained-production','application-gprof','arena-gprof']:
  members[d+'/build-complete.json']=root/d/'build-complete.json'
 for d in ['legacy-O0','legacy-O3','legacy-full/reference-run']:
  for p in (root/d).glob('*'):
   if p.name in {'INPUTS.json','build.log'}:members[str(p.relative_to(root))]=p
 for p in root.glob('*.log'):
  if p.stat().st_size<500_000:members[p.name]=p
 for pat in ['predecessor-*.json','predecessor-*.stdout','predecessor-*.stderr','arena-reactive/events.json','perf01-*.json','reactive-current-path-failure-events.json']:
  for p in root.glob(pat):members[str(p.relative_to(root))]=p
 archive=out/'evidence.tar.xz'
 manifest={str(k):hashlib.sha256(p.read_bytes()).hexdigest()for k,p in sorted(members.items())}
 with tarfile.open(archive,'w:xz',preset=6)as t:
  for k,p in sorted(members.items()):t.add(p,arcname=k,recursive=False)
  blob=json.dumps(manifest,sort_keys=True,indent=2).encode();info=tarfile.TarInfo('MEMBERS.json');info.size=len(blob);info.mtime=0;t.addfile(info,io.BytesIO(blob))
 raw=archive.read_bytes();encoded=base64.b64encode(raw);chunks=[]
 for i in range(0,len(encoded),512_000):
  name=f'evidence.part-{i//512_000:03d}.b64';(out/name).write_bytes(encoded[i:i+512_000]);chunks.append(name)
 (out/'INDEX.json').write_text(json.dumps(dict(schema=1,encoding='concatenated-base64-xz-tar',parts=chunks,decoded_sha256=hashlib.sha256(raw).hexdigest(),decoded_bytes=len(raw),member_count=len(members),members_sha256=hashlib.sha256(blob).hexdigest()),indent=2)+'\n');archive.unlink();print(len(members),len(raw),len(chunks),flush=True)
if __name__=='__main__':main()
