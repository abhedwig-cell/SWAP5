"""Preserve actual producer source bytes separately from normalized Git identity."""
from pathlib import Path
import argparse,hashlib,json,subprocess,time,zipfile

ROOT=Path(__file__).resolve().parents[2]
SURFACES=['app','src','tools/solute','tools/vq','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','tests/saltfarm_newton','reference/swap-4.3.1']
TEXT={'.py','.f90','.f','.for','.inc','.json','.md','.yml','.yaml','.toml','.txt'}


def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir();start=time.perf_counter()
 def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
 assert not git('status','--porcelain','--',*SURFACES),'Dirty actual producer source surface'
 head=git('rev-parse','HEAD').decode().strip();entries={}
 for line in git('ls-tree','-r',head,'--',*SURFACES).decode().splitlines():
  mode,name=line.split('\t',1);entries[name]=mode.split()[2]
 archive=a.output/'actual-producer-source.zip';members={}
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for name,blob in sorted(entries.items()):
   path=ROOT/name
   # Sparse portable checkouts may omit unrelated tracked artifacts; every
   # included byte is recorded, and missing paths remain explicit inventory.
   if not path.is_file():members[name]=dict(git_blob=blob,checkout='ABSENT');continue
   raw=path.read_bytes();z.writestr(name,raw);record=dict(git_blob=blob,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),prefix_nul_8192=raw[:8192].count(b'\0'))
   if path.suffix.lower() in TEXT:record['lf_normalized_sha256']=hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest()
   members[name]=record
 raw=archive.read_bytes();q=dict(status='ACTUAL_SOURCE_BYTES_PRESERVED_WITH_SEPARATE_GIT_AND_LF_IDENTITY',producer_head=head,role='Actual byte snapshot at this commit. Earlier model producers retain their own source refs; dependency equality must be proved, never rebound.',archive=archive.name,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),prefix_nul_8192=raw[:8192].count(b'\0'),surfaces=SURFACES,members=members,seconds=time.perf_counter()-start)
 (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8');print(q['status'],len(members),q['bytes'],flush=True)


if __name__=='__main__':main()
